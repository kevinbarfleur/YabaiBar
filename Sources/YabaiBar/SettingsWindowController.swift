import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: AppModel
    private var hasCenteredWindow = false
    private var hostingView: NSHostingView<SettingsView>?

    init(model: AppModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        setupWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setupWindow() {
        guard let window else { return }

        window.title = "YabaiBar Settings"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier("YabaiBarSettingsWindow")
        window.setContentSize(NSSize(width: 700, height: 560))
        window.minSize = NSSize(width: 660, height: 520)
        window.setFrameAutosaveName("YabaiBarSettingsWindow")
        window.delegate = self
        let hostingView = NSHostingView(rootView: SettingsView(model: model))
        self.hostingView = hostingView
        window.contentView = hostingView
    }

    func show() {
        guard let window else { return }

        if let hostingView {
            hostingView.rootView = SettingsView(model: model)
        }

        NSApp.setActivationPolicy(.regular)

        if !hasCenteredWindow {
            window.center()
            hasCenteredWindow = true
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak window] in
            window?.makeKeyAndOrderFront(nil)
        }
    }

    override func close() {
        super.close()
        relinquishFocus()
    }

    private func relinquishFocus() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        relinquishFocus()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
