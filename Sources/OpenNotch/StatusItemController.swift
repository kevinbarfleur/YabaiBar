import AppKit
import Combine
import Foundation
import OpenNotchCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private var cancellables = Set<AnyCancellable>()
    private var isMenuOpen = false

    init(model: AppModel) {
        self.model = model
        super.init()

        menu.delegate = self

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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$activeStackSummary
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$indicatorSurfaceMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
                self?.rebuildMenuIfNeeded()
            }
            .store(in: &cancellables)

        model.$menuBarLabelMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemButton()
            }
            .store(in: &cancellables)

        model.moduleRegistry.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItemButton()
                    self?.rebuildMenuIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemButton() {
        syncStatusItemVisibility()
        guard let statusItem,
              let button = statusItem.button else { return }

        let activeModule = model.moduleRegistry.activeStatusBarModule
        let content = activeModule?.statusBarContent()

        if model.shouldShowIconOnlyInStatusItem {
            statusItem.length = NSStatusItem.squareLength
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = content?.icon ?? defaultStatusItemImage()
            button.imagePosition = .imageOnly
            button.toolTip = content?.tooltip ?? "OpenNotch"
            return
        }

        if let content, model.shouldShowTextInStatusItem {
            statusItem.length = content.length > 0 ? content.length : NSStatusItem.squareLength
            button.title = ""
            button.attributedTitle = attributedLabel(content.label ?? "")
            button.image = model.shouldShowImageInStatusItem ? (content.icon ?? defaultStatusItemImage()) : nil
            button.imagePosition = model.shouldShowImageInStatusItem ? .imageLeading : .noImage
            button.toolTip = content.tooltip ?? "OpenNotch"
        } else {
            statusItem.length = NSStatusItem.squareLength
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = defaultStatusItemImage()
            button.imagePosition = .imageOnly
            button.toolTip = "OpenNotch"
        }
    }

    private func syncStatusItemVisibility() {
        if model.shouldShowStatusItem || model.indicatorSurfaceMode == .notch {
            ensureStatusItem()
        } else {
            removeStatusItem()
        }
    }

    private func ensureStatusItem() {
        guard statusItem == nil else { return }

        let statusItem = NSStatusBar.system.statusItem(withLength: 48)
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func removeStatusItem() {
        guard let statusItem else { return }

        if isMenuOpen {
            menu.cancelTracking()
            isMenuOpen = false
        }

        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func rebuildMenuIfNeeded() {
        guard isMenuOpen else { return }
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // Core status items
        addCoreStatusItems()

        // Module sections
        let enabledModules = model.moduleRegistry.enabledModules
        for module in enabledModules {
            let sections = module.menuSections()
            guard !sections.isEmpty else { continue }

            menu.addItem(.separator())
            let headerItem = NSMenuItem(title: module.displayName, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            headerItem.attributedTitle = NSAttributedString(string: module.displayName.uppercased(), attributes: attrs)
            menu.addItem(headerItem)

            for section in sections {
                for item in section.items {
                    menu.addItem(item)
                }
            }
        }

        // Utility items
        menu.addItem(.separator())
        addUtilityItems()
    }

    private func addCoreStatusItems() {
        if model.canMoveToApplications {
            let installItem = NSMenuItem(title: "Install in Applications", action: #selector(installInApplications), keyEquivalent: "")
            installItem.target = self
            menu.addItem(installItem)
        }

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
    }

    private func addUtilityItems() {
        let settingsItem = actionItem("Settings…", action: #selector(openSettings))
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
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

    private func attributedLabel(_ label: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        ]
        return NSAttributedString(string: label, attributes: attributes)
    }

    private func defaultStatusItemImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "square.3.layers.3d.top.filled", accessibilityDescription: nil)
        image?.isTemplate = true
        return image
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
    private func refresh() {
        model.moduleRegistry.refreshAll()
    }

    @objc
    private func openSettings() {
        model.openSettings()
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
