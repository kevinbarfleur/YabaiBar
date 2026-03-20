import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case startup
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

    private var advancedSection: some View {
        Form {
            Section {
                LabeledContent("Indicator surface") {
                    Text(model.indicatorSurfaceMode.title)
                }

                LabeledContent("Active display") {
                    Text(model.activeDisplayLabel)
                }

                LabeledContent("Active space") {
                    Text(model.activeSpaceLabel)
                }

                LabeledContent("Stack") {
                    Text(model.activeStackSummary?.badgeLabel ?? "None")
                        .monospacedDigit()
                }

                LabeledContent("Integration") {
                    Text(model.integrationState.statusText)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage = model.statusMessage, !statusMessage.isEmpty {
                    LabeledContent("Status") {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Diagnostics")
            }
        }
        .navigationTitle("Advanced")
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
