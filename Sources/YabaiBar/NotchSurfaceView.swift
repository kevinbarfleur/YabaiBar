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

private struct DotGlyph: View {
    let isActive: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(isActive ? Color.white : Color.white.opacity(0.22))
            .frame(width: isActive ? 16 : 6, height: 6)
    }
}

struct YabaiNotchSurfaceView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var viewModel: YabaiNotchViewModel
    @State private var showsExpandedContent = false
    @State private var revealTask: Task<Void, Never>?

    private var state: DisplayNotchState? {
        model.displayNotchState(for: viewModel.screenUUID)
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
        HStack(spacing: 5) {
            ForEach(Array(spaceRailTokens(for: state, maxVisibleSpaces: 4).enumerated()), id: \.offset) { _, token in
                switch token {
                case .ellipsis:
                    HStack(spacing: 2) {
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                        Circle().frame(width: 2, height: 2)
                    }
                    .foregroundStyle(.white.opacity(0.18))
                case let .space(_, isActive):
                    DotGlyph(isActive: isActive)
                }
            }
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openBody(for state: DisplayNotchState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(for: state)
            spacesRow(for: state)

            if !state.stackItems.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.05))
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                stackRows(for: state)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func headerRow(for state: DisplayNotchState) -> some View {
        HStack(spacing: 8) {
            Text("Space \(state.visibleSpaceIndex.map(String.init) ?? "--")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))

            if let badgeLabel = state.stackSummary?.badgeLabel {
                Text(badgeLabel)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: model.openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Button(action: model.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func spacesRow(for state: DisplayNotchState) -> some View {
        HStack(spacing: 12) {
            ForEach(state.spaceIndexes.sorted(), id: \.self) { spaceIndex in
                Button {
                    model.focusSpace(spaceIndex)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(spaceIndex)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(state.visibleSpaceIndex == spaceIndex ? .white.opacity(0.96) : .white.opacity(0.38))

                        Capsule(style: .continuous)
                            .fill(state.visibleSpaceIndex == spaceIndex ? Color.white.opacity(0.9) : Color.clear)
                            .frame(width: 12, height: 1.5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 9)
    }

    private func stackRows(for state: DisplayNotchState) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(state.stackItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                Button {
                    model.focusWindow(item.id)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(item.position)")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(item.isFocused ? .white.opacity(0.52) : .white.opacity(0.22))
                            .frame(width: 14, alignment: .leading)

                        Text(item.app)
                            .font(.system(size: 11, weight: item.isFocused ? .semibold : .medium))
                            .foregroundStyle(item.isFocused ? .white.opacity(0.95) : .white.opacity(0.7))
                            .lineLimit(1)

                        let trimmedTitle = stackItemTitle(item)
                        if !trimmedTitle.isEmpty {
                            Text(trimmedTitle)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(item.isFocused ? .white.opacity(0.34) : .white.opacity(0.18))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)

                if index < min(state.stackItems.count, 3) - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.04))
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

    private func stackItemTitle(_ item: ActiveStackItemSummary) -> String {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty || trimmedTitle == item.app {
            return ""
        }

        return trimmedTitle
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
