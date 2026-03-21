import AppKit
import Combine
import SwiftUI

let notchClosedTopRadius: CGFloat = 6
let notchClosedBottomRadius: CGFloat = 14
let notchOpenTopRadius: CGFloat = 19
let notchOpenBottomRadius: CGFloat = 24
let notchShadowPadding: CGFloat = 20
let notchOpenHorizontalPadding: CGFloat = 12
let notchOpenBottomPadding: CGFloat = 12
let notchOpenMinimumWidth: CGFloat = 420

enum YabaiNotchState: Equatable {
    case closed
    case open
}

@MainActor
final class YabaiNotchViewModel: ObservableObject {
    let screenUUID: String

    @Published private(set) var notchState: YabaiNotchState = .closed
    @Published private(set) var isHovering = false
    @Published private(set) var displayState: DisplayNotchState?
    @Published private(set) var hasHardwareNotch = true
    @Published private(set) var centerWidth: CGFloat = 184
    @Published private(set) var leadingWidth: CGFloat = 92
    @Published private(set) var trailingVisibleWidth: CGFloat = 0
    @Published private(set) var trailingReservedWidth: CGFloat = 64
    @Published private(set) var closedNotchSize: CGSize = .init(width: 334, height: 32)
    @Published private(set) var openOuterSize: CGSize = .init(width: 360, height: 96)
    @Published private(set) var openContentHeight: CGFloat = 72
    @Published private(set) var openNotchOnHover = true
    @Published private(set) var minimumHoverDuration = 0.3
    @Published private(set) var enableHaptics = true

    var onStateChange: ((Bool) -> Void)?
    var onLayoutInvalidated: ((Bool) -> Void)?

    private var hoverTask: Task<Void, Never>?

    init(screenUUID: String) {
        self.screenUUID = screenUUID
    }

    func setDisplayState(_ state: DisplayNotchState?) {
        displayState = state
    }

    var closedVisibleWidth: CGFloat {
        leadingWidth + centerWidth + trailingVisibleWidth
    }

    var windowSize: CGSize {
        .init(width: openOuterSize.width, height: openOuterSize.height + notchShadowPadding)
    }

    var topCornerRadius: CGFloat {
        notchState == .open ? notchOpenTopRadius : notchClosedTopRadius
    }

    var bottomCornerRadius: CGFloat {
        notchState == .open ? notchOpenBottomRadius : notchClosedBottomRadius
    }

