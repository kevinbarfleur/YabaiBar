import OpenNotchCore
import SwiftUI

// MARK: - Closed Notch Indicator

struct AIQuotaClosedIndicator: View {
    let health: Health

    var body: some View {
        Circle()
            .fill(healthColor(health))
            .frame(width: 6, height: 6)
    }

    private func healthColor(_ h: Health) -> Color {
        switch h {
        case .ok: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Expanded Widget Content

struct AIQuotaExpandedContent: View {
    @ObservedObject var module: AIQuotaModule
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, isCollapsed ? 0 : 8)

            if !isCollapsed {
                if !module.hasAnyData {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if let claude = module.claudeUsage {
                            subscriptionSection("Claude Code", usage: claude)
                        }
                        if let codex = module.codexUsage {
                            codexSection(codex)
                        }
                    }
                }
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
                    Text("AI Usage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.22))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            NotchActionButton(systemImage: "arrow.clockwise", action: onRefresh)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            if module.hasClaudeToken || module.hasCodexToken {
                Text("Fetching usage...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
            } else {
                Text("No providers configured")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
                Text("Credentials auto-detected from Claude CLI and Codex CLI.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }

    // MARK: Subscription Section (reusable)

    private func subscriptionSection(_ title: String, usage: ClaudeSubscriptionUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(healthColor(usage.overallHealth))
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                if let error = usage.error {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            if usage.error == nil {
                usageRow(label: "Session", utilization: usage.sessionUtilization, resetTime: usage.sessionResetTime)
                usageRow(label: "Weekly", utilization: usage.weeklyUtilization, resetTime: usage.weeklyResetTime)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.04))
        }
    }

    // MARK: Codex Section

    private func codexSection(_ usage: CodexSubscriptionUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(healthColor(usage.overallHealth))
                    .frame(width: 6, height: 6)
                Text("Codex")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                if usage.limitReached {
                    Text("Limit reached")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if let error = usage.error {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            if usage.error == nil {
                usageRow(label: "Session", utilization: usage.sessionUsedPercent / 100, resetTime: usage.sessionResetTime)
                usageRow(label: "Weekly", utilization: usage.weeklyUsedPercent / 100, resetTime: usage.weeklyResetTime)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.04))
        }
    }

    // MARK: Shared UI

    private func usageRow(label: String, utilization: Double, resetTime: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.28))
                    .frame(width: 48, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(.white.opacity(0.08))

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(barColor(utilization))
                            .frame(width: geo.size.width * min(1, utilization))
                    }
                }
                .frame(height: 4)

                Text("\(Int(utilization * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)
            }

            if let reset = resetTime {
                Text("Reset \(resetLabel(reset))")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.22))
                    .padding(.leading, 48)
            }
        }
    }

    private func barColor(_ ratio: Double) -> Color {
        if ratio < 0.5 { return .green.opacity(0.6) }
        if ratio < 0.9 { return .yellow.opacity(0.6) }
        return .red.opacity(0.6)
    }

    private func healthColor(_ h: Health) -> Color {
        switch h {
        case .ok: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    private func resetLabel(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 24 {
            let days = hours / 24
            return "in \(days)d \(hours % 24)h"
        }
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
    }

    private func compactNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Settings View

struct AIQuotaSettingsView: View {
    @ObservedObject var module: AIQuotaModule

    var body: some View {
        Section {
            Toggle("Monitor Claude Code", isOn: Binding(
                get: { module.monitorClaude },
                set: { module.monitorClaude = $0 }
            ))

            if module.hasClaudeToken {
                LabeledContent("Credentials") {
                    Text("Auto-detected from Claude CLI")
                        .foregroundStyle(.green)
                }
            } else {
                LabeledContent("Credentials") {
                    Text("Not found — install Claude Code CLI")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Claude Code")
        } footer: {
            Text("Reads OAuth credentials from macOS Keychain (auto-detected from Claude Code CLI).")
        }

        Section {
            Toggle("Monitor Codex", isOn: Binding(
                get: { module.monitorCodex },
                set: { module.monitorCodex = $0 }
            ))

            if module.hasCodexToken {
                LabeledContent("Credentials") {
                    Text("Auto-detected from Codex CLI")
                        .foregroundStyle(.green)
                }
            } else {
                LabeledContent("Credentials") {
                    Text("Not found — install Codex CLI")
                        .foregroundStyle(.secondary)
                }
            }

            if let codex = module.codexUsage {
                if let error = codex.error {
                    LabeledContent("Status") {
                        Text(error).foregroundStyle(.red)
                    }
                } else if codex.limitReached {
                    LabeledContent("Status") {
                        Text("Limit reached").foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Text("Codex (OpenAI)")
        } footer: {
            Text("Reads OAuth credentials from ~/.codex/auth.json (auto-detected from Codex CLI).")
        }

        Section {
            Picker("Interval", selection: Binding(
                get: { module.refreshInterval },
                set: { module.refreshInterval = $0 }
            )) {
                Text("30 seconds").tag(30.0 as TimeInterval)
                Text("1 minute").tag(60.0 as TimeInterval)
                Text("2 minutes").tag(120.0 as TimeInterval)
                Text("5 minutes").tag(300.0 as TimeInterval)
            }

            Button("Refresh Now") { module.refresh() }
        } header: {
            Text("Refresh")
        }
    }
}
