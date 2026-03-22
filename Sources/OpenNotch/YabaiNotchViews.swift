import AppKit
import SwiftUI
import OpenNotchCore

// MARK: - Closed Notch Slots

struct YabaiSpaceRailSlot: View {
    let state: DisplayNotchState
    let tokens: [SpaceRailToken]
    let style: SpaceIndicatorStyle

    @State private var activeSlotX: CGFloat = 0
    @State private var hasAppeared = false

    var body: some View {
        Group {
            switch style {
            case .metaball:
                MetaballSpaceRailView(tokens: tokens, animatedActiveX: activeSlotX)
                    .onAppear {
                        if let slot = activeSlotIndex(in: tokens) {
                            activeSlotX = MetaballSpaceRailView.slotCenterX(for: slot)
                        }
                        hasAppeared = true
                    }
                    .onChange(of: state.visibleSpaceIndex) { _, _ in
                        let fresh = tokens
                        guard let slot = activeSlotIndex(in: fresh) else { return }
                        let targetX = MetaballSpaceRailView.slotCenterX(for: slot)
                        if hasAppeared {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                                activeSlotX = targetX
                            }
                        } else {
                            activeSlotX = targetX
                            hasAppeared = true
                        }
                    }
            case .numbers:
                NumberSpaceRailView(tokens: tokens)
            }
        }
    }

    private func activeSlotIndex(in tokens: [SpaceRailToken]) -> Int? {
        tokens.firstIndex(where: {
            if case .space(_, true) = $0 { return true }
            return false
        })
    }
}

// MARK: - Number Space Rail

struct NumberSpaceRailView: View {
    let tokens: [SpaceRailToken]

    static let itemWidth: CGFloat = 12
    static let spacing: CGFloat = 2

    static func contentWidth(for tokenCount: Int) -> CGFloat {
        CGFloat(tokenCount) * itemWidth + CGFloat(max(0, tokenCount - 1)) * spacing
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .ellipsis:
                    Text("…")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(width: Self.itemWidth)
                case .space(let index, let isActive):
                    Text("\(index)")
                        .font(.system(size: 11, weight: isActive ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.3))
                        .frame(width: Self.itemWidth)
                }
            }
        }
    }
}

struct YabaiStackBadgeSlot: View {
    let badgeLabel: String?

    var body: some View {
        ZStack(alignment: .trailing) {
            if let badgeLabel {
                Text(badgeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.trailing, 12)
                    .frame(width: 64, alignment: .trailing)
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
        .frame(width: 64, height: 32, alignment: .trailing)
    }
}

// MARK: - Expanded Widget Content

struct YabaiExpandedContent: View {
    let state: DisplayNotchState
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void
    let onFocusWindow: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            focusedAppHeader

            if !isCollapsed {
                if !state.stackItems.isEmpty {
                    stackRows
                        .padding(.top, 8)
                } else if !state.visibleSpaceApps.isEmpty {
                    bspAppList
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, isCollapsed ? 6 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCollapsed)
    }

    @ViewBuilder
    private var focusedAppHeader: some View {
        let focusedItem = state.stackItems.first(where: \.isFocused)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Button(action: onToggleCollapse) {
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

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.22))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    NotchActionButton(systemImage: "slider.horizontal.3", action: onOpenSettings)
                    NotchActionButton(systemImage: "arrow.clockwise", action: onRefresh)
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

    private var stackRows: some View {
        let maxItems = 6
        let displayedItems = Array(state.stackItems.prefix(maxItems))
        let remaining = state.stackItems.count - maxItems

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(displayedItems) { item in
                StackListRow(item: item) {
                    onFocusWindow(item.id)
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

    private var bspAppList: some View {
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
}

// MARK: - Shared Components

struct NotchActionButton: View {
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

struct AppIconView: View {
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

struct StackListRow: View {
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

// MARK: - MetaballSpaceRailView (shared)

@MainActor
struct MetaballSpaceRailView: View, Animatable {
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
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                if case .space(_, let isActive) = token, !isActive {
                    let cx = Self.slotCenterX(for: index)
                    let distance = abs(cx - animatedActiveX)
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

        for (index, token) in tokens.enumerated() {
            guard case .space(_, let isActive) = token, !isActive else { continue }

            let cx = slotCenterX(for: index)
            let distance = abs(cx - activeX)
            let proximityT = max(0, 1 - distance / proximityRadius)

            guard proximityT > 0.08 else { continue }

            let dotR = dotDiameter / 2
            let reach = proximityT * proximityT
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
