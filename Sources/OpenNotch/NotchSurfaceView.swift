import AppKit
import OpenNotchCore
import SwiftUI

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

struct NotchSurfaceView: View {
    @ObservedObject var viewModel: YabaiNotchViewModel
    let showsNotchSurface: Bool
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    @State private var showsExpandedContent = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if !viewModel.leadingSlots.isEmpty || !viewModel.trailingSlots.isEmpty {
                    mainLayout
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: viewModel.windowSize.width, maxHeight: viewModel.windowSize.height, alignment: .topLeading)
        .compositingGroup()
        .preferredColorScheme(.dark)
        .allowsHitTesting(showsNotchSurface)
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

    private var mainLayout: some View {
        let isOpen = viewModel.notchState == .open
        let outerWidth = isOpen ? viewModel.openOuterSize.width : viewModel.closedNotchSize.width
        let innerWidth = max(1, outerWidth - (isOpen ? notchOpenHorizontalPadding * 2 : 0))
        let innerHeight = isOpen ? max(1, viewModel.openOuterSize.height - notchOpenBottomPadding) : viewModel.closedNotchSize.height

        return Group {
            notchLayout
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
                    color: ((viewModel.notchState == .open || viewModel.isHovering) && showsNotchSurface)
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
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBand
                .frame(height: viewModel.closedNotchSize.height)
                .zIndex(2)

            if viewModel.notchState == .open || showsExpandedContent {
                openBody
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

    private static let slotSpacing: CGFloat = 4
    private static let leadingInset: CGFloat = 18
    private static let trailingInset: CGFloat = 12

    private var topBand: some View {
        HStack(spacing: 0) {
            HStack(spacing: Self.slotSpacing) {
                ForEach(Array(viewModel.leadingSlots.enumerated()), id: \.offset) { _, slot in
                    slot.view
                        .frame(width: slot.width, height: viewModel.closedNotchSize.height)
                }
            }
            .padding(.leading, Self.leadingInset)
            .frame(width: viewModel.leadingWidth, alignment: .leading)

            Spacer(minLength: viewModel.centerWidth)

            HStack(spacing: Self.slotSpacing) {
                ForEach(Array(viewModel.trailingSlots.enumerated()), id: \.offset) { _, slot in
                    slot.view
                        .frame(width: slot.width, height: viewModel.closedNotchSize.height)
                }
            }
            .padding(.trailing, Self.trailingInset)
            .frame(minWidth: viewModel.trailingReservedWidth, alignment: .trailing)
        }
        .frame(minWidth: viewModel.closedNotchSize.width, maxWidth: .infinity, maxHeight: viewModel.closedNotchSize.height)
    }

    private var openBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.expandedWidgets) { widget in
                widget.content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}
