import AppKit
import SwiftUI

@main
struct YabaiBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        model.startIfNeeded()
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarLabelView(activeSpaceLabel: model.activeSpaceLabel)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
        }
    }
}
