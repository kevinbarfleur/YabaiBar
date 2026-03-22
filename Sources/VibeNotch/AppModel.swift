import AppKit
import Combine
import Foundation
import VibeNotchCore

enum IndicatorSurfaceMode: String, CaseIterable, Identifiable {
    case topBar
    case notch
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topBar:
            return "Top Bar"
        case .notch:
            return "Notch"
        case .both:
            return "Both"
        }
    }

    var summary: String {
        switch self {
        case .topBar:
            return "Indicators stay next to the menu bar icon. The notch surface is hidden."
        case .notch:
            return "Indicators move into the notch. The menu bar keeps a small icon only."
        case .both:
            return "Indicators are shown in both the menu bar and the notch."
        }
    }
}

enum SpaceIndicatorStyle: String, CaseIterable, Identifiable {
    case metaball
    case numbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metaball: return "Dots"
        case .numbers: return "Numbers"
        }
    }
}

enum MenuBarLabelMode: String, CaseIterable, Identifiable {
    case iconAndNumber
    case numberOnly
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconAndNumber:
            return "Icon + number"
        case .numberOnly:
            return "Number only"
        case .iconOnly:
            return "Icon only"
        }
    }
}

struct IndicatorPresentationState: Equatable {
    let showsStatusItem: Bool
    let showsNotchSurface: Bool
    let statusItemShowsIconOnly: Bool
    let statusItemShowsText: Bool
    let statusItemShowsImage: Bool
}

struct DisplayNotchState: Identifiable, Equatable {
    let id: String
    let displayUUID: String
    let displayIndex: Int
    let isActiveDisplay: Bool
    let spaceIndexes: [Int]
    let visibleSpaceIndex: Int?
    let visibleSpaceType: String?
    let visibleSpaceApps: [String]
    let stackSummary: ActiveStackSummary?
    let stackItems: [ActiveStackItemSummary]
    let isNativeFullscreen: Bool
}

enum SpaceDiagnosticsStatus: Equatable {
    case notStack
    case notTracked
    case liveOnly
    case unresolvedFocus
    case synced
    case countMismatch
    case focusMismatch
    case staleLocal

    var title: String {
        switch self {
        case .notStack:
            return "Not a stack"
        case .notTracked:
            return "Not tracked"
        case .liveOnly:
            return "Live only"
        case .unresolvedFocus:
            return "Focus unresolved"
        case .synced:
            return "Synced"
        case .countMismatch:
            return "Count mismatch"
        case .focusMismatch:
            return "Focus mismatch"
        case .staleLocal:
            return "Stale local state"
        }
    }
}

struct SpaceDiagnosticsComparison: Equatable {
    let trackedState: TrackedStackState?
    let liveSummary: ActiveStackSummary?
    let status: SpaceDiagnosticsStatus
}

@MainActor
final class AppModel: ObservableObject {
    private enum DefaultsKey {
        static let indicatorSurfaceMode = "YabaiBar.indicatorSurfaceMode"
        static let menuBarLabelMode = "YabaiBar.menuBarLabelMode"
        static let showAppNamesInMenu = "YabaiBar.showAppNamesInMenu"
        static let maxAppsShownPerSpace = "YabaiBar.maxAppsShownPerSpace"
        static let groupSpacesByDisplay = "YabaiBar.groupSpacesByDisplay"
        static let openNotchOnHover = "YabaiBar.openNotchOnHover"
        static let minimumHoverDuration = "YabaiBar.minimumHoverDuration"
        static let enableHaptics = "YabaiBar.enableHaptics"
        static let spaceIndicatorStyle = "YabaiBar.spaceIndicatorStyle"
        static let legacyNotchEnabled = "YabaiBar.notchEnabled"
    }

    let moduleRegistry = ModuleRegistry()

