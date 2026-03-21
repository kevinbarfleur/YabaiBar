import AppKit
import SwiftUI
import YabaiBarCore

private enum SpaceRailToken: Equatable {
    case ellipsis
    case space(index: Int, isActive: Bool)
}

// Adapted from boring.notch / DynamicNotchKit under GPL-compatible reuse.
private struct NotchShape: Shape {
    private var topCornerRadius: CGFloat
    private var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat? = nil, bottomCornerRadius: CGFloat? = nil) {
        self.topCornerRadius = topCornerRadius ?? 6
        self.bottomCornerRadius = bottomCornerRadius ?? 14
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

@MainActor
private struct MetaballSpaceRailView: View, Animatable {
    nonisolated var animatableData: CGFloat {
        get { animatedActiveX }
        set { animatedActiveX = newValue }
    }
    let tokens: [SpaceRailToken]
    var animatedActiveX: CGFloat

    static let dotSize: CGFloat = 6
    static let capsuleWidth: CGFloat = 14
    private static let dotDiameter: CGFloat = dotSize
    private static let activeCapsuleWidth: CGFloat = capsuleWidth
    private static let activeCapsuleHeight: CGFloat = 6
    private static let spacing: CGFloat = 6
    private static let proximityRadius: CGFloat = 10
    private static let maxProximityScale: CGFloat = 2.0

    static func slotCenterX(for index: Int) -> CGFloat {
        CGFloat(index) * (dotDiameter + spacing) + dotDiameter / 2
    }

    private var contentWidth: CGFloat {
        guard !tokens.isEmpty else { return Self.dotDiameter }
        return CGFloat(tokens.count) * Self.dotDiameter + CGFloat(tokens.count - 1) * Self.spacing
    }

    private var hasActiveToken: Bool {
        tokens.contains(where: {
            if case .space(_, true) = $0 { return true }
            return false
        })
    }

    var body: some View {
        LiquidBlobShape(
            tokens: tokens,
            activeX: animatedActiveX,
            dotDiameter: Self.dotDiameter,
            activeCapsuleWidth: Self.activeCapsuleWidth,
            activeCapsuleHeight: Self.activeCapsuleHeight,
            spacing: Self.spacing,
            proximityRadius: Self.proximityRadius,
            maxProximityScale: Self.maxProximityScale,
            hasActiveToken: hasActiveToken
        )
        .fill(Color.white)
        .frame(width: contentWidth, height: 8)
        .overlay {
            // Inactive dots: visible at rest, fade out when blob covers them
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                if case .space(_, let isActive) = token, !isActive {
                    let cx = Self.slotCenterX(for: index)
                    let distance = abs(cx - animatedActiveX)
                    // Fade out earlier and more aggressively so dots disappear before blob arrives
                    let fadeRadius = Self.proximityRadius + 2
                    let fadeT = max(0, 1 - distance / fadeRadius)
                    let dotOpacity = 0.22 * (1 - fadeT * fadeT)

                    Circle()
                        .fill(Color.white.opacity(dotOpacity))
                        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                        .position(x: cx, y: 4)
                }
            }
        }
        .overlay {
            ellipsisOverlay
        }
    }

    private var ellipsisOverlay: some View {
        ZStack {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                if case .ellipsis = token {
                    HStack(spacing: 1.5) {
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                    }
                    .foregroundStyle(.white.opacity(0.18))
                    .position(x: Self.slotCenterX(for: index), y: 4)
                }
            }
        }
        .frame(width: contentWidth, height: 8)
        .allowsHitTesting(false)
    }
}

// Custom Shape: a single stretchy capsule that extends to absorb nearby dots
private struct LiquidBlobShape: Shape {
    let tokens: [SpaceRailToken]
    let activeX: CGFloat
    let dotDiameter: CGFloat
    let activeCapsuleWidth: CGFloat
    let activeCapsuleHeight: CGFloat
    let spacing: CGFloat
    let proximityRadius: CGFloat
    let maxProximityScale: CGFloat
    let hasActiveToken: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard hasActiveToken else { return path }