    var openAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    }

    var closeAnimation: Animation {
        .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    }

    func update(
        for screen: NSScreen,
        state: DisplayNotchState,
        openNotchOnHover: Bool,
        minimumHoverDuration: Double,
        enableHaptics: Bool
    ) {
        hasHardwareNotch = screen.hasHardwareNotch
        centerWidth = screen.resolvedNotchWidth

        let tokenCount = max(1, closedRailTokenCount(for: state))
        leadingWidth = min(126, max(90, CGFloat(tokenCount) * 12 + 28))

        let targetTrailingWidth: CGFloat
        if let badgeLabel = state.stackSummary?.badgeLabel {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            ]
            let labelWidth = NSAttributedString(string: badgeLabel, attributes: attributes).size().width
            targetTrailingWidth = min(76, max(42, ceil(labelWidth) + 18))
        } else {
            targetTrailingWidth = 0
        }

        trailingReservedWidth = 64
        withAnimation(.easeOut(duration: 0.16)) {
            trailingVisibleWidth = min(trailingReservedWidth, targetTrailingWidth)
        }

        let closedHeight = max(30, screen.resolvedNotchHeight)
        closedNotchSize = .init(
            width: leadingWidth + centerWidth + trailingReservedWidth,
            height: closedHeight
        )

        let stackRowCount = min(state.stackItems.count, 3)
        let stackHeight = stackRowCount > 0 ? CGFloat(stackRowCount) * 19 + 8 : 0
        openContentHeight = 46 + 22 + stackHeight

        let availableWidth = max(closedNotchSize.width, screen.frame.width - 48)
        let resolvedWidth = max(closedNotchSize.width, min(availableWidth, notchOpenMinimumWidth))
        openOuterSize = .init(
            width: resolvedWidth,
            height: max(closedHeight + notchOpenBottomPadding + 28, openContentHeight + notchOpenBottomPadding)
        )

        self.openNotchOnHover = openNotchOnHover
        self.minimumHoverDuration = minimumHoverDuration
        self.enableHaptics = enableHaptics

        onLayoutInvalidated?(false)
    }

    func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            withAnimation(openAnimation) {
                isHovering = true
            }

            if notchState == .closed && enableHaptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            }

            guard notchState == .closed, openNotchOnHover else { return }

            hoverTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(minimumHoverDuration))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.notchState == .closed, self.isHovering else { return }
                    self.open(animated: true)
                }
            }
        } else {
            hoverTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(self.closeAnimation) {
                        self.isHovering = false
                    }

                    if self.notchState == .open {
                        self.close(animated: true)
                    }
                }
            }
        }
    }

    func openFromTap() {
        open(animated: true)
    }

    func forceClosed() {
        hoverTask?.cancel()
        hoverTask = nil
        let wasOpen = notchState == .open
        isHovering = false
        notchState = .closed
        if wasOpen {
            onStateChange?(false)
        }
    }

    func invalidate() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func open(animated: Bool) {
        guard notchState != .open else { return }
        if animated {
            withAnimation(openAnimation) {
                notchState = .open
            }
        } else {
            notchState = .open
        }
        onStateChange?(true)
        onLayoutInvalidated?(animated)
    }

    private func close(animated: Bool) {
        guard notchState != .closed else { return }
        if animated {
            withAnimation(closeAnimation) {
                notchState = .closed
            }
        } else {
            notchState = .closed
        }
        onStateChange?(false)
        onLayoutInvalidated?(animated)
    }

    private func closedRailTokenCount(for state: DisplayNotchState) -> Int {
        let spaces = state.spaceIndexes.sorted()
        guard !spaces.isEmpty else {
            return 1
        }

        let activeSpaceIndex = state.visibleSpaceIndex
        let maxVisibleSpaces = 4
        guard spaces.count > maxVisibleSpaces,
              let activeSpaceIndex,
              let activeOffset = spaces.firstIndex(of: activeSpaceIndex) else {
            return spaces.count
        }

        let halfWindow = maxVisibleSpaces / 2
        var start = max(0, activeOffset - halfWindow)
        let end = min(spaces.count, start + maxVisibleSpaces)
        start = max(0, end - maxVisibleSpaces)

        var count = end - start
        if start > 0 {
            count += 1
        }
        if end < spaces.count {
            count += 1
        }

        return count
    }
}

@MainActor
final class NotchSurfaceCoordinator {
    private let model: AppModel
    private var controllers: [String: DisplayNotchWindowController] = [:]
    private var zombieControllers: [String: (controller: DisplayNotchWindowController, deadline: Date)] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var wakeRecoveryTask: Task<Void, Never>?

    private static let zombieGracePeriod: TimeInterval = 8

    init(model: AppModel) {
        self.model = model
        bind()
        reconcileControllers(animated: false)
    }

    private func bind() {
        model.$snapshot
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        model.$activeSpaceIndex
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: true)
            }
            .store(in: &cancellables)

        model.$activeStackSummary
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: true)
            }
            .store(in: &cancellables)

        model.$indicatorSurfaceMode
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        model.$openNotchOnHover
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        model.$minimumHoverDuration
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        model.$enableHaptics
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        model.$isUnavailable
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.reconcileControllers(animated: false)
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.handleSystemWake()
            }
            .store(in: &cancellables)
    }

    private func handleSystemWake() {
        wakeRecoveryTask?.cancel()
        wakeRecoveryTask = Task { [weak self] in
            for delayMs in [300, 800, 1500, 3000] {
                try? await Task.sleep(for: .milliseconds(delayMs))
                guard !Task.isCancelled else { return }
                self?.reconcileControllers(animated: false)
            }
        }
    }

    private func reconcileControllers(animated: Bool) {
        let screenUUIDs = Set(NSScreen.screens.compactMap(\.displayUUID))
        let now = Date()

        // Move disappeared controllers to zombie pool instead of destroying them
        for (displayUUID, controller) in controllers where !screenUUIDs.contains(displayUUID) {
            controller.hide()
            zombieControllers[displayUUID] = (controller, now.addingTimeInterval(Self.zombieGracePeriod))
            controllers.removeValue(forKey: displayUUID)
        }

        // Revive zombies whose displays came back
        for (displayUUID, entry) in zombieControllers where screenUUIDs.contains(displayUUID) {
            controllers[displayUUID] = entry.controller
            zombieControllers.removeValue(forKey: displayUUID)
        }

        // Purge expired zombies
        for (displayUUID, entry) in zombieControllers where now > entry.deadline {
            entry.controller.invalidate()
            zombieControllers.removeValue(forKey: displayUUID)
        }

        // Create new controllers for truly new displays
        for displayUUID in screenUUIDs where controllers[displayUUID] == nil {
            controllers[displayUUID] = DisplayNotchWindowController(model: model, displayUUID: displayUUID)
        }

        controllers.values.forEach { $0.refresh(animated: animated) }
    }
}

