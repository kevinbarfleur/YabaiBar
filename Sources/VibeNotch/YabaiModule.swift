import AppKit
import VibeNotchCore
import SwiftUI

func isWidgetCollapsed(_ widgetID: String) -> Bool {
    UserDefaults.standard.bool(forKey: "Widget.collapsed.\(widgetID)")
}

func setWidgetCollapsed(_ widgetID: String, _ collapsed: Bool) {
    UserDefaults.standard.set(collapsed, forKey: "Widget.collapsed.\(widgetID)")
}

@MainActor
final class YabaiModule: VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.yabai")
    let displayName = "Yabai"
    let icon = "square.grid.3x3"

    var objectDidChange: (() -> Void)?

    private weak var appModel: AppModel?

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func activate() {}
    func deactivate() {}

    func closedLeadingView(for displayUUID: String) -> NotchSlotContent? {
        guard let appModel,
              let state = appModel.displayNotchState(for: displayUUID) else {
            return nil
        }

        let tokens = spaceRailTokens(for: state, maxVisibleSpaces: 4)
        guard !tokens.isEmpty else { return nil }

        let style = appModel.spaceIndicatorStyle
        let tokenCount = tokens.count
        let width: CGFloat
        switch style {
        case .metaball:
            let dotSize: CGFloat = 6
            let spacing: CGFloat = 6
            width = CGFloat(tokenCount) * dotSize + CGFloat(tokenCount - 1) * spacing
        case .numbers:
            width = NumberSpaceRailView.contentWidth(for: tokenCount)
        }

        return NotchSlotContent(
            view: AnyView(
                YabaiSpaceRailSlot(state: state, tokens: tokens, style: style)
            ),
            width: width
        )
    }

    func closedTrailingView(for displayUUID: String) -> NotchSlotContent? {
        guard let appModel,
              let state = appModel.displayNotchState(for: displayUUID) else {
            return nil
        }

        return NotchSlotContent(
            view: AnyView(
                YabaiStackBadgeSlot(badgeLabel: state.stackSummary?.badgeLabel)
            ),
            width: 64
        )
    }

    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        guard let appModel,
              let state = appModel.displayNotchState(for: displayUUID) else {
            return []
        }

        let listItemCount: Int
        if !state.stackItems.isEmpty {
            listItemCount = min(state.stackItems.count, 6)
        } else {
            listItemCount = min(state.visibleSpaceApps.count, 6)
        }
        let widgetID = "yabai-space-detail"
        let collapsed = isWidgetCollapsed(widgetID)

        let listHeight = CGFloat(listItemCount) * 30
        let estimatedHeight: CGFloat = collapsed ? 40 : (60 + listHeight)

        return [
            NotchExpandedWidget(
                id: widgetID,
                moduleID: identifier,
                estimatedHeight: estimatedHeight,
                content: AnyView(
                    YabaiExpandedContent(
                        state: state,
                        isCollapsed: collapsed,
                        onToggleCollapse: { [weak self] in
                            setWidgetCollapsed(widgetID, !collapsed)
                            self?.objectDidChange?()
                        },
                        onOpenSettings: { [weak appModel] in appModel?.openSettings() },
                        onRefresh: { [weak appModel] in appModel?.refresh() },
                        onFocusWindow: { [weak appModel] id in appModel?.focusWindow(id) }
                    )
                )
            ),
        ]
    }

    func statusBarContent() -> StatusBarContent? {
        guard let appModel else { return nil }

        let image = NSImage(systemSymbolName: "square.3.layers.3d.top.filled", accessibilityDescription: nil)
        image?.isTemplate = true

        return StatusBarContent(
            icon: image,
            label: appModel.activeSpaceDisplayLabel,
            tooltip: appModel.activeSpaceTooltip,
            length: statusBarLength()
        )
    }

    func menuSections() -> [ModuleMenuSection] {
        guard let appModel else { return [] }

        var items: [NSMenuItem] = []

        if appModel.isUnavailable, appModel.snapshot == nil {
            let unavailableItem = NSMenuItem(title: "Yabai unavailable", action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            items.append(unavailableItem)
            return [ModuleMenuSection(items: items)]
        }

        if let statusMessage = appModel.statusMessage {
            let statusItem = NSMenuItem(title: statusMessage, action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            items.append(statusItem)
        }

        if let activeStackMenuLabel = appModel.activeStackMenuLabel {
            let stackItem = NSMenuItem(title: activeStackMenuLabel, action: nil, keyEquivalent: "")
            stackItem.isEnabled = false
            items.append(stackItem)
        }

        if !items.isEmpty {
            items.append(.separator())
        }

        let spaces = appModel.spaces
        if spaces.isEmpty {
            let noSpacesItem = NSMenuItem(title: "No spaces found", action: nil, keyEquivalent: "")
            noSpacesItem.isEnabled = false
            items.append(noSpacesItem)
        } else {
            for (offset, section) in appModel.menuSpaceSections.enumerated() {
                if offset > 0 {
                    items.append(.separator())
                }

                if let title = section.title {
                    let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    titleItem.isEnabled = false
                    items.append(titleItem)
                }

                for space in section.spaces {
                    let spaceItem = NSMenuItem(
                        title: appModel.menuSpaceTitle(for: space),
                        action: nil,
                        keyEquivalent: ""
                    )
                    spaceItem.state = appModel.isSpaceFocused(space.index) ? .on : .off
                    items.append(spaceItem)
                }
            }
        }

        return [ModuleMenuSection(title: "Spaces", items: items)]
    }

    func makeSettingsView() -> AnyView? {
        guard let appModel else { return nil }
        return AnyView(YabaiSettingsView(appModel: appModel))
    }

    func refresh() {
        appModel?.refresh()
    }

    func displayChanged() {
        appModel?.refresh()
    }

    private func statusBarLength() -> CGFloat {
        guard let appModel else { return NSStatusItem.squareLength }

        let label = appModel.activeSpaceDisplayLabel
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        ]
        let baseWidth = NSAttributedString(string: label, attributes: attributes).size().width
        return baseWidth + 22
    }

    private func spaceRailTokens(for state: DisplayNotchState, maxVisibleSpaces: Int) -> [SpaceRailToken] {
        let spaces = state.spaceIndexes.sorted()
        let activeSpaceIndex = state.visibleSpaceIndex

        guard !spaces.isEmpty else {
            return [.ellipsis]
        }

        guard spaces.count > maxVisibleSpaces,
              let activeSpaceIndex,
              let activeOffset = spaces.firstIndex(of: activeSpaceIndex) else {
            return spaces.map { .space(index: $0, isActive: $0 == activeSpaceIndex) }
        }

        let halfWindow = maxVisibleSpaces / 2
        var start = max(0, activeOffset - halfWindow)
        let end = min(spaces.count, start + maxVisibleSpaces)
        start = max(0, end - maxVisibleSpaces)

        var tokens: [SpaceRailToken] = []
        if start > 0 {
            tokens.append(.ellipsis)
        }

        tokens.append(contentsOf: spaces[start ..< end].map { .space(index: $0, isActive: $0 == activeSpaceIndex) })

        if end < spaces.count {
            tokens.append(.ellipsis)
        }

        return tokens
    }
}

