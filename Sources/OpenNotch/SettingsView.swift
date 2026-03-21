import SwiftUI
import OpenNotchCore

// MARK: - Sidebar Item

private enum SettingsSidebarItem: Hashable, Identifiable {
    case general
    case notch
    case startup
    case module(String)
    case moduleSubpage(String, String)

    var id: String {
        switch self {
        case .general: return "core.general"
        case .notch: return "core.notch"
        case .startup: return "core.startup"
        case let .module(moduleID): return "module.\(moduleID)"
        case let .moduleSubpage(moduleID, sub): return "module.\(moduleID).\(sub)"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedItem: SettingsSidebarItem? = .general
    @State private var expandedDiagnosticSpaceIDs = Set<Int>()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("").frame(width: 0, height: 0).accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            Section("OpenNotch") {
                Label("General", systemImage: "gear")
                    .tag(SettingsSidebarItem.general)
                Label("Notch", systemImage: "rectangle.topthird.inset.filled")
                    .tag(SettingsSidebarItem.notch)
                Label("Startup", systemImage: "power")
                    .tag(SettingsSidebarItem.startup)
            }

            Section("Modules") {
                ForEach(model.moduleRegistry.modules, id: \.identifier) { module in
                    HStack {
                        Label(module.displayName, systemImage: module.icon)
                        Spacer()
                        if model.moduleRegistry.isEnabled(module.identifier) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .tag(SettingsSidebarItem.module(module.identifier.rawValue))

                    if module.identifier.rawValue == "com.opennotch.yabai",
                       model.moduleRegistry.isEnabled(module.identifier) {
                        Label("Diagnostics", systemImage: "stethoscope")
                            .padding(.leading, 12)
                            .tag(SettingsSidebarItem.moduleSubpage("com.opennotch.yabai", "diagnostics"))
                        Label("Configuration", systemImage: "doc.text")
                            .padding(.leading, 12)
                            .tag(SettingsSidebarItem.moduleSubpage("com.opennotch.yabai", "configuration"))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(190)
        .toolbar(removing: .sidebarToggle)
    }

    // MARK: Detail Routing

    @ViewBuilder
    private var detailContent: some View {
        switch selectedItem ?? .general {
        case .general:
            generalPage
        case .notch:
            notchPage
        case .startup:
            startupPage
        case let .module(moduleID):
            moduleSettingsPage(for: moduleID)
        case let .moduleSubpage(moduleID, subpage):
            moduleSubpage(for: moduleID, subpage: subpage)
        }
    }

    // MARK: - General Page

    private var generalPage: some View {
        Form {
            Section("Indicators") {
                Picker("Show indicators in", selection: indicatorSurfaceModeBinding) {
                    ForEach(IndicatorSurfaceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.indicatorSurfaceMode.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Notch Behavior") {
                Toggle("Open notch on hover", isOn: openNotchOnHoverBinding)
                Toggle("Enable haptic feedback", isOn: enableHapticsBinding)

                if model.openNotchOnHover {
                    LabeledContent {
                        Text("\(model.minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } label: {
                        Text("Hover delay")
                    }

                    Slider(value: minimumHoverDurationBinding, in: 0 ... 1, step: 0.1)
                }
            }
        }
    }

    // MARK: - Notch Page (NEW)

    private var notchPage: some View {
        Form {
            slotOrderSection(
                title: "Left Slots (Closed Notch)",
                side: .leading,
                order: model.moduleRegistry.leadingSlotOrder
            )

            slotOrderSection(
                title: "Right Slots (Closed Notch)",
                side: .trailing,
                order: model.moduleRegistry.trailingSlotOrder
            )

            Section {
                let enabledOrder = model.moduleRegistry.widgetOrder.filter { moduleID in
                    model.moduleRegistry.isEnabled(ModuleIdentifier(moduleID))
                }

                if enabledOrder.isEmpty {
                    Text("No modules enabled")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(enabledOrder.enumerated()), id: \.element) { index, moduleID in
                        let module = model.moduleRegistry.modules.first { $0.identifier.rawValue == moduleID }
                        HStack {
                            Label(module?.displayName ?? moduleID, systemImage: module?.icon ?? "questionmark")
                            Spacer()
                            orderButtons(
                                upAction: { model.moduleRegistry.moveWidgetUp(moduleID) },
                                downAction: { model.moduleRegistry.moveWidgetDown(moduleID) },
                                isFirst: index == 0,
                                isLast: index == enabledOrder.count - 1
                            )
                        }
                    }
                }
            } header: {
                Text("Expanded Widgets")
            } footer: {
                Text("Order of widgets shown when the notch is open.")
            }

            Section {
                Picker("Active module", selection: activeStatusBarModuleBinding) {
                    ForEach(model.moduleRegistry.enabledModules, id: \.identifier) { module in
                        Text(module.displayName).tag(Optional(module.identifier.rawValue))
                    }
                }
            } header: {
                Text("Status Bar")
            } footer: {
                Text("Only the active module's icon and label appear in the menu bar.")
            }
        }
    }

    private func slotOrderSection(title: String, side: ModuleRegistry.SlotSide, order: [String]) -> some View {
        let registry = model.moduleRegistry
        let enabledSlots = order.filter { slotID in
            guard let modID = registry.moduleID(from: slotID) else { return false }
            return registry.isEnabled(ModuleIdentifier(modID))
        }

        return Section {
            if enabledSlots.isEmpty {
                Text("No slots available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(enabledSlots.enumerated()), id: \.element) { index, slotID in
                    let isEnabled = registry.isSlotEnabled(slotID)
                    HStack {
                        Toggle(isOn: Binding(
                            get: { registry.isSlotEnabled(slotID) },
                            set: { registry.setSlotEnabled(slotID, $0) }
                        )) {
                            Text(registry.slotLabel(for: slotID))
                        }

                        Spacer()

                        orderButtons(
                            upAction: { registry.moveSlotUp(slotID, side: side) },
                            downAction: { registry.moveSlotDown(slotID, side: side) },
                            isFirst: index == 0,
                            isLast: index == enabledSlots.count - 1
                        )
                        .opacity(isEnabled ? 1 : 0.3)
                        .disabled(!isEnabled)
                    }
                }
            }
        } header: {
            Text(title)
        }
    }

    private func orderButtons(upAction: @escaping () -> Void, downAction: @escaping () -> Void, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 2) {
            Button(action: upAction) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(isFirst)

            Button(action: downAction) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(isLast)
        }
    }

    // MARK: - Startup Page

    private var startupPage: some View {
        Form {
            Section("Launch at Login") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .disabled(model.installationState != .installed)

                Text(model.loginItemState.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if model.needsLoginApproval {
                    Button("Open Login Items Settings") {
                        model.openLoginItemsSettings()
                    }
                }
            }

            Section("Installation") {
                LabeledContent("Status") {
                    Text(model.installationState.statusText)
                        .foregroundStyle(.secondary)
                }

                if model.canMoveToApplications {
                    Button("Install in Applications") {
                        model.installInApplications()
                    }
                }
            }

            Section("Yabai Integration") {
                LabeledContent("Status") {
                    Text(model.integrationState.statusText)
                        .foregroundStyle(.secondary)
                }

                if model.canRepairIntegration {
                    Button("Repair Yabai Integration") {
                        model.repairIntegration()
                    }
                }
            }
        }
    }

    // MARK: - Module Settings Page

    private func moduleSettingsPage(for moduleID: String) -> some View {
        let identifier = ModuleIdentifier(moduleID)
        let module = model.moduleRegistry.modules.first { $0.identifier == identifier }
        let isEnabled = model.moduleRegistry.isEnabled(identifier)

        return Form {
            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { model.moduleRegistry.isEnabled(identifier) },
                    set: { model.moduleRegistry.setEnabled(identifier, $0) }
                ))
            } header: {
                Text(module?.displayName ?? moduleID)
            }

            if isEnabled {
                if moduleID == "com.opennotch.yabai" {
                    yabaiSettingsSections
                } else if let settingsView = module?.makeSettingsView() {
                    settingsView
                }
            }
        }
    }

    // MARK: Yabai Settings Sections (no Form wrapper)

    @ViewBuilder
    private var yabaiSettingsSections: some View {
        Section {
            Picker("Style", selection: spaceIndicatorStyleBinding) {
                ForEach(SpaceIndicatorStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Space Indicator")
        } footer: {
            Text("How spaces are displayed in the notch. Dots uses an animated blob, Numbers shows space indices.")
        }

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
            Text("Affects Top Bar and Both modes. In Notch mode, the menu bar item is hidden.")
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

        Section {
            Button("Open yabairc") { model.openConfig() }
            Button("Open Yabai Folder") { model.openConfigDirectory() }
            Button("Refresh now") { model.refresh() }
        } header: {
            Text("Quick Actions")
        }

        Section {
            LabeledContent("Indicator surface") { Text(model.indicatorSurfaceMode.title) }
            LabeledContent("Runtime state") {
                Text(model.runtimeStatePath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            if let statusMessage = model.statusMessage, !statusMessage.isEmpty {
                LabeledContent("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Info")
        }
    }

    // MARK: - Module Subpage Routing

    @ViewBuilder
    private func moduleSubpage(for moduleID: String, subpage: String) -> some View {
        if moduleID == "com.opennotch.yabai" {
            switch subpage {
            case "diagnostics":
                diagnosticsPage
            case "configuration":
                configurationPage
            default:
                ContentUnavailableView("Unknown page", systemImage: "questionmark")
            }
        } else {
            ContentUnavailableView("Unknown page", systemImage: "questionmark")
        }
    }

    // MARK: - Diagnostics Page

    private var diagnosticsPage: some View {
        Form {
            if let msg = model.diagnosticsStatusMessage, !msg.isEmpty {
                Section {
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Status")
                }
            }

            if model.diagnosticDisplays.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No diagnostics available",
                        systemImage: "eye.slash",
                        description: Text("Click Refresh to inspect spaces and windows.")
                    )
                } header: {
                    Text("Spaces")
                }
            } else {
                ForEach(model.diagnosticDisplays) { display in
                    Section {
                        ForEach(display.spaces) { space in
                            diagnosticSpaceRow(space)
                        }
                    } header: {
                        HStack {
                            Text("Display \(display.index)")
                            if display.hasFocus {
                                Text("Active")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Refresh Diagnostics") { model.refreshDiagnostics() }
                Button("Recheck All Spaces") { model.recheckAllSpaces() }

                if let updatedAt = model.diagnosticsUpdatedAt {
                    LabeledContent("Last updated") {
                        Text(updatedAt.formatted(date: .omitted, time: .standard))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Actions")
            }
        }
    }

    private func diagnosticSpaceRow(_ space: SpaceDiagnosticSummary) -> some View {
        let comparison = model.diagnosticsComparison(for: space)

        return DisclosureGroup(isExpanded: diagnosticDisclosureBinding(for: space.index)) {
            VStack(alignment: .leading, spacing: 8) {
                // Metrics
                HStack(spacing: 0) {
                    diagnosticMetricCell("Live", value: space.isStack ? "\(space.countedStackWindowCount)" : "--")
                    diagnosticMetricCell("Local", value: comparison.trackedState.map { "\($0.total)" } ?? "--")
                    diagnosticMetricCell("Live focus", value: space.liveStackSummary?.badgeLabel ?? "--")
                    diagnosticMetricCell("Local focus", value: comparison.trackedState.map { "\($0.currentIndex)/\($0.total)" } ?? "--")
                }

                Divider()

                // Windows
                ForEach(space.windows) { window in
                    diagnosticWindowRow(window, spaceIndex: space.index)
                }

                // Actions
                HStack(spacing: 8) {
                    Button("Recheck") { model.recheckSpace(space.index) }
                        .controlSize(.small)
                    if comparison.trackedState != nil {
                        Button("Purge local state") { model.purgeLocalTrackedState(for: space.index) }
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 8) {
                Text("Space \(space.index)")
                    .fontWeight(.medium)

                Text(space.type?.uppercased() ?? "—")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if space.hasFocus {
                    Text("Focused")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else if space.isVisible {
                    Text("Visible")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(comparison.status.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(diagnosticStatusColor(comparison.status))
            }
        }
    }

    private func diagnosticMetricCell(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func diagnosticWindowRow(_ window: WindowDiagnosticItem, spaceIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text(window.countedPosition.map(String.init) ?? "·")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(window.countsTowardStack ? .primary : .quaternary)
                .frame(width: 18, height: 18)
                .background(window.hasFocus ? Color.accentColor.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 1) {
                Text(window.app)
                    .font(.callout)
                    .fontWeight(window.hasFocus ? .semibold : .regular)

                HStack(spacing: 4) {
                    if window.hasFocus { diagnosticTag("focus", color: .blue) }
                    if window.isHidden { diagnosticTag("hidden", color: .orange) }
                    if window.isMinimized { diagnosticTag("min", color: .orange) }
                    if window.isFloating { diagnosticTag("float", color: .purple) }
                    Text("#\(window.id)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer(minLength: 0)

            Button {
                model.quitApplication(pid: window.pid, spaceIndex: spaceIndex)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .help("Quit \(window.app)")
        }
        .padding(.vertical, 2)
    }

    private func diagnosticTag(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func diagnosticStatusColor(_ status: SpaceDiagnosticsStatus) -> Color {
        switch status {
        case .synced: return .green
        case .notStack, .notTracked: return .secondary
        case .liveOnly, .unresolvedFocus: return .yellow
        case .countMismatch, .focusMismatch, .staleLocal: return .red
        }
    }

    private func diagnosticDisclosureBinding(for spaceIndex: Int) -> Binding<Bool> {
        Binding(
            get: { expandedDiagnosticSpaceIDs.contains(spaceIndex) },
            set: { if $0 { expandedDiagnosticSpaceIDs.insert(spaceIndex) } else { expandedDiagnosticSpaceIDs.remove(spaceIndex) } }
        )
    }

    // MARK: - Configuration Page

    private var configurationPage: some View {
        Form {
            if model.yabaiConfigContent == nil, model.skhdConfigContent == nil {
                Section {
                    ContentUnavailableView(
                        "No configuration files found",
                        systemImage: "doc.text",
                        description: Text("Expected yabairc at ~/.config/yabai/yabairc")
                    )
                }
            } else {
                if let skhdContent = model.skhdConfigContent {
                    configKeybindingSections(skhdContent)
                }

                if let yabaiContent = model.yabaiConfigContent {
                    configSettingsSection(yabaiContent)
                    configRulesSection(yabaiContent)
                }
            }

            Section {
                Button("Reload Configuration") { model.loadConfigFiles() }
                Button("Open yabairc") { model.openConfig() }
                if model.skhdConfigContent != nil {
                    Button("Open skhdrc") { model.openSkhdConfig() }
                }
            } header: {
                Text("Actions")
            }
        }
        .onAppear { model.loadConfigFiles() }
    }

    @ViewBuilder
    private func configKeybindingSections(_ content: String) -> some View {
        let bindings = Self.parseSkhdBindings(content)
        let sections = Self.groupBindingsBySection(bindings)

        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
            Section {
                ForEach(Array(section.bindings.enumerated()), id: \.offset) { _, binding in
                    LabeledContent {
                        Text(binding.command)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(binding.shortcut)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } header: {
                Text(section.header ?? "Keybindings")
            }
        }
    }

    @ViewBuilder
    private func configSettingsSection(_ content: String) -> some View {
        let settings = Self.parseYabaiSettings(content)

        Section {
            if settings.isEmpty {
                Text("No settings found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(settings.enumerated()), id: \.offset) { _, entry in
                    LabeledContent {
                        Text(entry.value)
                            .font(.system(.body, design: .monospaced))
                    } label: {
                        Text(entry.key)
                    }
                }
            }
        } header: {
            Text("Yabai Settings")
        }
    }

    @ViewBuilder
    private func configRulesSection(_ content: String) -> some View {
        let rules = Self.parseYabaiRules(content)

        if !rules.isEmpty {
            Section {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    Text(rule)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } header: {
                Text("Rules")
            }
        }
    }

    // MARK: - Config Parsing Helpers

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
                if !comment.isEmpty, !comment.hasPrefix("!") { currentSection = comment }
                continue
            }
            if trimmed.isEmpty { continue }
            guard let colonRange = trimmed.range(of: " : ") else { continue }
            let shortcutRaw = String(trimmed[trimmed.startIndex ..< colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let commandRaw = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            bindings.append(SkhdBinding(shortcut: formatShortcut(shortcutRaw), command: simplifyYabaiCommand(commandRaw), section: currentSection))
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
            firstCommand = String(raw[raw.startIndex ..< semicolonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
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
                if raw.contains(";") { result += " +" }
                return result
            }
        }
        return raw
    }

    private static func parseYabaiSettings(_ content: String) -> [(key: String, value: String)] {
        var settings: [(key: String, value: String)] = []
        let managedMarkers = ["# >>> OpenNotch >>>", "# >>> YabaiBar >>>"]
        let managedEndMarkers = ["# <<< OpenNotch <<<", "# <<< YabaiBar <<<"]
        var inManaged = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if managedMarkers.contains(where: { trimmed.contains($0) }) { inManaged = true; continue }
            if managedEndMarkers.contains(where: { trimmed.contains($0) }) { inManaged = false; continue }
            if inManaged { continue }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard trimmed.hasPrefix("yabai -m config ") else { continue }
            let remainder = String(trimmed.dropFirst("yabai -m config ".count)).trimmingCharacters(in: .whitespaces)
            let parts = remainder.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { settings.append((key: parts[0], value: parts[1])) }
        }
        return settings
    }

    private static func parseYabaiRules(_ content: String) -> [String] {
        var rules: [String] = []
        let managedMarkers = ["# >>> OpenNotch >>>", "# >>> YabaiBar >>>"]
        let managedEndMarkers = ["# <<< OpenNotch <<<", "# <<< YabaiBar <<<"]
        var inManaged = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if managedMarkers.contains(where: { trimmed.contains($0) }) { inManaged = true; continue }
            if managedEndMarkers.contains(where: { trimmed.contains($0) }) { inManaged = false; continue }
            if inManaged { continue }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard trimmed.hasPrefix("yabai -m rule --add ") else { continue }
            rules.append(String(trimmed.dropFirst("yabai -m rule --add ".count)).trimmingCharacters(in: .whitespaces))
        }
        return rules
    }

    // MARK: - Bindings

    private var indicatorSurfaceModeBinding: Binding<IndicatorSurfaceMode> {
        Binding(get: { model.indicatorSurfaceMode }, set: { model.setIndicatorSurfaceMode($0) })
    }

    private var menuBarLabelModeBinding: Binding<MenuBarLabelMode> {
        Binding(get: { model.menuBarLabelMode }, set: { model.setMenuBarLabelMode($0) })
    }

    private var spaceIndicatorStyleBinding: Binding<SpaceIndicatorStyle> {
        Binding(get: { model.spaceIndicatorStyle }, set: { model.setSpaceIndicatorStyle($0) })
    }

    private var showAppNamesBinding: Binding<Bool> {
        Binding(get: { model.showAppNamesInMenu }, set: { model.setShowAppNamesInMenu($0) })
    }

    private var maxAppsBinding: Binding<Int> {
        Binding(get: { model.maxAppsShownPerSpace }, set: { model.setMaxAppsShownPerSpace($0) })
    }

    private var groupSpacesBinding: Binding<Bool> {
        Binding(get: { model.groupSpacesByDisplay }, set: { model.setGroupSpacesByDisplay($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { model.launchAtLoginEnabled }, set: { model.setLaunchAtLoginEnabled($0) })
    }

    private var openNotchOnHoverBinding: Binding<Bool> {
        Binding(get: { model.openNotchOnHover }, set: { model.setOpenNotchOnHover($0) })
    }

    private var minimumHoverDurationBinding: Binding<Double> {
        Binding(get: { model.minimumHoverDuration }, set: { model.setMinimumHoverDuration($0) })
    }

    private var enableHapticsBinding: Binding<Bool> {
        Binding(get: { model.enableHaptics }, set: { model.setEnableHaptics($0) })
    }

    private var activeStatusBarModuleBinding: Binding<String?> {
        Binding(
            get: { model.moduleRegistry.activeStatusBarModuleID },
            set: { model.moduleRegistry.activeStatusBarModuleID = $0 }
        )
    }
}
