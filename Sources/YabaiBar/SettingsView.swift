import SwiftUI
import YabaiBarCore

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case startup
    case diagnostics
    case tools
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

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(space.windows) { window in
                        diagnosticWindowRow(window)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Space \(space.index)")
                        .font(.system(size: 13, weight: .semibold))

                    Text(space.type?.uppercased() ?? "UNKNOWN")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    if space.hasFocus {
                        Text("Focused")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else if space.isVisible {
                        Text("Visible")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
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

    private func diagnosticWindowRow(_ window: WindowDiagnosticItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(window.countedPosition.map(String.init) ?? "·")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(window.countsTowardStack ? .primary : .secondary)
                    .frame(width: 14, alignment: .leading)

                Text(window.app)
                    .font(.system(size: 12, weight: window.hasFocus ? .semibold : .medium))

                if !window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   window.title != window.app {
                    Text(window.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let stackIndex = window.stackIndex {
                    Text("stack \(stackIndex)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("#\(window.id)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                if window.hasFocus { diagnosticFlag("focus") }
                if window.countsTowardStack { diagnosticFlag("counted") }
                if window.isHidden { diagnosticFlag("hidden") }
                if window.isMinimized { diagnosticFlag("minimized") }
                if window.isFloating { diagnosticFlag("floating") }
            }
        }
        .padding(.vertical, 2)
    }

    private func diagnosticFlag(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
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
