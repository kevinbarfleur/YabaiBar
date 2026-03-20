import AppKit
import Combine
import Foundation
import YabaiBarCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private var cancellables = Set<AnyCancellable>()
    private var isMenuOpen = false

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: 48)
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        bind()
        updateStatusItemButton()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        rebuildMenu()
        model.menuOpened()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func bind() {
        model.$activeSpaceIndex
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$activeStackSummary
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$snapshot
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$statusMessage
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$installationState
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$loginItemState
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$integrationState
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemButton() {
        guard let button = statusItem.button else { return }

        statusItem.length = statusItemLength()
        button.title = ""
        button.attributedTitle = attributedLabel(model.activeSpaceDisplayLabel)
        button.image = statusItemImage()
        button.imagePosition = .imageLeading
        button.toolTip = model.activeSpaceTooltip
    }

    private func rebuildMenuIfNeeded() {
        guard isMenuOpen else { return }
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if model.isUnavailable, model.snapshot == nil {
            menu.addItem(disabledItem("Yabai unavailable"))
            if let statusMessage = model.statusMessage {
                menu.addItem(disabledItem(statusMessage))
            }
            menu.addItem(.separator())
            addUtilityItems()
            return
        }

        addStatusItems()

        if let statusMessage = model.statusMessage {
            menu.addItem(disabledItem(statusMessage))
        }

        if let activeStackMenuLabel = model.activeStackMenuLabel {
            menu.addItem(disabledItem(activeStackMenuLabel))
            menu.addItem(.separator())
        }

        addSpaceItems()
        menu.addItem(.separator())
        addUtilityItems()
    }

    private func addStatusItems() {
        var addedStatusItem = false

        if model.canMoveToApplications {
            let installItem = NSMenuItem(title: "Install in Applications", action: #selector(installInApplications), keyEquivalent: "")
            installItem.target = self
            menu.addItem(installItem)
            menu.addItem(disabledItem(model.installationState.statusText))
            addedStatusItem = true
        }

        menu.addItem(disabledItem(model.loginItemState.statusText))
        addedStatusItem = true

        menu.addItem(disabledItem(model.integrationState.statusText))
        addedStatusItem = true

        if model.needsLoginApproval {
            let loginSettingsItem = NSMenuItem(title: "Open Login Items Settings", action: #selector(openLoginItemsSettings), keyEquivalent: "")
            loginSettingsItem.target = self
            menu.addItem(loginSettingsItem)
        }

        if model.canRepairIntegration {
            let repairIntegrationItem = NSMenuItem(title: "Repair Yabai Integration", action: #selector(repairIntegration), keyEquivalent: "")
            repairIntegrationItem.target = self
            menu.addItem(repairIntegrationItem)
        }

        if addedStatusItem {
            menu.addItem(.separator())
        }
    }

    private func addSpaceItems() {
        if model.spaces.isEmpty {
            menu.addItem(disabledItem("No spaces found"))
            return
        }

        for (offset, group) in model.groupedSpaces.enumerated() {
            if offset > 0 {
                menu.addItem(.separator())
            }

            menu.addItem(disabledItem("Display \(group.display)"))
            group.spaces.forEach { space in
                menu.addItem(spaceItem(for: space))
            }
        }
    }

    private func addUtilityItems() {
        menu.addItem(actionItem("Open yabairc", action: #selector(openConfig)))
        menu.addItem(actionItem("Open Yabai Folder", action: #selector(openConfigDirectory)))
        menu.addItem(actionItem("Refresh", action: #selector(refresh)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit", action: #selector(quit)))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func spaceItem(for space: SpaceSummary) -> NSMenuItem {
        let item = NSMenuItem(title: "Space \(space.index) · \(space.appSummary)", action: #selector(focusSpace(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = space.index
        item.state = model.isSpaceFocused(space.index) ? .on : .off
        return item
    }

    private func attributedLabel(_ label: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        ]
        return NSAttributedString(string: label, attributes: attributes)
    }

    private func statusItemLength() -> CGFloat {
        let template = statusItemLabelTemplate()
        return attributedLabel(template).size().width + 22
    }

    private func statusItemLabelTemplate() -> String {
        guard let activeStackSummary = model.activeStackSummary else {
            return model.activeSpaceLabel
        }

        let digitCount = max(
            String(activeStackSummary.currentIndex).count,
            String(activeStackSummary.total).count
        )
        let digits = String(repeating: "9", count: digitCount)
        return "\(model.activeSpaceLabel) · \(digits)/\(digits)"
    }

    private func statusItemImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "square.3.layers.3d.top.filled", accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    @objc
    private func focusSpace(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        model.focusSpace(index)
    }

    @objc
    private func installInApplications() {
        model.installInApplications()
    }

    @objc
    private func openLoginItemsSettings() {
        model.openLoginItemsSettings()
    }

    @objc
    private func openConfig() {
        model.openConfig()
    }

    @objc
    private func openConfigDirectory() {
        model.openConfigDirectory()
    }

    @objc
    private func refresh() {
        model.refresh()
    }

    @objc
    private func repairIntegration() {
        model.repairIntegration()
    }

    @objc
    private func quit() {
        model.quit()
    }
}
