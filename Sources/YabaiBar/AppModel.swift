import AppKit
import Combine
import Foundation
import YabaiBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: YabaiSnapshot?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isUnavailable = false
    @Published private(set) var activeSpaceIndex: Int?
    @Published private(set) var installationState: InstallationState
    @Published private(set) var loginItemState: LoginItemState

    private let client: YabaiClient
    private let installationManager: AppInstallationManager
    private let loginItemManager: LoginItemManager
    private let configFileURL: URL
    private let configDirectoryURL: URL

    private var hasStarted = false
    private var hasPromptedForInstallation = false
    private var activeSpaceObserver: NSObjectProtocol?
    private var snapshotRefreshTask: Task<Void, Never>?
    private var activeSpaceRefreshTask: Task<Void, Never>?

    init(
        client: YabaiClient = YabaiClient(),
        installationManager: AppInstallationManager = AppInstallationManager(),
        loginItemManager: LoginItemManager = LoginItemManager(),
        configFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("yabai", isDirectory: true)
            .appendingPathComponent("yabairc", isDirectory: false)
    ) {
        let initialInstallationState = installationManager.state
        self.client = client
        self.installationManager = installationManager
        self.loginItemManager = loginItemManager
        self.configFileURL = configFileURL
        configDirectoryURL = configFileURL.deletingLastPathComponent()
        installationState = initialInstallationState
        loginItemState = loginItemManager.currentState(isEligibleForRegistration: initialInstallationState == .installed)
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        installationManager.removeLegacyLaunchAgentIfNeeded()
        refreshInstallationAndLoginItemState()
        promptForInstallationIfNeeded()
        observeActiveSpaceChanges()
        refreshActiveSpace()
        refresh()
    }

    func menuOpened() {
        refresh()
    }

    func refresh() {
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try await Task.detached(priority: .userInitiated) { [client] in
                    try client.fetchSnapshot()
                }.value

                self.snapshot = snapshot
                self.activeSpaceIndex = snapshot.activeSpaceIndex
                self.statusMessage = nil
                self.isUnavailable = false
            } catch {
                self.statusMessage = error.localizedDescription
                self.isUnavailable = self.snapshot == nil
            }
        }
    }

    func focusSpace(_ index: Int) {
        Task { [weak self] in
            guard let self else { return }

            do {
                self.activeSpaceIndex = index
                try await Task.detached(priority: .userInitiated) { [client] in
                    try client.focusSpace(index: index)
                }.value
                self.refreshActiveSpace()
                self.scheduleDelayedActiveSpaceRefresh()
                self.refresh()
            } catch {
                self.statusMessage = error.localizedDescription
                self.isUnavailable = self.snapshot == nil
            }
        }
    }

    func openConfig() {
        NSWorkspace.shared.open(configFileURL)
    }

    func openConfigDirectory() {
        NSWorkspace.shared.open(configDirectoryURL)
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

    var groupedSpaces: [(display: Int, spaces: [SpaceSummary])] {
        let spaces = snapshot?.spaces ?? []
        let groups = Dictionary(grouping: spaces, by: \.display)
        return groups.keys.sorted().map { display in
            (display: display, spaces: groups[display, default: []].sorted { $0.index < $1.index })
        }
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

    func installInApplications() {
        installationState = .moving

        Task { [weak self] in
            guard let self else { return }

            do {
                try installationManager.installAndRelaunch()
                self.quit()
            } catch {
                let message = error.localizedDescription
                self.installationState = .moveFailed(message)
                self.statusMessage = message
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
    }

    private func promptForInstallationIfNeeded() {
        guard !hasPromptedForInstallation else { return }
        hasPromptedForInstallation = true

        installationManager.promptForInstallationIfNeeded { [weak self] in
            self?.installInApplications()
        }
    }

    private func observeActiveSpaceChanges() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshActiveSpace()
                self?.scheduleDelayedActiveSpaceRefresh()
            }
        }
    }

    private func refreshActiveSpace() {
        activeSpaceRefreshTask?.cancel()
        activeSpaceRefreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let activeSpaceIndex = try await Task.detached(priority: .userInitiated) { [client] in
                    try client.fetchActiveSpaceIndex()
                }.value

                self.activeSpaceIndex = activeSpaceIndex
                if self.snapshot != nil || activeSpaceIndex != nil {
                    self.isUnavailable = false
                }
            } catch {
                self.statusMessage = error.localizedDescription
                self.isUnavailable = self.snapshot == nil
            }
        }
    }

    private func scheduleDelayedActiveSpaceRefresh() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            self?.refreshActiveSpace()
        }
    }
}
