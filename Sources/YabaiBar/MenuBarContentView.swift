import SwiftUI
import YabaiBarCore

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.isUnavailable, model.snapshot == nil {
                unavailableView
            } else {
                spacesMenu
            }
        }
        .onAppear {
            model.menuOpened()
        }
    }

    private var unavailableView: some View {
        Group {
            Text("Yabai unavailable")
            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.caption)
            }

            Divider()
            utilityButtons
        }
    }

    private var spacesMenu: some View {
        Group {
            statusSection

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.caption)
            }

            ForEach(model.groupedSpaces, id: \.display) { group in
                Section("Display \(group.display)") {
                    ForEach(group.spaces) { space in
                        Button {
                            model.focusSpace(space.index)
                        } label: {
                            Label {
                                Text("Space \(space.index) · \(space.appSummary)")
                            } icon: {
                                Image(systemName: space.hasFocus ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            }

            if model.groupedSpaces.isEmpty {
                Text("No spaces found")
            }

            Divider()
            utilityButtons
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if model.canMoveToApplications {
            Button("Install in Applications") {
                model.installInApplications()
            }

            Text(model.installationState.statusText)
                .font(.caption)

            Divider()
        }

        Text(model.loginItemState.statusText)
            .font(.caption)

        if model.needsLoginApproval {
            Button("Open Login Items Settings") {
                model.openLoginItemsSettings()
            }
        }

        if model.canMoveToApplications || model.needsLoginApproval {
            Divider()
        }
    }

    private var utilityButtons: some View {
        Group {
            Button("Open yabairc") {
                model.openConfig()
            }

            Button("Open Yabai Folder") {
                model.openConfigDirectory()
            }

            Button("Refresh") {
                model.refresh()
            }

            Divider()

            Button("Quit") {
                model.quit()
            }
        }
    }
}
