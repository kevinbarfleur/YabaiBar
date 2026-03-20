import AppKit
import Foundation
import YabaiBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: YabaiSnapshot?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isUnavailable = false
    @Published private(set) var activeSpaceIndex: Int?
    @Published private(set) var activeStackSummary: ActiveStackSummary?
    @Published private(set) var installationState: InstallationState
    @Published private(set) var loginItemState: LoginItemState
    @Published private(set) var integrationState: YabaiIntegrationState

    private let client: YabaiClient
    private let installationManager: AppInstallationManager
    private let loginItemManager: LoginItemManager
    private let integrationManager: YabaiIntegrationManager
    private let runtimeMonitor: YabaiRuntimeMonitor
    private let configFileURL: URL
    private let configDirectoryURL: URL

    private var hasStarted = false
    private var hasPromptedForInstallation = false
    private var activeSpaceObserver: NSObjectProtocol?
    private var snapshotRefreshTask: Task<Void, Never>?
    private var displayReconcileTask: Task<Void, Never>?
    private var integrationTask: Task<Void, Never>?
    private var liveState: YabaiLiveState?

    private struct ReconciledDisplayState: Sendable {
        let activeSpaceIndex: Int?
        let activeStackSummary: ActiveStackSummary?
    }

    init(
        client: YabaiClient = YabaiClient(),
        installationManager: AppInstallationManager = AppInstallationManager(),
        loginItemManager: LoginItemManager = LoginItemManager(),
        integrationManager: YabaiIntegrationManager = YabaiIntegrationManager(),
        configFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("yabai", isDirectory: true)
            .appendingPathComponent("yabairc", isDirectory: false)
    ) {
        let initialInstallationState = installationManager.state
        self.client = client
        self.installationManager = installationManager
        self.loginItemManager = loginItemManager
        self.integrationManager = integrationManager
        self.configFileURL = configFileURL
        configDirectoryURL = configFileURL.deletingLastPathComponent()
        runtimeMonitor = YabaiRuntimeMonitor(stateURL: integrationManager.runtimeStateURL)
        installationState = initialInstallationState
        loginItemState = loginItemManager.currentState(isEligibleForRegistration: initialInstallationState == .installed)
        integrationState = integrationManager.state(isEligible: initialInstallationState == .installed)

        runtimeMonitor.onStateChange = { [weak self] state in
            self?.applyLiveState(state)
        }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        installationManager.removeLegacyLaunchAgentIfNeeded()
        refreshInstallationAndLoginItemState()
        promptForInstallationIfNeeded()
        ensureIntegrationIfNeeded()
        observeActiveSpaceChanges()
        refresh()
    }

    func menuOpened() {
        refreshSnapshot()
    }

    func refresh() {
        reconcileDisplayedState()
        refreshSnapshot()
    }

    func focusSpace(_ index: Int) {
        Task { [weak self] in
            guard let self else { return }

            do {
                activeSpaceIndex = index
                if let trackedState = liveState?.spaces[index] {
                    activeStackSummary = trackedState.activeStackSummary
                } else if liveState == nil {
                    activeStackSummary = nil
                }

                try await Task.detached(priority: .userInitiated) { [client] in
                    try client.focusSpace(index: index)
                }.value

                reconcileDisplayedState(afterDelays: [40, 140, 320])
                refreshSnapshot(after: 220)
            } catch {
                statusMessage = error.localizedDescription
                isUnavailable = snapshot == nil && liveState == nil
            }
        }
    }

    func openConfig() {
        NSWorkspace.shared.open(configFileURL)
    }

    func openConfigDirectory() {
        NSWorkspace.shared.open(configDirectoryURL)
    }

    func repairIntegration() {
        ensureIntegrationIfNeeded(force: true)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    var activeSpaceLabel: String {
        if let activeSpaceIndex {
            return String(activeSpaceIndex)
        }

        return "--"
    }

    var activeSpaceDisplayLabel: String {
        guard let activeStackSummary else {
            return activeSpaceLabel
        }

        return "\(activeSpaceLabel) · \(activeStackSummary.badgeLabel)"
    }

    var activeStackMenuLabel: String? {
        guard let activeStackSummary else {
            return nil
        }

        if let focusedAppName = activeStackSummary.focusedAppName, !focusedAppName.isEmpty {
            return "Stack \(activeStackSummary.badgeLabel) · \(focusedAppName)"
        }

        return "Stack \(activeStackSummary.badgeLabel)"
    }

    var activeSpaceTooltip: String {
        guard activeSpaceLabel != "--" else {
            return "Current space unavailable"
        }

        if let activeStackMenuLabel {
            return "Current space \(activeSpaceLabel) · \(activeStackMenuLabel)"
        }

        return "Current space \(activeSpaceLabel)"
    }

    var groupedSpaces: [(display: Int, spaces: [SpaceSummary])] {
        let spaces = snapshot?.spaces ?? []
        let groups = Dictionary(grouping: spaces, by: \.display)
        return groups.keys.sorted().map { display in
            (display: display, spaces: groups[display, default: []].sorted { $0.index < $1.index })
        }
    }

    var spaces: [SpaceSummary] {
        snapshot?.spaces ?? []
    }

    var canMoveToApplications: Bool {
        installationState == .needsMove || {
            if case .moveFailed = installationState { return true }
            return false
        }()
    }

    var needsLoginApproval: Bool {
        loginItemState == .requiresApproval
    }

    var canRepairIntegration: Bool {
        integrationState.canRepair
    }

    func isSpaceFocused(_ index: Int) -> Bool {
        activeSpaceIndex == index
    }

    func installInApplications() {
        installationState = .moving

        Task { [weak self] in
            guard let self else { return }

            do {
                try installationManager.installAndRelaunch()
                quit()
            } catch {
                let message = error.localizedDescription
                installationState = .moveFailed(message)
                statusMessage = message
            }
        }
    }

    func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func refreshInstallationAndLoginItemState() {
        installationState = installationManager.state
        let eligibleForRegistration = installationState == .installed
        loginItemState = loginItemManager.currentState(isEligibleForRegistration: eligibleForRegistration)

        if eligibleForRegistration, loginItemState == .notRegistered {
            loginItemState = loginItemManager.ensureEnabled(isEligibleForRegistration: eligibleForRegistration)
        }

        integrationState = integrationManager.state(isEligible: eligibleForRegistration)
    }

    private func promptForInstallationIfNeeded() {
        guard !hasPromptedForInstallation else { return }
        hasPromptedForInstallation = true

        installationManager.promptForInstallationIfNeeded { [weak self] in
            self?.installInApplications()
        }
    }

    private func ensureIntegrationIfNeeded(force: Bool = false) {
        integrationTask?.cancel()

        guard installationState == .installed else {
            runtimeMonitor.stop()
            liveState = nil
            integrationState = integrationManager.state(isEligible: false)
            return
        }

        let integrationManager = self.integrationManager
        integrationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let currentState = integrationManager.state(isEligible: true)
                let nextState: YabaiIntegrationState

                if force || currentState != .installed {
                    nextState = try await Task.detached(priority: .userInitiated) {
                        try integrationManager.ensureInstalled(isEligible: true)
                    }.value
                } else {
                    try await Task.detached(priority: .userInitiated) {
                        try integrationManager.bootstrapRuntimeState()
                    }.value
                    nextState = currentState
                }

                runtimeMonitor.start()
                integrationState = nextState
                statusMessage = nil
            } catch {
                runtimeMonitor.stop()
                integrationState = .repairFailed(error.localizedDescription)
                statusMessage = error.localizedDescription
                isUnavailable = snapshot == nil && liveState == nil
            }
        }
    }

    private func observeActiveSpaceChanges() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                reconcileDisplayedState(afterDelays: [0, 80, 220])
                refreshSnapshot(after: liveState == nil ? 220 : 140)
            }
        }
    }

    private func applyLiveState(_ state: YabaiLiveState?) {
        liveState = state

        guard let state else {
            reconcileDisplayedState(afterDelays: [0, 80, 220])
            return
        }

        if snapshot != nil || state.activeSpaceIndex != nil {
            isUnavailable = false
            statusMessage = nil
        }

        reconcileDisplayedState(
            afterDelays: state.activeStackSummary == nil ? [0, 80, 220] : [0, 60, 160]
        )
    }

    private func reconcileDisplayedState(afterDelays delays: [Int] = [0, 140, 360]) {
        displayReconcileTask?.cancel()
        displayReconcileTask = Task { [weak self] in
            guard let self else { return }

            let normalizedDelays = delays.isEmpty ? [0] : delays

            for (attemptIndex, delayMilliseconds) in normalizedDelays.enumerated() {
                if delayMilliseconds > 0 {
                    try? await Task.sleep(for: .milliseconds(delayMilliseconds))
                }

                guard !Task.isCancelled else { return }

                do {
                    let reconciledState = try await Task.detached(priority: .userInitiated) { [client] in
                        let activeSpaceIndex = try client.fetchActiveSpaceIndex()
                        let activeStackSummary = try client.fetchActiveStackSummary()
                        return ReconciledDisplayState(
                            activeSpaceIndex: activeSpaceIndex,
                            activeStackSummary: activeStackSummary
                        )
                    }.value

                    applyReconciledDisplayState(
                        reconciledState,
                        isFinalAttempt: attemptIndex == normalizedDelays.count - 1
                    )
                } catch {
                    if attemptIndex == normalizedDelays.count - 1 {
                        statusMessage = error.localizedDescription
                        isUnavailable = snapshot == nil && activeSpaceIndex == nil
                    }
                }
            }
        }
    }

    private func applyReconciledDisplayState(_ reconciledState: ReconciledDisplayState, isFinalAttempt: Bool) {
        activeSpaceIndex = reconciledState.activeSpaceIndex

        if let activeStackSummary = reconciledState.activeStackSummary {
            self.activeStackSummary = activeStackSummary
        } else if reconciledState.activeSpaceIndex == nil
            || self.activeStackSummary?.spaceIndex != reconciledState.activeSpaceIndex
            || isFinalAttempt {
            activeStackSummary = nil
        }

        if snapshot != nil || reconciledState.activeSpaceIndex != nil {
            isUnavailable = false
            statusMessage = nil
        }
    }

    private func refreshSnapshot(after delayMilliseconds: Int = 0) {
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = Task { [weak self] in
            guard let self else { return }

            if delayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            }

            guard !Task.isCancelled else { return }

            do {
                let fetchedSnapshot = try await Task.detached(priority: .userInitiated) { [client] in
                    try client.fetchSnapshot()
                }.value

                snapshot = fetchedSnapshot

                statusMessage = nil
                isUnavailable = false
            } catch {
                statusMessage = error.localizedDescription
                isUnavailable = snapshot == nil && liveState == nil
            }
        }
    }
}
