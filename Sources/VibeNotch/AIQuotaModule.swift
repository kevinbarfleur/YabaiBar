import AppKit
import Combine
import VibeNotchCore
import SwiftUI

@MainActor
final class AIQuotaModule: ObservableObject, VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.aiquota")
    let displayName = "AI Quota"
    let icon = "gauge.with.dots.needle.33percent"

    var objectDidChange: (() -> Void)?

    @Published private(set) var claudeUsage: ClaudeSubscriptionUsage?
    @Published private(set) var codexUsage: CodexSubscriptionUsage?
    @Published private(set) var hasClaudeToken = false
    @Published private(set) var hasCodexToken = false

    @Published var monitorClaude: Bool {
        didSet { UserDefaults.standard.set(monitorClaude, forKey: DefaultsKey.monitorClaude) }
    }
    @Published var monitorCodex: Bool {
        didSet { UserDefaults.standard.set(monitorCodex, forKey: DefaultsKey.monitorCodex) }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: DefaultsKey.refreshInterval)
            restartTimer()
        }
    }

    private var timerCancellable: AnyCancellable?
    private var isActive = false

    private enum DefaultsKey {
        static let monitorClaude = "AIQuota.monitorClaude"
        static let monitorCodex = "AIQuota.monitorCodex"
        static let refreshInterval = "AIQuota.refreshInterval"
    }

    init() {
        let defaults = UserDefaults.standard
        monitorClaude = defaults.object(forKey: DefaultsKey.monitorClaude) as? Bool ?? true
        monitorCodex = defaults.object(forKey: DefaultsKey.monitorCodex) as? Bool ?? true
        refreshInterval = defaults.object(forKey: DefaultsKey.refreshInterval) as? Double ?? 60
        hasClaudeToken = AIQuotaClient.readClaudeOAuthToken() != nil
        hasCodexToken = AIQuotaClient.readCodexOAuthToken() != nil
    }

    // MARK: - Lifecycle

    func activate() {
        isActive = true
        restartTimer()
        Task { await fetchAll() }
    }

    func deactivate() {
        isActive = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func refresh() {
        Task { await fetchAll() }
    }

    // MARK: - Data Fetching

    private func fetchAll() async {
        hasClaudeToken = AIQuotaClient.readClaudeOAuthToken() != nil
        hasCodexToken = AIQuotaClient.readCodexOAuthToken() != nil

        if monitorClaude, let token = AIQuotaClient.readClaudeOAuthToken() {
            claudeUsage = await AIQuotaClient.fetchClaudeSubscriptionUsage(oauthToken: token)
        } else {
            claudeUsage = nil
        }

        if monitorCodex, let token = AIQuotaClient.readCodexOAuthToken() {
            codexUsage = await AIQuotaClient.fetchCodexSubscriptionUsage(oauthToken: token)
        } else {
            codexUsage = nil
        }

        objectDidChange?()
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

    var overallHealth: Health {
        let healths: [Health] = [claudeUsage?.overallHealth, codexUsage?.overallHealth].compactMap { $0 }
        if healths.contains(.critical) { return .critical }
        if healths.contains(.warning) { return .warning }
        if healths.contains(.ok) { return .ok }
        return .unknown
    }

    var statusLabel: String {
        if let claude = claudeUsage {
            let pct = Int(claude.sessionUtilization * 100)
            return "\(pct)%"
        }
        return "--"
    }

    var hasAnyData: Bool {
        claudeUsage != nil || codexUsage != nil
    }

    // MARK: - Module Content

    func closedTrailingView(for displayUUID: String) -> NotchSlotContent? {
        guard hasAnyData else { return nil }

        return NotchSlotContent(
            view: AnyView(AIQuotaClosedIndicator(health: overallHealth)),
            width: 6
        )
    }

    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        let widgetID = "aiquota-detail"
        let collapsed = isWidgetCollapsed(widgetID)
        let estimatedHeight: CGFloat = collapsed ? 40 : (40 + (claudeUsage != nil ? 70 : 0) + (codexUsage != nil ? 70 : 0))

        return [
            NotchExpandedWidget(
                id: widgetID,
                moduleID: identifier,
                estimatedHeight: estimatedHeight,
                content: AnyView(
                    AIQuotaExpandedContent(
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

    func statusBarContent() -> StatusBarContent? {
        let image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: nil)
        image?.isTemplate = true

        return StatusBarContent(
            icon: image,
            label: statusLabel,
            tooltip: "AI Quota: \(statusLabel)",
            length: 48
        )
    }

    func menuSections() -> [ModuleMenuSection] {
        var items: [NSMenuItem] = []

        if let claude = claudeUsage {
            if let error = claude.error {
                let item = NSMenuItem(title: "Claude: \(error)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                items.append(item)
            } else {
                let sessionPct = Int(claude.sessionUtilization * 100)
                let weeklyPct = Int(claude.weeklyUtilization * 100)
                let sessionItem = NSMenuItem(title: "Session: \(sessionPct)% used", action: nil, keyEquivalent: "")
                sessionItem.isEnabled = false
                items.append(sessionItem)
                let weeklyItem = NSMenuItem(title: "Weekly: \(weeklyPct)% used", action: nil, keyEquivalent: "")
                weeklyItem.isEnabled = false
                items.append(weeklyItem)
            }
        } else if monitorClaude {
            let item = NSMenuItem(title: hasClaudeToken ? "Fetching..." : "No Claude credentials", action: nil, keyEquivalent: "")
            item.isEnabled = false
            items.append(item)
        }

        if let codex = codexUsage {
            if let error = codex.error {
                let item = NSMenuItem(title: "Codex: \(error)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                items.append(item)
            } else {
                let sessionItem = NSMenuItem(title: "Codex Session: \(Int(codex.sessionUsedPercent))%", action: nil, keyEquivalent: "")
                sessionItem.isEnabled = false
                items.append(sessionItem)
                let weeklyItem = NSMenuItem(title: "Codex Weekly: \(Int(codex.weeklyUsedPercent))%\(codex.limitReached ? " (limit reached)" : "")", action: nil, keyEquivalent: "")
                weeklyItem.isEnabled = false
                items.append(weeklyItem)
            }
        } else if monitorCodex {
            let item = NSMenuItem(title: hasCodexToken ? "Fetching..." : "No Codex credentials", action: nil, keyEquivalent: "")
            item.isEnabled = false
            items.append(item)
        }

        return items.isEmpty ? [] : [ModuleMenuSection(title: "AI Quota", items: items)]
    }

    func makeSettingsView() -> AnyView? {
        AnyView(AIQuotaSettingsView(module: self))
    }
}
