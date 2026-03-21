import AppKit
import OpenNotchCore
import SwiftUI
import OpenNotchCore

@MainActor
final class YabaiModule: OpenNotchModule {
    let identifier = ModuleIdentifier("com.opennotch.yabai")
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
        let listHeight = CGFloat(listItemCount) * 30
        let estimatedHeight: CGFloat = 60 + listHeight

        return [
            NotchExpandedWidget(
                id: "yabai-space-detail",
                moduleID: identifier,
                estimatedHeight: estimatedHeight,
                content: AnyView(
                    YabaiExpandedContent(
                        state: state,
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
        nil
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

// MARK: - SpaceRailToken (shared with views)

enum SpaceRailToken: Equatable {
    case ellipsis
    case space(index: Int, isActive: Bool)
}
