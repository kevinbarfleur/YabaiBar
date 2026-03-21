import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingModel: AppModel?
    private var statusItemController: StatusItemController?
    private var notchSurfaceCoordinator: NotchSurfaceCoordinator?
    private var settingsWindowController: SettingsWindowController?
    private var didFinishLaunching = false

    func configure(model: AppModel) {
        pendingModel = model
        installControllersIfPossible()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching = true
        NSApp.setActivationPolicy(.accessory)
        installControllersIfPossible()
    }

    private func installControllersIfPossible() {
        guard didFinishLaunching else { return }
        guard statusItemController == nil else { return }
        guard let model = pendingModel else { return }

        statusItemController = StatusItemController(model: model)
        notchSurfaceCoordinator = NotchSurfaceCoordinator(model: model)
        settingsWindowController = SettingsWindowController(model: model)
        model.setOpenSettingsHandler { [weak self] in
            self?.settingsWindowController?.show()
        }
    }
}