    @Published private(set) var snapshot: YabaiSnapshot?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isUnavailable = false
    @Published private(set) var activeSpaceIndex: Int?
    @Published private(set) var activeDisplayUUID: String?
    @Published private(set) var activeSpaceType: String?
    @Published private(set) var activeSpaceIsNativeFullscreen = false
    @Published private(set) var activeStackSummary: ActiveStackSummary?
    @Published private(set) var diagnosticsSnapshot: YabaiDiagnosticsSnapshot?
    @Published private(set) var diagnosticsUpdatedAt: Date?
    @Published private(set) var diagnosticsStatusMessage: String?
    @Published private(set) var indicatorSurfaceMode: IndicatorSurfaceMode
    @Published private(set) var menuBarLabelMode: MenuBarLabelMode
    @Published private(set) var spaceIndicatorStyle: SpaceIndicatorStyle
    @Published private(set) var showAppNamesInMenu: Bool
    @Published private(set) var maxAppsShownPerSpace: Int
    @Published private(set) var groupSpacesByDisplay: Bool
    @Published private(set) var openNotchOnHover: Bool
    @Published private(set) var minimumHoverDuration: Double
    @Published private(set) var enableHaptics: Bool
    @Published private(set) var yabaiConfigContent: String?
    @Published private(set) var skhdConfigContent: String?
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
    private let skhdConfigFileURL: URL
    private var openSettingsHandler: (() -> Void)?

    private var hasStarted = false
    private var hasPromptedForInstallation = false
    private var activeSpaceObserver: NSObjectProtocol?
    private var snapshotRefreshTask: Task<Void, Never>?
    private var diagnosticsRefreshTask: Task<Void, Never>?
    private var displayReconcileTask: Task<Void, Never>?
    private var integrationTask: Task<Void, Never>?
    private var liveState: YabaiLiveState?
    private var openNotchDisplayUUIDs = Set<String>()
    private var registryCancellable: AnyCancellable?
    private var settingsBackupTask: Task<Void, Never>?

    private struct ReconciledDisplayState: Sendable {
        let activeSpaceIndex: Int?
        let activeStackSummary: ActiveStackSummary?
        let activeDisplayUUID: String?
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
        let defaults = UserDefaults.standard
        let storedIndicatorSurfaceMode = defaults.string(forKey: DefaultsKey.indicatorSurfaceMode)
            .flatMap(IndicatorSurfaceMode.init(rawValue:))
            ?? {
                if let legacyNotchEnabled = defaults.object(forKey: DefaultsKey.legacyNotchEnabled) as? Bool {
                    return legacyNotchEnabled ? .both : .topBar
                }

                return .both
            }()
        let storedMenuBarLabelMode = defaults.string(forKey: DefaultsKey.menuBarLabelMode)
            .flatMap(MenuBarLabelMode.init(rawValue:))
            ?? .iconAndNumber
        let storedSpaceIndicatorStyle = defaults.string(forKey: DefaultsKey.spaceIndicatorStyle)
            .flatMap(SpaceIndicatorStyle.init(rawValue:))
            ?? .metaball
        let storedShowAppNamesInMenu: Bool = defaults.object(forKey: DefaultsKey.showAppNamesInMenu) as? Bool ?? true
        let storedMaxAppsShownPerSpace = min(3, max(1, defaults.object(forKey: DefaultsKey.maxAppsShownPerSpace) as? Int ?? 2))
        let storedGroupSpacesByDisplay: Bool = defaults.object(forKey: DefaultsKey.groupSpacesByDisplay) as? Bool ?? true
        let storedOpenNotchOnHover: Bool = defaults.object(forKey: DefaultsKey.openNotchOnHover) as? Bool ?? true
        let storedMinimumHoverDuration = min(1, max(0, defaults.object(forKey: DefaultsKey.minimumHoverDuration) as? Double ?? 0.3))
        let storedEnableHaptics: Bool = defaults.object(forKey: DefaultsKey.enableHaptics) as? Bool ?? true
        self.client = client
        self.installationManager = installationManager
        self.loginItemManager = loginItemManager
        self.integrationManager = integrationManager
        self.configFileURL = configFileURL
        configDirectoryURL = configFileURL.deletingLastPathComponent()
        skhdConfigFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("skhd", isDirectory: true)
            .appendingPathComponent("skhdrc", isDirectory: false)
        runtimeMonitor = YabaiRuntimeMonitor(stateURL: integrationManager.runtimeStateURL)
        indicatorSurfaceMode = storedIndicatorSurfaceMode
        menuBarLabelMode = storedMenuBarLabelMode
        spaceIndicatorStyle = storedSpaceIndicatorStyle
        showAppNamesInMenu = storedShowAppNamesInMenu
        maxAppsShownPerSpace = storedMaxAppsShownPerSpace
        groupSpacesByDisplay = storedGroupSpacesByDisplay
        openNotchOnHover = storedOpenNotchOnHover
        minimumHoverDuration = storedMinimumHoverDuration
        enableHaptics = storedEnableHaptics
        installationState = initialInstallationState
        loginItemState = loginItemManager.currentState(isEligibleForRegistration: initialInstallationState == .installed)
        integrationState = integrationManager.state(isEligible: initialInstallationState == .installed)

