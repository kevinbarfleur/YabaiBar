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

private struct ClosedRailSpaceTokenView: View {
    let isActive: Bool
    let namespace: Namespace.ID

    var body: some View {
        Group {
            if isActive {
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: 16, height: 6)
                    .matchedGeometryEffect(id: "closed-rail-active-indicator", in: namespace)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 8)
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
    @Namespace private var closedRailIndicatorNamespace

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
        let badgeLabel = state.stackSummary?.badgeLabel ?? ""

        return ZStack(alignment: .trailing) {
            Text(badgeLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .padding(.trailing, 12)
                .frame(width: viewModel.trailingReservedWidth, alignment: .trailing)
                .mask(alignment: .trailing) {
                    Rectangle()
                        .frame(width: max(0, viewModel.trailingVisibleWidth), alignment: .trailing)
                }
                .opacity(viewModel.trailingVisibleWidth > 0.5 ? 1 : 0)
        }
        .frame(
            width: viewModel.trailingReservedWidth,
            height: viewModel.closedNotchSize.height,
            alignment: .trailing
        )
    }

    private func closedSpaceRail(for state: DisplayNotchState) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(spaceRailTokens(for: state, maxVisibleSpaces: 4).enumerated()), id: \.offset) { _, token in
                switch token {
                case .ellipsis:
                    HStack(spacing: 1.5) {
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                    }
                    .foregroundStyle(.white.opacity(0.18))
                case let .space(_, isActive):
                    ClosedRailSpaceTokenView(
                        isActive: isActive,
                        namespace: closedRailIndicatorNamespace
                    )
                }
            }
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.08), value: state.visibleSpaceIndex)
    }

    private func openBody(for state: DisplayNotchState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(for: state)
            spacesRow(for: state)

            if !state.stackItems.isEmpty {
                stackRows(for: state)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func headerRow(for state: DisplayNotchState) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("Display \(state.displayIndex)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))

                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 2.5, height: 2.5)

                Text("Space \(state.visibleSpaceIndex.map(String.init) ?? "--")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))

                if let badgeLabel = state.stackSummary?.badgeLabel {
                    Text(badgeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.46))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                NotchActionButton(systemImage: "slider.horizontal.3", action: model.openSettings)
                NotchActionButton(systemImage: "arrow.clockwise", action: model.refresh)
            }
        }
    }

    private func spacesRow(for state: DisplayNotchState) -> some View {
        let sortedSpaces = state.spaceIndexes.sorted()

        return HStack(spacing: 8) {
            ForEach(sortedSpaces, id: \.self) { spaceIndex in
                Button {
                    model.focusSpace(spaceIndex)
                } label: {
                    Text("\(spaceIndex)")
                        .font(.system(size: 11, weight: state.visibleSpaceIndex == spaceIndex ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(state.visibleSpaceIndex == spaceIndex ? .white.opacity(0.97) : .white.opacity(0.42))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }

    private func stackRows(for state: DisplayNotchState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(state.stackItems.prefix(3))) { item in
                StackListRow(item: item) {
                    model.focusWindow(item.id)
                }
            }
        }
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
