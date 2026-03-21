import SwiftUI
import YabaiBarCore

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case startup
    case diagnostics
    case tools
    case configuration
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .appearance:
            return "Appearance"
        case .startup:
            return "Startup"
        case .diagnostics:
            return "Diagnostics"
        case .tools:
            return "Tools"
        case .configuration:
            return "Configuration"
        case .advanced:
            return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gear"
        case .appearance:
            return "eye"
        case .startup:
            return "power"
        case .diagnostics:
            return "stethoscope"
        case .tools:
            return "wrench.and.screwdriver"
        case .configuration:
            return "doc.text.magnifyingglass"
        case .advanced:
            return "gearshape.2"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedSection: SettingsSection? = .general
    @State private var expandedDiagnosticSpaceIDs = Set<Int>()

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedSection ?? .general {
                case .general:
                    generalSection
                case .appearance:
                    appearanceSection
                case .startup:
                    startupSection
                case .diagnostics:
                    diagnosticsSection
                case .tools:
                    toolsSection
                case .configuration:
                    configurationSection
                case .advanced:
                    advancedSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var generalSection: some View {
        Form {
            Section {
                Picker("Show indicators in", selection: indicatorSurfaceModeBinding) {
                    ForEach(IndicatorSurfaceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.indicatorSurfaceMode.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Indicators")
            } footer: {
                Text("In `Notch`, the menu bar icon is fully hidden and the notch becomes the only visible surface.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open notch on hover", isOn: openNotchOnHoverBinding)
                Toggle("Enable haptic feedback", isOn: enableHapticsBinding)

                if model.openNotchOnHover {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hover delay")
                            Spacer()
                            Text("\(model.minimumHoverDuration, specifier: "%.1f")s")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: minimumHoverDurationBinding, in: 0...1, step: 0.1)
                    }
                }
            } header: {
                Text("Notch behavior")
            }
        }
        .navigationTitle("General")
    }

    private var appearanceSection: some View {
        Form {
            Section {
                Picker("Label style", selection: menuBarLabelModeBinding) {
                    ForEach(MenuBarLabelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("This affects `Top Bar` and `Both`. In `Notch`, the menu bar item is hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show app names in the menu", isOn: showAppNamesBinding)

                Picker("Apps shown per space", selection: maxAppsBinding) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
                .disabled(!model.showAppNamesInMenu)

                Toggle("Group spaces by display", isOn: groupSpacesBinding)
            } header: {
                Text("Menu Content")
            }
        }
        .navigationTitle("Appearance")
    }

    private var startupSection: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .disabled(model.installationState != .installed)

                Text(model.loginItemState.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if model.needsLoginApproval {
                    Button("Open Login Items Settings") {
                        model.openLoginItemsSettings()
                    }
                }
            } header: {
                Text("Launch at Login")
            }

            Section {
                Text(model.installationState.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if model.canMoveToApplications {
                    Button("Install in Applications") {
                        model.installInApplications()
                    }
                }
            } header: {
                Text("Installation")
            }

            Section {
                Text(model.integrationState.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if model.canRepairIntegration {
                    Button("Repair Yabai Integration") {
                        model.repairIntegration()
                    }
                }
            } header: {
                Text("Yabai Integration")
            }
        }
        .navigationTitle("Startup")
    }

    private var toolsSection: some View {
        Form {
            Section {
                Button("Open yabairc") {
                    model.openConfig()
                }

                Button("Open Yabai Folder") {
                    model.openConfigDirectory()
                }
            } header: {
                Text("Files")
            }

            Section {
                Button("Refresh now") {
                    model.refresh()
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Tools")
    }

    private var configurationSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                configToolbar
                configBody
            }
            .padding(20)
        }
        .navigationTitle("Configuration")
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { model.loadConfigFiles() }
    }

    private var configToolbar: some View {
        HStack(spacing: 10) {
            Button("Reload") {
                model.loadConfigFiles()
            }

            Button("Open yabairc") {
                model.openConfig()
            }

            if model.skhdConfigContent != nil {
                Button("Open skhdrc") {
                    model.openSkhdConfig()
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var configBody: some View {
        if model.yabaiConfigContent == nil, model.skhdConfigContent == nil {
            ContentUnavailableView(
                "No configuration files found",
                systemImage: "doc.text",
                description: Text("Expected yabairc at ~/.config/yabai/yabairc")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            if let skhdContent = model.skhdConfigContent {
                configSkhdSection(skhdContent)
            }
            if let yabaiContent = model.yabaiConfigContent {
                configYabaiSettingsSection(yabaiContent)
                configYabaiRulesSection(yabaiContent)
            }
        }
    }

    private func configSkhdSection(_ content: String) -> some View {
        let bindings = Self.parseSkhdBindings(content)
        let sections = Self.groupBindingsBySection(bindings)

        return GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                ForEach(Array(sections.enumerated()), id: \.offset) { sectionIdx, section in
                    if let header = section.header {
                        GridRow {
                            Text(header)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, sectionIdx == 0 ? 0 : 8)
                                .gridCellColumns(2)
                        }
                    }

                    ForEach(Array(section.bindings.enumerated()), id: \.offset) { _, binding in
                        GridRow {
                            Text(binding.shortcut)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .gridColumnAlignment(.trailing)

                            Text(binding.command)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .gridColumnAlignment(.leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 6) {
                Text("Keybindings")
                Text("skhd")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func configYabaiSettingsSection(_ content: String) -> some View {
        let settings = Self.parseYabaiSettings(content)

        return GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                if settings.isEmpty {
                    GridRow {
                        Text("No settings found")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .gridCellColumns(2)
                    }
                } else {
                    ForEach(Array(settings.enumerated()), id: \.offset) { _, entry in
                        GridRow {
                            Text(entry.key)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)

                            Text(entry.value)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .gridColumnAlignment(.leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 6) {
                Text("Settings")
                Text("yabairc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func configYabaiRulesSection(_ content: String) -> some View {
        let rules = Self.parseYabaiRules(content)

        return Group {
            if !rules.isEmpty {
                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                            GridRow {
                                Text(rule)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Rules")
                }
            }
        }
    }

    private struct SkhdBinding {
        let shortcut: String
        let command: String
        let section: String?
    }

    private struct SkhdSection {
        let header: String?
        let bindings: [SkhdBinding]
    }

    private static func parseSkhdBindings(_ content: String) -> [SkhdBinding] {
        var bindings: [SkhdBinding] = []
        var currentSection: String?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#") {
                let comment = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !comment.isEmpty, !comment.hasPrefix("!") {
                    currentSection = comment
                }
                continue
            }

            if trimmed.isEmpty { continue }

            guard let colonRange = trimmed.range(of: " : ") else { continue }
            let shortcutRaw = String(trimmed[trimmed.startIndex ..< colonRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let commandRaw = String(trimmed[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            let formatted = formatShortcut(shortcutRaw)
            let simplified = simplifyYabaiCommand(commandRaw)

            bindings.append(SkhdBinding(
                shortcut: formatted,
                command: simplified,
                section: currentSection
            ))
        }

        return bindings
    }

    private static func groupBindingsBySection(_ bindings: [SkhdBinding]) -> [SkhdSection] {
        var sections: [SkhdSection] = []
        var currentHeader: String?
        var currentBindings: [SkhdBinding] = []

        for binding in bindings {
            if binding.section != currentHeader, !currentBindings.isEmpty {
                sections.append(SkhdSection(header: currentHeader, bindings: currentBindings))
                currentBindings = []
            }
            currentHeader = binding.section
            currentBindings.append(binding)
        }

        if !currentBindings.isEmpty {
            sections.append(SkhdSection(header: currentHeader, bindings: currentBindings))
        }

        return sections
    }

    private static func formatShortcut(_ raw: String) -> String {
        raw.replacingOccurrences(of: "shift + alt", with: "⇧⌥")
            .replacingOccurrences(of: "shift + cmd", with: "⇧⌘")
            .replacingOccurrences(of: "ctrl + alt", with: "⌃⌥")
            .replacingOccurrences(of: "cmd + alt", with: "⌘⌥")
            .replacingOccurrences(of: "ctrl + cmd", with: "⌃⌘")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: " - ", with: " ")
    }

    private static func simplifyYabaiCommand(_ raw: String) -> String {
        let firstCommand: String
        if let semicolonRange = raw.range(of: ";") {
            firstCommand = String(raw[raw.startIndex ..< semicolonRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            firstCommand = raw
        }

        let replacements: [(String, String)] = [
            ("yabai -m window --focus ", "Focus window "),
            ("yabai -m window --swap ", "Swap window "),
            ("yabai -m window --warp ", "Warp window "),
            ("yabai -m window --toggle ", "Toggle "),
            ("yabai -m window --resize ", "Resize "),
            ("yabai -m window --move ", "Move window "),
            ("yabai -m window --display ", "Send to display "),
            ("yabai -m window --space ", "Send to space "),
            ("yabai -m window --grid ", "Grid "),
            ("yabai -m space --focus ", "Focus space "),
            ("yabai -m space --create", "Create space"),
            ("yabai -m space --destroy", "Destroy space"),
            ("yabai -m space --balance", "Balance"),
            ("yabai -m space --rotate ", "Rotate "),
            ("yabai -m space --mirror ", "Mirror "),
            ("yabai -m space --layout ", "Layout "),
            ("yabai -m display --focus ", "Focus display "),
        ]

        for (pattern, replacement) in replacements {
            if firstCommand.hasPrefix(pattern) {
                var result = firstCommand.replacingOccurrences(of: pattern, with: replacement)
                if raw.contains(";") {
                    result += " +"
                }
                return result
            }
        }

        return raw
    }

    private static func parseYabaiSettings(_ content: String) -> [(key: String, value: String)] {
        var settings: [(key: String, value: String)] = []
        let managedStart = "# >>> YabaiBar >>>"
        let managedEnd = "# <<< YabaiBar <<<"
        var inManaged = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(managedStart) { inManaged = true; continue }
            if trimmed.contains(managedEnd) { inManaged = false; continue }
            if inManaged { continue }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            guard trimmed.hasPrefix("yabai -m config ") else { continue }
            let remainder = String(trimmed.dropFirst("yabai -m config ".count))
                .trimmingCharacters(in: .whitespaces)
            let parts = remainder.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                settings.append((key: parts[0], value: parts[1]))
            }
        }

        return settings
    }

    private static func parseYabaiRules(_ content: String) -> [String] {
        var rules: [String] = []
        let managedStart = "# >>> YabaiBar >>>"
        let managedEnd = "# <<< YabaiBar <<<"
        var inManaged = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(managedStart) { inManaged = true; continue }
            if trimmed.contains(managedEnd) { inManaged = false; continue }
            if inManaged { continue }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            guard trimmed.hasPrefix("yabai -m rule --add ") else { continue }
            let remainder = String(trimmed.dropFirst("yabai -m rule --add ".count))
                .trimmingCharacters(in: .whitespaces)
            rules.append(remainder)
        }

        return rules
    }

    private var diagnosticsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                diagnosticsToolbar
                diagnosticsStatusBanner
                diagnosticsBody
            }
            .padding(20)
        }
        .navigationTitle("Diagnostics")
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var diagnosticsToolbar: some View {
        HStack(spacing: 10) {
            Button("Refresh diagnostics") {
                model.refreshDiagnostics()
            }

            Button("Recheck all") {
                model.recheckAllSpaces()
            }

            Spacer(minLength: 0)

            if let updatedAt = model.diagnosticsUpdatedAt {
                Text(updatedAt.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var diagnosticsStatusBanner: some View {
        if let diagnosticsStatusMessage = model.diagnosticsStatusMessage, !diagnosticsStatusMessage.isEmpty {
            Text(diagnosticsStatusMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var diagnosticsBody: some View {
        if model.diagnosticDisplays.isEmpty {
            ContentUnavailableView(
                "No diagnostics available",
                systemImage: "eye.slash",
                description: Text("Refresh diagnostics to inspect spaces, windows, and local stack tracking.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            ForEach(model.diagnosticDisplays) { display in
                diagnosticsDisplayGroup(display)
            }
        }
    }

    private func diagnosticsDisplayGroup(_ display: DisplayDiagnosticSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(display.spaces) { space in
                    diagnosticSpaceDisclosure(space)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 8) {
                Text("Display \(display.index)")
                if display.hasFocus {
                    Text("Active")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var advancedSection: some View {
        Form {
            Section {
                LabeledContent("Indicator surface") { Text(model.indicatorSurfaceMode.title) }
                LabeledContent("Runtime state file") {
                    Text(model.runtimeStatePath)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                if let statusMessage = model.statusMessage, !statusMessage.isEmpty {
                    LabeledContent("App status") {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Internal")
            }
        }
        .navigationTitle("Advanced")
    }

    @ViewBuilder
    private func diagnosticSpaceDisclosure(_ space: SpaceDiagnosticSummary) -> some View {
        let comparison = model.diagnosticsComparison(for: space)

        DisclosureGroup(isExpanded: diagnosticDisclosureBinding(for: space.index)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button("Recheck this space") {
                        model.recheckSpace(space.index)
                    }

                    if comparison.trackedState != nil {
                        Button("Purge local stack state") {
                            model.purgeLocalTrackedState(for: space.index)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(space.windows) { window in
                        diagnosticWindowRow(window, spaceIndex: space.index)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Space \(space.index)")
                        .font(.system(size: 13, weight: .semibold))

                    diagnosticPill(space.type?.uppercased() ?? "UNKNOWN")

                    if space.hasFocus {
                        diagnosticPill("Focused", color: .blue)
                    } else if space.isVisible {
                        diagnosticPill("Visible")
                    }

                    Spacer(minLength: 0)

                    Text(comparison.status.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(diagnosticStatusColor(comparison.status))
                }

                HStack(spacing: 14) {
                    diagnosticMetric("Live", value: space.isStack ? "\(space.countedStackWindowCount)" : "--")
                    diagnosticMetric("Local", value: comparison.trackedState.map { "\($0.total)" } ?? "--")
                    diagnosticMetric("Live focus", value: space.liveStackSummary?.badgeLabel ?? "--")
                    diagnosticMetric("Local focus", value: comparison.trackedState.map { "\($0.currentIndex)/\($0.total)" } ?? "--")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func diagnosticMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func diagnosticWindowRow(_ window: WindowDiagnosticItem, spaceIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text(window.countedPosition.map(String.init) ?? "·")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(window.countsTowardStack ? .primary : .quaternary)
                .frame(width: 18, height: 18)
                .background(window.hasFocus ? Color.accentColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(window.app)
                        .font(.system(size: 12, weight: window.hasFocus ? .semibold : .medium))

                    if !window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       window.title != window.app {
                        Text("— \(window.title)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    if window.hasFocus { diagnosticFlag("focus", color: .blue) }
                    if window.isHidden { diagnosticFlag("hidden", color: .orange) }
                    if window.isMinimized { diagnosticFlag("minimized", color: .orange) }
                    if window.isFloating { diagnosticFlag("floating", color: .purple) }

                    Text("#\(window.id)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer(minLength: 0)

            Button {
                model.quitApplication(pid: window.pid, spaceIndex: spaceIndex)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit \(window.app)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(window.hasFocus ? Color.accentColor.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func diagnosticFlag(_ label: String, color: Color = .secondary) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func diagnosticPill(_ label: String, color: Color = .secondary) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func diagnosticStatusColor(_ status: SpaceDiagnosticsStatus) -> Color {
        switch status {
        case .synced:
            return .green
        case .notStack, .notTracked:
            return .secondary
        case .liveOnly, .unresolvedFocus:
            return .yellow
        case .countMismatch, .focusMismatch, .staleLocal:
            return .red
        }
    }

    private func diagnosticDisclosureBinding(for spaceIndex: Int) -> Binding<Bool> {
        Binding(
            get: { expandedDiagnosticSpaceIDs.contains(spaceIndex) },
            set: { isExpanded in
                if isExpanded {
                    expandedDiagnosticSpaceIDs.insert(spaceIndex)
                } else {
                    expandedDiagnosticSpaceIDs.remove(spaceIndex)
                }
            }
        )
    }

    private var indicatorSurfaceModeBinding: Binding<IndicatorSurfaceMode> {
        Binding(
            get: { model.indicatorSurfaceMode },
            set: { model.setIndicatorSurfaceMode($0) }
        )
    }

    private var menuBarLabelModeBinding: Binding<MenuBarLabelMode> {
        Binding(
            get: { model.menuBarLabelMode },
            set: { model.setMenuBarLabelMode($0) }
        )
    }

    private var showAppNamesBinding: Binding<Bool> {
        Binding(
            get: { model.showAppNamesInMenu },
            set: { model.setShowAppNamesInMenu($0) }
        )
    }

    private var maxAppsBinding: Binding<Int> {
        Binding(
            get: { model.maxAppsShownPerSpace },
            set: { model.setMaxAppsShownPerSpace($0) }
        )
    }

    private var groupSpacesBinding: Binding<Bool> {
        Binding(
            get: { model.groupSpacesByDisplay },
            set: { model.setGroupSpacesByDisplay($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }

    private var openNotchOnHoverBinding: Binding<Bool> {
        Binding(
            get: { model.openNotchOnHover },
            set: { model.setOpenNotchOnHover($0) }
        )
    }

    private var minimumHoverDurationBinding: Binding<Double> {
        Binding(
            get: { model.minimumHoverDuration },
            set: { model.setMinimumHoverDuration($0) }
        )
    }

    private var enableHapticsBinding: Binding<Bool> {
        Binding(
            get: { model.enableHaptics },
            set: { model.setEnableHaptics($0) }
        )
    }
}