        runtimeMonitor.onStateChange = { [weak self] state in
            self?.applyLiveState(state)
        }

        registryCancellable = moduleRegistry.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        // Migrate settings from old OpenNotch app, then restore from backup if needed
        SettingsBackupManager.migrateFromOldAppIfNeeded()
        SettingsBackupManager.restoreBackupIfNeeded()
        JiraClient.migrateFromOldKeychainIfNeeded()

        let yabaiModule = YabaiModule(appModel: self)
        moduleRegistry.register(yabaiModule)

        let aiQuotaModule = AIQuotaModule()
        moduleRegistry.register(aiQuotaModule)

        let jiraModule = JiraModule()
        moduleRegistry.register(jiraModule)

        let todoListModule = TodoListModule()
        moduleRegistry.register(todoListModule)

        installationManager.removeLegacyLaunchAgentIfNeeded()
        refreshInstallationAndLoginItemState()
        promptForInstallationIfNeeded()
        ensureIntegrationIfNeeded()
        observeActiveSpaceChanges()
        refresh()

        // Auto-backup settings after startup
        SettingsBackupManager.exportBackup()
    }

    func menuOpened() {
        refreshSnapshot()
    }

    func refresh() {
        reconcileDisplayedState()
        refreshSnapshot()
        refreshDiagnostics()
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

    func focusWindow(_ id: Int) {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.detached(priority: .userInitiated) { [client] in
                    try client.focusWindow(id: id)
                }.value

                reconcileDisplayedState(afterDelays: [30, 100, 240])
                refreshSnapshot(after: 120)
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

    func quitApplication(pid: Int, spaceIndex: Int) {
        guard pid > 0 else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return }
        app.terminate()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            self.recheckSpace(spaceIndex)
            self.refreshDiagnostics()
        }
    }

    func openSkhdConfig() {
        NSWorkspace.shared.open(skhdConfigFileURL)
    }

    func loadConfigFiles() {
        yabaiConfigContent = try? String(contentsOf: configFileURL, encoding: .utf8)
        skhdConfigContent = try? String(contentsOf: skhdConfigFileURL, encoding: .utf8)
    }

    func repairIntegration() {
        ensureIntegrationIfNeeded(force: true)
    }