        let cy = rect.midY
        let hh = activeCapsuleHeight / 2
        var leftEdge = activeX - activeCapsuleWidth / 2
        var rightEdge = activeX + activeCapsuleWidth / 2

        // Extend capsule edges to cover nearby dots
        for (index, token) in tokens.enumerated() {
            guard case .space(_, let isActive) = token, !isActive else { continue }

            let cx = slotCenterX(for: index)
            let distance = abs(cx - activeX)
            let proximityT = max(0, 1 - distance / proximityRadius)

            guard proximityT > 0.08 else { continue }

            // Smoothly extend the blob edge toward the dot
            let dotR = dotDiameter / 2
            let reach = proximityT * proximityT // ease-in: gentle at distance, strong up close
            let dotLeft = cx - dotR * reach
            let dotRight = cx + dotR * reach

            leftEdge = min(leftEdge, dotLeft)
            rightEdge = max(rightEdge, dotRight)
        }

        let blobWidth = rightEdge - leftEdge
        let cornerRadius = min(hh, blobWidth / 2)
        path.addRoundedRect(
            in: CGRect(x: leftEdge, y: cy - hh, width: blobWidth, height: activeCapsuleHeight),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )

        return path
    }

    private func slotCenterX(for index: Int) -> CGFloat {
        CGFloat(index) * (dotDiameter + spacing) + dotDiameter / 2
    }
}

