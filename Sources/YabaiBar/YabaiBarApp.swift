import AppKit
import SwiftUI

@main
struct YabaiBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let model: AppModel

    init() {
        let model = AppModel()
        model.startIfNeeded()
        self.model = model
        appDelegate.configure(model: model)
    }

    var body: some Scene {
        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
        }
    }
}