    func setIndicatorSurfaceMode(_ mode: IndicatorSurfaceMode) {
        indicatorSurfaceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.indicatorSurfaceMode)
        scheduleSettingsBackup()
    }

    func setMenuBarLabelMode(_ mode: MenuBarLabelMode) {
        menuBarLabelMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.menuBarLabelMode)
        scheduleSettingsBackup()
    }

    func setSpaceIndicatorStyle(_ style: SpaceIndicatorStyle) {
        spaceIndicatorStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: DefaultsKey.spaceIndicatorStyle)
        scheduleSettingsBackup()
    }

    func setShowAppNamesInMenu(_ enabled: Bool) {
        showAppNamesInMenu = enabled
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.showAppNamesInMenu)
        scheduleSettingsBackup()
    }

    func setMaxAppsShownPerSpace(_ count: Int) {
        let resolvedCount = min(3, max(1, count))
        maxAppsShownPerSpace = resolvedCount
        UserDefaults.standard.set(resolvedCount, forKey: DefaultsKey.maxAppsShownPerSpace)
        scheduleSettingsBackup()
    }

    func setGroupSpacesByDisplay(_ enabled: Bool) {
        groupSpacesByDisplay = enabled
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.groupSpacesByDisplay)
        scheduleSettingsBackup()
    }

    func setOpenNotchOnHover(_ enabled: Bool) {
        openNotchOnHover = enabled
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.openNotchOnHover)
        scheduleSettingsBackup()
    }

    func setMinimumHoverDuration(_ duration: Double) {
        let resolvedDuration = min(1, max(0, duration))
        minimumHoverDuration = resolvedDuration
        UserDefaults.standard.set(resolvedDuration, forKey: DefaultsKey.minimumHoverDuration)
        scheduleSettingsBackup()
    }

    func setEnableHaptics(_ enabled: Bool) {
        enableHaptics = enabled
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.enableHaptics)
        scheduleSettingsBackup()
    }

    func scheduleSettingsBackup() {
        settingsBackupTask?.cancel()
        settingsBackupTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            SettingsBackupManager.exportBackup()
        }
    }

    func openSettings() {
        refreshDiagnostics()
        loadConfigFiles()

        if let openSettingsHandler {
            openSettingsHandler()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func setOpenSettingsHandler(_ handler: @escaping () -> Void) {
        openSettingsHandler = handler
    }

    func notchSurfaceDidChangeOpenState(displayUUID: String, isOpen: Bool) {
        if isOpen {
            openNotchDisplayUUIDs.insert(displayUUID)
        } else {
            openNotchDisplayUUIDs.remove(displayUUID)
        }

        if isOpen {
            reconcileDisplayedState(afterDelays: [0, 70, 180])
            refreshSnapshot()
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        let eligibleForRegistration = installationState == .installed
        loginItemState = loginItemManager.setEnabled(enabled, isEligibleForRegistration: eligibleForRegistration)

        if case let .unavailable(message) = loginItemState {
            statusMessage = message
        }
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

    var shouldShowStatusIndicators: Bool {
        indicatorPresentationState.showsStatusItem
    }

    var shouldShowStatusItem: Bool {
        indicatorPresentationState.showsStatusItem
    }

    var shouldShowNotchSurface: Bool {
        indicatorPresentationState.showsNotchSurface
    }

    var shouldShowIconOnlyInStatusItem: Bool {
        indicatorPresentationState.statusItemShowsIconOnly
    }

    var shouldShowTextInStatusItem: Bool {
        indicatorPresentationState.statusItemShowsText
    }

    var shouldShowImageInStatusItem: Bool {
        indicatorPresentationState.statusItemShowsImage
    }

    var indicatorPresentationState: IndicatorPresentationState {
        switch indicatorSurfaceMode {
        case .topBar:
            return IndicatorPresentationState(
                showsStatusItem: true,
                showsNotchSurface: false,
                statusItemShowsIconOnly: menuBarLabelMode == .iconOnly,
                statusItemShowsText: menuBarLabelMode != .iconOnly,
                statusItemShowsImage: menuBarLabelMode != .numberOnly
            )
        case .notch:
            return IndicatorPresentationState(
                showsStatusItem: false,
                showsNotchSurface: true,
                statusItemShowsIconOnly: false,
                statusItemShowsText: false,
                statusItemShowsImage: false
            )
        case .both:
            return IndicatorPresentationState(
                showsStatusItem: true,
                showsNotchSurface: true,
                statusItemShowsIconOnly: menuBarLabelMode == .iconOnly,
                statusItemShowsText: menuBarLabelMode != .iconOnly,
                statusItemShowsImage: menuBarLabelMode != .numberOnly
            )
        }
    }

    var activeDisplay: DisplaySummary? {
        if let activeDisplayUUID,
           let matchedDisplay = snapshot?.displays.first(where: { $0.uuid == activeDisplayUUID }) {
            return matchedDisplay
        }

        return snapshot?.displays.first(where: \.hasFocus)
    }

    var activeDisplayLabel: String {
        if let activeDisplay {
            return "Display \(activeDisplay.index)"
        }

        return "Display"
    }

    var activeDisplaySpaces: [Int] {
        activeDisplay?.spaces ?? []
    }

    var activeStackItems: [ActiveStackItemSummary] {
        snapshot?.activeStackItems ?? []
    }

    var activeSpaceTypeLabel: String? {
        if let activeStackSummary {
            return activeStackSummary.badgeLabel
        }

        switch activeSpaceType?.lowercased() {
        case "bsp":
            return "BSP"
        case "float":
            return "FLOAT"
        case "stack":
            return "STACK"
        default:
            return nil
        }
    }

    var menuSpaceSections: [(title: String?, spaces: [SpaceSummary])] {
        let spaces = snapshot?.spaces ?? []
        guard groupSpacesByDisplay else {
            return [(title: nil, spaces: spaces.sorted { $0.index < $1.index })]
        }

        let groups = Dictionary(grouping: spaces, by: \.display)
        let sortedDisplays = groups.keys.sorted()
        var sections: [(title: String?, spaces: [SpaceSummary])] = []
        sections.reserveCapacity(sortedDisplays.count)

        for display in sortedDisplays {
            let sortedSpaces = (groups[display] ?? []).sorted { $0.index < $1.index }
            sections.append((title: "Display \(display)", spaces: sortedSpaces))
        }

        return sections
    }

    var spaces: [SpaceSummary] {
        snapshot?.spaces ?? []
    }

    var diagnosticDisplays: [DisplayDiagnosticSummary] {
        diagnosticsSnapshot?.displays ?? []
    }

    var runtimeStatePath: String {
        integrationManager.runtimeStateURL.path
    }

    var launchAtLoginEnabled: Bool {
        loginItemState == .enabled
    }

    var displayNotchStates: [DisplayNotchState] {
        let displays = snapshot?.displays ?? []
        return displays.compactMap { display in
            displayNotchState(for: display.uuid)
        }
        .sorted { $0.displayIndex < $1.displayIndex }
    }

    func displayNotchState(for displayUUID: String?) -> DisplayNotchState? {
        guard let displayUUID,
              let display = snapshot?.displays.first(where: { $0.uuid == displayUUID }) else {
            return nil
        }

        let visibleSpace = visibleSpace(for: display)
        let stackSummary = stackSummary(for: visibleSpace)

        return DisplayNotchState(
            id: displayUUID,
            displayUUID: displayUUID,
            displayIndex: display.index,
            isActiveDisplay: activeDisplayUUID == displayUUID || display.hasFocus,
            spaceIndexes: display.spaces,
            visibleSpaceIndex: visibleSpace?.index,
            visibleSpaceType: visibleSpace?.type,
            visibleSpaceApps: visibleSpace?.apps ?? [],
            stackSummary: stackSummary,
            stackItems: stackItems(for: visibleSpace, using: stackSummary),
            isNativeFullscreen: visibleSpace?.isNativeFullscreen ?? false
        )
    }

    func menuSpaceTitle(for space: SpaceSummary) -> String {
        if showAppNamesInMenu {
            return "Space \(space.index) · \(space.appSummary(maxApps: maxAppsShownPerSpace))"
        }

        return "Space \(space.index)"
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

    func refreshDiagnostics() {
        refreshDiagnostics(after: 0)
    }

    func recheckAllSpaces() {
        guard installationState == .installed else {
            diagnosticsStatusMessage = "Install the app in Applications first"
            return
        }

        let client = self.client
        let runtimeStateURL = integrationManager.runtimeStateURL

        Task { [weak self] in
            guard let self else { return }

            do {
                let rebuilt = try await Task.detached(priority: .userInitiated) { () throws -> (YabaiSnapshot, YabaiLiveState) in
                    let snapshot = try client.fetchSnapshot()
                    let rebuiltState = YabaiLiveStateMaintenance.rebuildAll(from: snapshot)
                    try YabaiLiveStateStore.save(rebuiltState, to: runtimeStateURL)
                    return (snapshot, rebuiltState)
                }.value

                applySnapshot(rebuilt.0)
                applyLiveState(rebuilt.1)
                diagnosticsStatusMessage = nil
                statusMessage = "Rechecked all spaces"
                refreshDiagnostics(after: 40)
            } catch {
                let message = error.localizedDescription
                diagnosticsStatusMessage = message
                statusMessage = message
            }
        }
    }

    func recheckSpace(_ index: Int) {
        guard installationState == .installed else {
            diagnosticsStatusMessage = "Install the app in Applications first"
            return
        }

        let client = self.client
        let runtimeStateURL = integrationManager.runtimeStateURL
        let fallbackState = liveState

        Task { [weak self] in
            guard let self else { return }

            do {
                let rebuiltState = try await Task.detached(priority: .userInitiated) {
                    let baseState = try YabaiLiveStateStore.load(from: runtimeStateURL) ?? fallbackState ?? YabaiLiveState()
                    let nextState = try YabaiLiveStateMaintenance.rebuildSpace(index, in: baseState, using: client)
                    try YabaiLiveStateStore.save(nextState, to: runtimeStateURL)
                    return nextState
                }.value

                applyLiveState(rebuiltState)
                diagnosticsStatusMessage = nil
                statusMessage = "Rechecked space \(index)"
                reconcileDisplayedState(afterDelays: [0, 60, 160])
                refreshSnapshot(after: 40)
                refreshDiagnostics(after: 40)
            } catch {
                let message = error.localizedDescription
                diagnosticsStatusMessage = message
                statusMessage = message
            }
        }
    }

    func purgeLocalTrackedState(for spaceIndex: Int) {
        guard installationState == .installed else {
            diagnosticsStatusMessage = "Install the app in Applications first"
            return
        }

        let runtimeStateURL = integrationManager.runtimeStateURL
        let fallbackState = liveState

        Task { [weak self] in
            guard let self else { return }

            do {
                let purgedState = try await Task.detached(priority: .userInitiated) {
                    let baseState = try YabaiLiveStateStore.load(from: runtimeStateURL) ?? fallbackState ?? YabaiLiveState()
                    let nextState = YabaiLiveStateMaintenance.purgeSpace(spaceIndex, from: baseState)
                    try YabaiLiveStateStore.save(nextState, to: runtimeStateURL)
                    return nextState
                }.value

                applyLiveState(purgedState)
                diagnosticsStatusMessage = nil
                statusMessage = "Purged local state for space \(spaceIndex)"
                reconcileDisplayedState(afterDelays: [0, 60, 160])
                refreshSnapshot(after: 40)
                refreshDiagnostics(after: 40)
            } catch {
                let message = error.localizedDescription
                diagnosticsStatusMessage = message
                statusMessage = message
            }
        }
    }

    func diagnosticsComparison(for space: SpaceDiagnosticSummary) -> SpaceDiagnosticsComparison {
        let trackedState = liveState?.spaces[space.index]
        let liveSummary = space.liveStackSummary
        let liveCount = space.countedStackWindowCount

        let status: SpaceDiagnosticsStatus

        if !space.isStack {
            status = .notStack
        } else if trackedState == nil {
            status = liveCount >= 2 ? .liveOnly : .notTracked
        } else if liveCount < 2 {
            status = .staleLocal
        } else if trackedState?.total != liveCount {
            status = .countMismatch
        } else if liveSummary == nil {
            status = .unresolvedFocus
        } else if trackedState?.focusedWindowID != liveSummary?.focusedWindowID
            || trackedState?.currentIndex != liveSummary?.currentIndex {
            status = .focusMismatch
        } else {
            status = .synced
        }

        return SpaceDiagnosticsComparison(
            trackedState: trackedState,
            liveSummary: liveSummary,
            status: status
        )
    }

    private func visibleSpace(for display: DisplaySummary) -> SpaceSummary? {
        let spaces = snapshot?.spaces.filter { $0.display == display.index } ?? []
        if let focusedVisibleSpace = spaces.first(where: { $0.isVisible && $0.hasFocus }) {
            return focusedVisibleSpace
        }

        if let visibleSpace = spaces.first(where: \.isVisible) {
            return visibleSpace
        }

        if let firstDisplaySpaceIndex = display.spaces.first {
            return spaces.first(where: { $0.index == firstDisplaySpaceIndex })
        }

        return spaces.first
    }

    private func stackSummary(for space: SpaceSummary?) -> ActiveStackSummary? {
        guard let space, space.isStack else {
            return nil
        }

        if let trackedSummary = liveState?.spaces[space.index]?.activeStackSummary {
            return trackedSummary
        }

        if let stackSummary = space.stackSummary {
            return stackSummary
        }

        guard space.stackItems.count >= 2 else {
            return nil
        }

        let focusedItem = space.stackItems.first(where: \.isFocused) ?? space.stackItems.first
        guard let focusedItem else {
            return nil
        }

        return ActiveStackSummary(
            spaceIndex: space.index,
            currentIndex: focusedItem.position,
            total: space.stackItems.count,
            focusedWindowID: focusedItem.id,
            focusedAppName: focusedItem.app
        )
    }

    private func stackItems(for space: SpaceSummary?, using summary: ActiveStackSummary?) -> [ActiveStackItemSummary] {
        guard let space else {
            return []
        }

        guard let summary else {
            return space.stackItems
        }

        return space.stackItems.map { item in
            ActiveStackItemSummary(
                id: item.id,
                position: item.position,
                app: item.app,
                title: item.title,
                isFocused: item.id == summary.focusedWindowID
            )
        }
    }

    private func refreshInstallationAndLoginItemState() {
        installationState = installationManager.state
        let eligibleForRegistration = installationState == .installed
        loginItemState = loginItemManager.currentState(isEligibleForRegistration: eligibleForRegistration)

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
            activeDisplayUUID = snapshot?.activeDisplayUUID
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
                refreshSnapshot(after: liveState == nil ? 220 : (openNotchDisplayUUIDs.isEmpty ? 120 : 60))
            }
        }
    }

    private func applyLiveState(_ state: YabaiLiveState?) {
        liveState = state

        guard let state else {
            activeDisplayUUID = snapshot?.activeDisplayUUID
            reconcileDisplayedState(afterDelays: [0, 80, 220])
            return
        }

        activeDisplayUUID = state.activeDisplayUUID ?? snapshot?.activeDisplayUUID

        if snapshot != nil || state.activeSpaceIndex != nil {
            isUnavailable = false
            statusMessage = nil
        }

        activeSpaceIndex = state.activeSpaceIndex
        if let summary = state.activeStackSummary {
            activeStackSummary = summary
        }

        reconcileDisplayedState(
            afterDelays: state.activeStackSummary == nil ? [0, 80, 220] : [0, 60, 160]
        )

        refreshSnapshot(after: state.activeStackSummary == nil ? 80 : 30)
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
                        let activeDisplayUUID = try client.fetchActiveDisplayUUID()
                        return ReconciledDisplayState(
                            activeSpaceIndex: activeSpaceIndex,
                            activeStackSummary: activeStackSummary,
                            activeDisplayUUID: activeDisplayUUID
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
        activeDisplayUUID = liveState?.activeDisplayUUID ?? reconciledState.activeDisplayUUID ?? snapshot?.activeDisplayUUID

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

                applySnapshot(fetchedSnapshot)
                statusMessage = nil
                isUnavailable = false
            } catch {
                statusMessage = error.localizedDescription
                isUnavailable = snapshot == nil && liveState == nil
            }
        }
    }

    private func applySnapshot(_ fetchedSnapshot: YabaiSnapshot) {
        snapshot = fetchedSnapshot
        activeSpaceType = fetchedSnapshot.activeSpaceType
        activeSpaceIsNativeFullscreen = fetchedSnapshot.activeSpaceIsNativeFullscreen
        activeDisplayUUID = liveState?.activeDisplayUUID ?? fetchedSnapshot.activeDisplayUUID
    }

    private func refreshDiagnostics(after delayMilliseconds: Int = 0) {
        diagnosticsRefreshTask?.cancel()
        diagnosticsRefreshTask = Task { [weak self] in
            guard let self else { return }

            if delayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            }

            guard !Task.isCancelled else { return }

            do {
                let fetchedDiagnostics = try await Task.detached(priority: .userInitiated) { [client] in
                    try client.fetchDiagnosticsSnapshot()
                }.value

                diagnosticsSnapshot = fetchedDiagnostics
                diagnosticsUpdatedAt = Date()
                diagnosticsStatusMessage = nil
            } catch {
                diagnosticsStatusMessage = error.localizedDescription
            }
        }
    }
}
