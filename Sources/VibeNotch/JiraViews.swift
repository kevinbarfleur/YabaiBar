import AppKit
import VibeNotchCore
import SwiftUI

// MARK: - Expanded Widget Content

struct JiraExpandedContent: View {
    @ObservedObject var module: JiraModule
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, isCollapsed ? 0 : 8)

            if !isCollapsed {
                content
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, isCollapsed ? 6 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCollapsed)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onToggleCollapse) {
                HStack(spacing: 8) {
                    Text("Jira")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.22))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))

                    if !module.issues.isEmpty {
                        Text("\(module.issues.count)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if module.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
            }

            NotchActionButton(systemImage: "arrow.clockwise", action: onRefresh)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch module.connectionState {
        case .disconnected:
            emptyState("Configure Jira in Settings")
        case .connecting:
            emptyState("Connecting...")
        case .error:
            if let error = module.lastError {
                errorState(error)
            } else {
                emptyState("Connection error")
            }
        case .connected:
            if module.issues.isEmpty && !module.isLoading {
                VStack(spacing: 4) {
                    emptyState("No issues found")
                    if let jql = module.lastJQL {
                        Text(jql)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.white.opacity(0.18))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity)
                    }
                    if let error = module.lastError {
                        Text(error)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.red.opacity(0.5))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else if !module.issues.isEmpty {
                issuesList
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func errorState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.red.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private var issuesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(module.issuesByStatus, id: \.status) { group in
                statusGroup(status: group.status, issues: group.issues)
            }
        }
    }

    private func statusGroup(status: String, issues: [JiraIssue]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(status) (\(issues.count))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
                .padding(.bottom, 2)

            ForEach(issues) { issue in
                issueRow(issue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.04))
        }
    }

    private func issueRow(_ issue: JiraIssue) -> some View {
        Button {
            if let url = URL(string: issue.browseUrl) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                priorityDot(issue.priorityName)

                Text(issue.key)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                if let type = issue.issueType {
                    Text(type)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white.opacity(0.06))
                        }
                }

                Text(issue.summary)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private func priorityDot(_ priorityName: String?) -> some View {
        Circle()
            .fill(priorityColor(priorityName))
            .frame(width: 5, height: 5)
    }

    private func priorityColor(_ name: String?) -> Color {
        switch name?.lowercased() {
        case "highest", "high": return .red.opacity(0.8)
        case "medium": return .orange.opacity(0.8)
        case "low", "lowest": return .blue.opacity(0.6)
        default: return .white.opacity(0.22)
        }
    }
}

// MARK: - Settings View

struct JiraSettingsView: View {
    @ObservedObject var module: JiraModule

    @State private var siteUrl = ""
    @State private var email = ""
    @State private var apiToken = ""

    var body: some View {
        connectionSection

        if module.connectionState == .connected {
            statusFilterSection
            typeFilterSection
            projectFilterSection
        }

        refreshSection
    }

    // MARK: Connection

    private var connectionSection: some View {
        Section {
            switch module.connectionState {
            case .disconnected, .error:
                TextField("Site URL", text: $siteUrl, prompt: Text("https://company.atlassian.net"))
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $email, prompt: Text("you@company.com"))
                    .textFieldStyle(.roundedBorder)

                SecureField("API Token", text: $apiToken, prompt: Text("Paste your token"))
                    .textFieldStyle(.roundedBorder)

                if let error = module.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Connect") {
                    module.connect(siteUrl: siteUrl, email: email, apiToken: apiToken)
                }
                .disabled(siteUrl.isEmpty || email.isEmpty || apiToken.isEmpty)

            case .connecting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                        .foregroundStyle(.secondary)
                }

            case .connected:
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Connected")
                            .foregroundStyle(.green)
                    }
                }

                if let name = module.connectedUserName {
                    LabeledContent("Account") {
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Disconnect", role: .destructive) {
                    module.disconnect()
                    siteUrl = ""
                    email = ""
                    apiToken = ""
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            if module.connectionState != .connected {
                Text("Get your API token at id.atlassian.com → Security → API Tokens")
            }
        }
        .onAppear {
            if let creds = JiraClient.readCredentials() {
                siteUrl = creds.siteUrl
                email = creds.email
            }
            if module.connectionState == .connected && module.availableStatuses.isEmpty {
                Task { await module.fetchMetadata() }
            }
        }
    }

    // MARK: Status Filter

    private var statusFilterSection: some View {
        Section {
            if module.availableStatuses.isEmpty {
                Text("Fetching statuses...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(module.availableStatuses) { status in
                    Toggle(status.name, isOn: Binding(
                        get: { module.selectedStatuses.contains(status.name) },
                        set: { enabled in
                            if enabled {
                                module.selectedStatuses.insert(status.name)
                            } else {
                                module.selectedStatuses.remove(status.name)
                            }
                        }
                    ))
                }
            }
        } header: {
            Text("Status Filter")
        } footer: {
            Text(module.selectedStatuses.isEmpty
                 ? "No filter — showing all statuses."
                 : "Showing \(module.selectedStatuses.count) status(es).")
        }
    }

    // MARK: Type Filter

    private var typeFilterSection: some View {
        Section {
            if module.availableIssueTypes.isEmpty {
                Text("Fetching types...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(module.availableIssueTypes) { type in
                    Toggle(type.name, isOn: Binding(
                        get: { module.selectedTypes.contains(type.name) },
                        set: { enabled in
                            if enabled {
                                module.selectedTypes.insert(type.name)
                            } else {
                                module.selectedTypes.remove(type.name)
                            }
                        }
                    ))
                }
            }
        } header: {
            Text("Type Filter")
        } footer: {
            Text(module.selectedTypes.isEmpty
                 ? "No filter — showing all types."
                 : "Showing \(module.selectedTypes.count) type(s).")
        }
    }

    // MARK: Project Filter

    private var projectFilterSection: some View {
        Section {
            if module.availableProjects.isEmpty {
                Text("Fetching projects...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(module.availableProjects) { project in
                    Toggle("\(project.key) — \(project.name)", isOn: Binding(
                        get: { module.selectedProjects.contains(project.key) },
                        set: { enabled in
                            if enabled {
                                module.selectedProjects.insert(project.key)
                            } else {
                                module.selectedProjects.remove(project.key)
                            }
                        }
                    ))
                }
            }
        } header: {
            Text("Project Filter")
        } footer: {
            Text(module.selectedProjects.isEmpty
                 ? "No filter — showing all projects."
                 : "Showing \(module.selectedProjects.count) project(s).")
        }
    }

    // MARK: Refresh

    private var refreshSection: some View {
        Section {
            Picker("Interval", selection: Binding(
                get: { module.refreshInterval },
                set: { module.refreshInterval = $0 }
            )) {
                Text("1 minute").tag(60.0 as TimeInterval)
                Text("2 minutes").tag(120.0 as TimeInterval)
                Text("5 minutes").tag(300.0 as TimeInterval)
                Text("10 minutes").tag(600.0 as TimeInterval)
            }

            Button("Refresh Now") { module.refresh() }
        } header: {
            Text("Refresh")
        }
    }
}
