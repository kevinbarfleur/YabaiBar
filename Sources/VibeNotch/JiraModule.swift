import AppKit
import Combine
import VibeNotchCore
import SwiftUI

@MainActor
final class JiraModule: ObservableObject, VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.jira")
    let displayName = "Jira"
    let icon = "list.bullet.rectangle"

    var objectDidChange: (() -> Void)?

    // MARK: - State

    @Published private(set) var issues: [JiraIssue] = []
    @Published private(set) var availableStatuses: [JiraStatus] = []
    @Published private(set) var availableProjects: [JiraProject] = []
    @Published private(set) var availableIssueTypes: [JiraIssueType] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false
    @Published private(set) var connectedUserName: String?
    @Published private(set) var lastJQL: String?

    @Published var selectedStatuses: Set<String> {
        didSet {
            let array = Array(selectedStatuses)
            UserDefaults.standard.set(array, forKey: DefaultsKey.selectedStatuses)
            refreshAfterFilterChange()
        }
    }

    @Published var selectedProjects: Set<String> {
        didSet {
            let array = Array(selectedProjects)
            UserDefaults.standard.set(array, forKey: DefaultsKey.selectedProjects)
            refreshAfterFilterChange()
        }
    }

    @Published var selectedTypes: Set<String> {
        didSet {
            let array = Array(selectedTypes)
            UserDefaults.standard.set(array, forKey: DefaultsKey.selectedTypes)
            refreshAfterFilterChange()
        }
    }

    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: DefaultsKey.refreshInterval)
            restartTimer()
        }
    }

    enum ConnectionState {
        case disconnected, connecting, connected, error
    }

    private var timerCancellable: AnyCancellable?
    private var isActive = false

    private enum DefaultsKey {
        static let selectedStatuses = "Jira.selectedStatuses"
        static let selectedProjects = "Jira.selectedProjects"
        static let selectedTypes = "Jira.selectedTypes"
        static let refreshInterval = "Jira.refreshInterval"
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        let storedStatuses = defaults.stringArray(forKey: DefaultsKey.selectedStatuses) ?? []
        selectedStatuses = Set(storedStatuses)
        let storedProjects = defaults.stringArray(forKey: DefaultsKey.selectedProjects) ?? []
        selectedProjects = Set(storedProjects)
        let storedTypes = defaults.stringArray(forKey: DefaultsKey.selectedTypes) ?? []
        selectedTypes = Set(storedTypes)
        refreshInterval = defaults.object(forKey: DefaultsKey.refreshInterval) as? Double ?? 120

        if JiraClient.readCredentials() != nil {
            connectionState = .connected
        }
    }

    // MARK: - Lifecycle

    func activate() {
        isActive = true
        restartTimer()
        Task {
            await fetchAll()
            if connectionState == .connected {
                await fetchMetadata()
            }
        }
    }

    func deactivate() {
        isActive = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func refresh() {
        Task { await fetchAll() }
    }

    // MARK: - Connection

    func connect(siteUrl: String, email: String, apiToken: String) {
        let trimmedUrl = siteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUrl.isEmpty, !trimmedEmail.isEmpty, !trimmedToken.isEmpty else {
            lastError = "All fields are required"
            connectionState = .error
            objectDidChange?()
            return
        }

        let creds = JiraCredentials(siteUrl: trimmedUrl, email: trimmedEmail, apiToken: trimmedToken)
        connectionState = .connecting
        lastError = nil
        objectDidChange?()

        Task {
            let result = await JiraClient.validateConnection(creds)

            if let error = result.error {
                connectionState = .error
                lastError = error
                JiraClient.deleteCredentials()
            } else {
                _ = JiraClient.saveCredentials(creds)
                connectionState = .connected
                connectedUserName = result.displayName
                lastError = nil

                await fetchMetadata()
                await fetchAll()
            }

            objectDidChange?()
        }
    }

    func disconnect() {
        JiraClient.deleteCredentials()
        connectionState = .disconnected
        connectedUserName = nil
        issues = []
        availableStatuses = []
        availableProjects = []
        availableIssueTypes = []
        lastError = nil
        objectDidChange?()
    }

    // MARK: - Data Fetching

    private func fetchAll() async {
        guard let creds = JiraClient.readCredentials() else {
            if connectionState != .disconnected {
                connectionState = .disconnected
                objectDidChange?()
            }
            return
        }

        isLoading = true

        let jql = JiraClient.buildJQL(statusFilter: selectedStatuses, projectFilter: selectedProjects, typeFilter: selectedTypes)
        lastJQL = jql
        let result = await JiraClient.fetchIssues(creds, jql: jql)

        if let error = result.error {
            lastError = error
            if error == "Invalid credentials" {
                connectionState = .error
            }
        } else {
            issues = result.issues
            lastError = nil
            connectionState = .connected
        }

        isLoading = false
        objectDidChange?()
    }

    func fetchMetadata() async {
        guard let creds = JiraClient.readCredentials() else { return }

        async let statusResult = JiraClient.fetchStatuses(creds)
        async let projectResult = JiraClient.fetchProjects(creds)
        async let typeResult = JiraClient.fetchIssueTypes(creds)

        let (statuses, projects, types) = await (statusResult, projectResult, typeResult)

        if statuses.error == nil {
            availableStatuses = statuses.statuses
        }
        if types.error == nil {
            availableIssueTypes = types.types
        }
        if projects.error == nil {
            availableProjects = projects.projects
        }

        objectDidChange?()
    }

    private func refreshAfterFilterChange() {
        guard connectionState == .connected else { return }
        Task { await fetchAll() }
    }

    private func restartTimer() {
        timerCancellable?.cancel()
        guard isActive else { return }

        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.fetchAll() }
            }
    }

    // MARK: - Helpers

    var issuesByStatus: [(status: String, issues: [JiraIssue])] {
        let grouped = Dictionary(grouping: issues, by: \.status)
        return grouped.keys.sorted().map { key in
            (status: key, issues: grouped[key] ?? [])
        }
    }

    // MARK: - Module Content

    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        let headerHeight: CGFloat = 32
        let padding: CGFloat = 23

        var contentHeight: CGFloat = 0
        if connectionState == .disconnected || (issues.isEmpty && lastError == nil) {
            contentHeight = 30
        } else if lastError != nil {
            contentHeight = 30
        } else {
            for group in issuesByStatus {
                let headerLine: CGFloat = 18
                let rows = CGFloat(min(group.issues.count, 10)) * 20
                let groupPadding: CGFloat = 12
                let groupSpacing: CGFloat = 10
                contentHeight += headerLine + rows + groupPadding + groupSpacing
            }
        }

        let widgetID = "jira-issues"
        let collapsed = isWidgetCollapsed(widgetID)
        let estimatedHeight = collapsed ? 40 : (headerHeight + contentHeight + padding)

        return [
            NotchExpandedWidget(
                id: widgetID,
                moduleID: identifier,
                estimatedHeight: estimatedHeight,
                content: AnyView(
                    JiraExpandedContent(
                        module: self,
                        isCollapsed: collapsed,
                        onToggleCollapse: { [weak self] in
                            setWidgetCollapsed(widgetID, !collapsed)
                            self?.objectDidChange?()
                        },
                        onRefresh: { [weak self] in self?.refresh() }
                    )
                )
            ),
        ]
    }

    func makeSettingsView() -> AnyView? {
        AnyView(JiraSettingsView(module: self))
    }
}