@MainActor
private final class DisplayNotchWindowController {
    private let model: AppModel
    private let displayUUID: String
    private let viewModel: YabaiNotchViewModel
    private let window: YabaiNotchWindow
    private var lastStableState: DisplayNotchState?

    init(model: AppModel, displayUUID: String) {
        self.model = model
        self.displayUUID = displayUUID
        viewModel = YabaiNotchViewModel(screenUUID: displayUUID)
        window = YabaiNotchWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(
            rootView: YabaiNotchSurfaceView(model: model, viewModel: viewModel)
        )

        viewModel.onStateChange = { [weak self] isOpen in
            guard let self else { return }
            self.model.notchSurfaceDidChangeOpenState(displayUUID: self.displayUUID, isOpen: isOpen)
        }

        viewModel.onLayoutInvalidated = { [weak self] animated in
            self?.layoutWindow(animated: animated)
        }
    }

    func refresh(animated: Bool) {
        guard model.indicatorPresentationState.showsNotchSurface,
              let screen = NSScreen.matchingDisplayUUID(displayUUID) else {
            viewModel.forceClosed()
            viewModel.setDisplayState(nil)
            lastStableState = nil
            window.orderOut(nil)
            return
        }

        if let freshState = model.displayNotchState(for: displayUUID) {
            if freshState.isNativeFullscreen {
                viewModel.forceClosed()
                viewModel.setDisplayState(freshState)
                lastStableState = freshState
                window.orderOut(nil)
                return
            }

            lastStableState = freshState
            viewModel.setDisplayState(freshState)
            viewModel.update(
                for: screen,
                state: freshState,
                openNotchOnHover: model.openNotchOnHover,
                minimumHoverDuration: model.minimumHoverDuration,
                enableHaptics: model.enableHaptics
            )

            layoutWindow(animated: animated)
            window.orderFrontRegardless()
            return
        }

        guard let lastStableState, !lastStableState.isNativeFullscreen else {
            viewModel.forceClosed()
            viewModel.setDisplayState(nil)
            self.lastStableState = nil
            window.orderOut(nil)
            return
        }

        viewModel.setDisplayState(lastStableState)
        viewModel.update(
            for: screen,
            state: lastStableState,
            openNotchOnHover: model.openNotchOnHover,
            minimumHoverDuration: model.minimumHoverDuration,
            enableHaptics: model.enableHaptics
        )

        layoutWindow(animated: animated)
        window.orderFrontRegardless()
    }

    func hide() {
        viewModel.forceClosed()
        window.orderOut(nil)
    }

    func invalidate() {
        viewModel.invalidate()
        viewModel.setDisplayState(nil)
        lastStableState = nil
        window.orderOut(nil)
    }

    private func layoutWindow(animated: Bool) {
        guard let screen = NSScreen.matchingDisplayUUID(displayUUID) else { return }

        let frame = NSRect(
            x: screen.frame.midX - viewModel.windowSize.width / 2,
            y: screen.frame.maxY - viewModel.windowSize.height,
            width: viewModel.windowSize.width,
            height: viewModel.windowSize.height
        )

        guard animated, window.isVisible else {
            window.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = viewModel.notchState == .open ? 0.24 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}

private final class YabaiNotchWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        isReleasedWhenClosed = false
        level = .mainMenu + 3
        hasShadow = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