// MARK: - Yabai Settings View

private struct YabaiSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Section {
            Picker("Style", selection: Binding(
                get: { appModel.spaceIndicatorStyle },
                set: { appModel.setSpaceIndicatorStyle($0) }
            )) {
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
            Picker("Label style", selection: Binding(
                get: { appModel.menuBarLabelMode },
                set: { appModel.setMenuBarLabelMode($0) }
            )) {
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
            Toggle("Show app names in the menu", isOn: Binding(
                get: { appModel.showAppNamesInMenu },
                set: { appModel.setShowAppNamesInMenu($0) }
            ))

            Picker("Apps shown per space", selection: Binding(
                get: { appModel.maxAppsShownPerSpace },
                set: { appModel.setMaxAppsShownPerSpace($0) }
            )) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .pickerStyle(.segmented)
            .disabled(!appModel.showAppNamesInMenu)

            Toggle("Group spaces by display", isOn: Binding(
                get: { appModel.groupSpacesByDisplay },
                set: { appModel.setGroupSpacesByDisplay($0) }
            ))
        } header: {
            Text("Menu Content")
        }

        Section {
            Button("Open yabairc") { appModel.openConfig() }
            Button("Open Yabai Folder") { appModel.openConfigDirectory() }
            Button("Refresh now") { appModel.refresh() }
        } header: {
            Text("Quick Actions")
        }

        Section {
            LabeledContent("Indicator surface") { Text(appModel.indicatorSurfaceMode.title) }
            LabeledContent("Runtime state") {
                Text(appModel.runtimeStatePath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            if let statusMessage = appModel.statusMessage, !statusMessage.isEmpty {
                LabeledContent("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Info")
        }
    }
}

// MARK: - SpaceRailToken (shared with views)

enum SpaceRailToken: Equatable {
    case ellipsis
    case space(index: Int, isActive: Bool)
}