private struct NotchActionButton: View {
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.48))
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(.white.opacity(isHovered ? 0.09 : 0))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct AppIconView: View {
    let appName: String

    private var icon: NSImage? {
        NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName })?.icon
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay {
                        Text(String(appName.prefix(1)).uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
            }
        }
        .frame(width: 14, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct StackListRow: View {
    let item: ActiveStackItemSummary
    let action: () -> Void

    @State private var isHovered = false

    private var trimmedTitle: String {
        let candidate = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate != item.app else {
            return ""
        }
        return candidate
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIconView(appName: item.app)

                HStack(spacing: 5) {
                    Text(item.app)
                        .font(.system(size: 11, weight: item.isFocused ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(item.isFocused ? 0.94 : 0.72))
                        .lineLimit(1)

                    if !trimmedTitle.isEmpty {
                        Text(trimmedTitle)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(item.isFocused ? 0.34 : 0.24))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Text("\(item.position)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(item.isFocused ? 0.5 : 0.28))
                    .frame(width: 14, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(item.isFocused ? 0.08 : (isHovered ? 0.05 : 0)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(item.isFocused ? 0.05 : 0), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct YabaiNotchSurfaceView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var viewModel: YabaiNotchViewModel
    @State private var showsExpandedContent = false
    @State private var revealTask: Task<Void, Never>?
    @State private var activeSlotX: CGFloat = 0
    @State private var railHasAppeared = false

    private var state: DisplayNotchState? {
        viewModel.displayState
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if let state {
                    mainLayout(for: state)
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: viewModel.windowSize.width, maxHeight: viewModel.windowSize.height, alignment: .topLeading)
        .compositingGroup()
        .preferredColorScheme(.dark)
        .allowsHitTesting(model.indicatorPresentationState.showsNotchSurface)
        .onAppear {
            syncExpandedContent(with: viewModel.notchState, animated: false)
        }
        .onDisappear {
            revealTask?.cancel()
            revealTask = nil
        }
        .onChange(of: viewModel.notchState) { _, newValue in
            syncExpandedContent(with: newValue, animated: true)
        }
    }

    private func mainLayout(for state: DisplayNotchState) -> some View {
        let isOpen = viewModel.notchState == .open
        let outerWidth = isOpen ? viewModel.openOuterSize.width : viewModel.closedNotchSize.width
        let innerWidth = max(1, outerWidth - (isOpen ? notchOpenHorizontalPadding * 2 : 0))
        let innerHeight = isOpen ? max(1, viewModel.openOuterSize.height - notchOpenBottomPadding) : viewModel.closedNotchSize.height

        return Group {
            notchLayout(for: state)
                .frame(width: innerWidth, height: innerHeight, alignment: .topLeading)
                .padding(.horizontal, isOpen ? notchOpenHorizontalPadding : 0)
                .padding(.bottom, isOpen ? notchOpenBottomPadding : 0)
                .background(.black)
                .clipShape(
                    NotchShape(
                        topCornerRadius: viewModel.topCornerRadius,
                        bottomCornerRadius: viewModel.bottomCornerRadius
                    )
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 1)
                        .padding(.horizontal, viewModel.topCornerRadius)
                }
                .shadow(
                    color: ((viewModel.notchState == .open || viewModel.isHovering) && model.indicatorPresentationState.showsNotchSurface)
                        ? .black.opacity(0.68) : .clear,
                    radius: 5
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    viewModel.handleHover(hovering)
                }
                .onTapGesture {
                    viewModel.openFromTap()
                }
        }
        .animation(viewModel.notchState == .open ? viewModel.openAnimation : viewModel.closeAnimation, value: viewModel.notchState)
        .animation(.easeOut(duration: 0.16), value: viewModel.closedVisibleWidth)
        .frame(width: viewModel.windowSize.width, alignment: .center)
    }

    @ViewBuilder
    private func notchLayout(for state: DisplayNotchState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            topBand(for: state)
                .frame(height: viewModel.closedNotchSize.height)
                .zIndex(2)

            if viewModel.notchState == .open || showsExpandedContent {
                openBody(for: state)
                    .frame(
                        maxHeight: showsExpandedContent ? max(0, viewModel.openOuterSize.height - notchOpenBottomPadding - viewModel.closedNotchSize.height) : 0,
                        alignment: .top
                    )
                    .clipped()
                    .opacity(showsExpandedContent ? 1 : 0)
                    .blur(radius: showsExpandedContent ? 0 : 16)
                    .offset(y: showsExpandedContent ? 0 : -10)
                    .allowsHitTesting(viewModel.notchState == .open)
                    .animation(.easeOut(duration: 0.18), value: showsExpandedContent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func topBand(for state: DisplayNotchState) -> some View {
        HStack(spacing: 0) {
            closedSpaceRail(for: state)
                .frame(width: viewModel.leadingWidth, alignment: .leading)

            Rectangle()
                .fill(Color.clear)
                .frame(width: viewModel.centerWidth, height: viewModel.closedNotchSize.height)

            trailingStackSlot(for: state)
        }
        .frame(width: viewModel.closedNotchSize.width, height: viewModel.closedNotchSize.height, alignment: .leading)
    }

    private func trailingStackSlot(for state: DisplayNotchState) -> some View {
        let badgeLabel = state.stackSummary?.badgeLabel

        return ZStack(alignment: .trailing) {
            if let badgeLabel {
                Text(badgeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.trailing, 12)
                    .frame(width: viewModel.trailingReservedWidth, alignment: .trailing)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.6, anchor: .trailing)
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .trailing)
                                .combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: badgeLabel != nil)
        .frame(
            width: viewModel.trailingReservedWidth,
            height: viewModel.closedNotchSize.height,
            alignment: .trailing
        )
    }

    private func closedSpaceRail(for state: DisplayNotchState) -> some View {
        let tokens = spaceRailTokens(for: state, maxVisibleSpaces: 4)

        return MetaballSpaceRailView(tokens: tokens, animatedActiveX: activeSlotX)
            .padding(.leading, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                if let slot = activeSlotIndex(in: tokens) {
                    activeSlotX = MetaballSpaceRailView.slotCenterX(for: slot)
                }
                railHasAppeared = true
            }
            .onChange(of: state.visibleSpaceIndex) { _, _ in
                let fresh = spaceRailTokens(for: state, maxVisibleSpaces: 4)
                guard let slot = activeSlotIndex(in: fresh) else { return }
                let targetX = MetaballSpaceRailView.slotCenterX(for: slot)
                if railHasAppeared {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                        activeSlotX = targetX
                    }
                } else {
                    activeSlotX = targetX
                    railHasAppeared = true
                }
            }
    }

    private func activeSlotIndex(in tokens: [SpaceRailToken]) -> Int? {
        tokens.firstIndex(where: {
            if case .space(_, true) = $0 { return true }
            return false
        })
    }

    private func openBody(for state: DisplayNotchState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            focusedAppHeader(for: state)

            if !state.stackItems.isEmpty {
                stackRows(for: state)
                    .padding(.top, 8)
            } else if !state.visibleSpaceApps.isEmpty {
                bspAppList(for: state)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func focusedAppHeader(for state: DisplayNotchState) -> some View {
        let focusedItem = state.stackItems.first(where: \.isFocused)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let focusedItem {
                    AppIconView(appName: focusedItem.app)

                    HStack(spacing: 5) {
                        Text(focusedItem.app)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(1)

                        let trimmedTitle = focusedItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedTitle.isEmpty, trimmedTitle != focusedItem.app {
                            Text(trimmedTitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.white.opacity(0.34))
                                .lineLimit(1)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("Space \(state.visibleSpaceIndex.map(String.init) ?? "--")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.96))

                        if let type = state.visibleSpaceType?.uppercased(), !state.visibleSpaceApps.isEmpty {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 2.5, height: 2.5)

                            Text(type)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.34))
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    NotchActionButton(systemImage: "slider.horizontal.3", action: model.openSettings)
                    NotchActionButton(systemImage: "arrow.clockwise", action: model.refresh)
                }
            }

            if let stackSummary = state.stackSummary {
                HStack(spacing: 4) {
                    Text("Stack")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))

                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 2, height: 2)

                    Text(stackSummary.badgeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.34))
                }
                .padding(.top, 2)
            } else if state.visibleSpaceApps.isEmpty, state.visibleSpaceIndex != nil {
                Text("No windows")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.22))
                    .padding(.top, 2)
            }
        }
    }

    private func stackRows(for state: DisplayNotchState) -> some View {
        let maxItems = 6
        let displayedItems = Array(state.stackItems.prefix(maxItems))
        let remaining = state.stackItems.count - maxItems

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(displayedItems) { item in
                StackListRow(item: item) {
                    model.focusWindow(item.id)
                }
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }

    private func bspAppList(for state: DisplayNotchState) -> some View {
        let maxApps = 6
        let displayedApps = Array(state.visibleSpaceApps.prefix(maxApps))
        let remaining = state.visibleSpaceApps.count - maxApps

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(displayedApps, id: \.self) { appName in
                bspAppRow(appName)
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }

    private func bspAppRow(_ appName: String) -> some View {
        HStack(spacing: 8) {
            AppIconView(appName: appName)

            Text(appName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func syncExpandedContent(with notchState: YabaiNotchState, animated: Bool) {
        revealTask?.cancel()
        revealTask = nil

        switch notchState {
        case .closed:
            if animated {
                withAnimation(.easeOut(duration: 0.1)) {
                    showsExpandedContent = false
                }
            } else {
                showsExpandedContent = false
            }
        case .open:
            guard animated else {
                showsExpandedContent = true
                return
            }

            revealTask = Task {
                try? await Task.sleep(for: .milliseconds(70))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsExpandedContent = true
                    }
                }
            }
        }
    }

    private func spaceRailTokens(for state: DisplayNotchState, maxVisibleSpaces: Int) -> [SpaceRailToken] {
        let spaces = state.spaceIndexes.sorted()
        let activeSpaceIndex = state.visibleSpaceIndex

        guard !spaces.isEmpty else {
            return [.ellipsis]
        }

        guard spaces.count > maxVisibleSpaces,
              let activeSpaceIndex,
              let activeOffset = spaces.firstIndex(of: activeSpaceIndex) else {
            return spaces.map { .space(index: $0, isActive: $0 == activeSpaceIndex) }
        }

        let halfWindow = maxVisibleSpaces / 2
        var start = max(0, activeOffset - halfWindow)
        let end = min(spaces.count, start + maxVisibleSpaces)
        start = max(0, end - maxVisibleSpaces)

        var tokens: [SpaceRailToken] = []
        if start > 0 {
            tokens.append(.ellipsis)
        }

        tokens.append(contentsOf: spaces[start..<end].map { .space(index: $0, isActive: $0 == activeSpaceIndex) })

        if end < spaces.count {
            tokens.append(.ellipsis)
        }

        return tokens
    }
}
