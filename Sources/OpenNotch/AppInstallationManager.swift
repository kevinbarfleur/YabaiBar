import AppKit
import Foundation

enum InstallationState: Equatable {
    case unsupported
    case installed
    case needsMove
    case moving
    case moveFailed(String)

    var statusText: String {
        switch self {
        case .unsupported:
            return "Installable app bundle not detected"
        case .installed:
            return "Installed in Applications"
        case .needsMove:
            return "Move to Applications to keep it permanently"
        case .moving:
            return "Installing in Applications..."
        case let .moveFailed(message):
            return message
        }
    }
}

enum AppInstallationError: LocalizedError {
    case notRunningFromAppBundle
    case destinationUnavailable

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "This build is not running from an app bundle."
        case .destinationUnavailable:
            return "Could not resolve an Applications folder."
        }
    }
}

@MainActor
final class AppInstallationManager {
    private let fileManager: FileManager
    private let workspace: NSWorkspace
    private let legacyLaunchAgentLabel = "com.kevinbarfleur.YabaiBar"

    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
    }

    var bundleURL: URL? {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        return bundleURL.pathExtension == "app" ? bundleURL : nil
    }

    var state: InstallationState {
        guard let bundleURL else {
            return .unsupported
        }

        if bundleURL.path.hasPrefix("/Applications/") || bundleURL.path.hasPrefix("\(NSHomeDirectory())/Applications/") {
            return .installed
        }

        return .needsMove
    }

    func promptForInstallationIfNeeded(installAction: @escaping () -> Void) {
        guard state == .needsMove else { return }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Install OpenNotch in Applications?"
        alert.informativeText = "Move the app to Applications so it can be launched reliably at login and keep working after Xcode or build folders change."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            installAction()
        }
    }

    func installAndRelaunch() throws {
        guard let sourceURL = bundleURL else {
            throw AppInstallationError.notRunningFromAppBundle
        }

        let destinationDirectory = try preferredApplicationsDirectory()
        let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: destinationURL, configuration: configuration) { _, error in
            if let error {
                NSLog("Failed to relaunch OpenNotch from Applications: \(error.localizedDescription)")
            }
        }
    }

    func removeLegacyLaunchAgentIfNeeded() {
        let launchAgentURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(legacyLaunchAgentLabel).plist", isDirectory: false)

        guard fileManager.fileExists(atPath: launchAgentURL.path) else {
            return
        }

        try? fileManager.removeItem(at: launchAgentURL)
    }

    private func preferredApplicationsDirectory() throws -> URL {
        let localApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if fileManager.isWritableFile(atPath: localApplications.path) {
            return localApplications
        }

        let userApplications = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        try fileManager.createDirectory(at: userApplications, withIntermediateDirectories: true)
        return userApplications
    }
}
