import Foundation
import OpenNotchCore

enum YabaiIntegrationState: Equatable, Sendable {
    case unavailable(String)
    case missing
    case outdated
    case installed
    case repairFailed(String)

    var statusText: String {
        switch self {
        case let .unavailable(message):
            return message
        case .missing:
            return "Yabai integration is off"
        case .outdated:
            return "Yabai integration needs repair"
        case .installed:
            return "Yabai integration is on"
        case let .repairFailed(message):
            return message
        }
    }

    var canRepair: Bool {
        switch self {
        case .missing, .outdated, .repairFailed:
            return true
        case .unavailable, .installed:
            return false
        }
    }
}

struct YabaiIntegrationManager: Sendable {
    let helperExecutableURL: URL
    let yabaiExecutableURL: URL
    let configFileURL: URL
    let runtimeDirectoryURL: URL

    init(
        helperExecutableURL: URL? = Bundle.main.resourceURL?.appendingPathComponent("YabaiBarSignalHelper", isDirectory: false),
        yabaiExecutableURL: URL = YabaiClient.defaultExecutableURL(),
        configFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("yabai", isDirectory: true)
            .appendingPathComponent("yabairc", isDirectory: false),
        runtimeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("OpenNotch", isDirectory: true)
            .appendingPathComponent("runtime", isDirectory: true)
    ) {
        self.helperExecutableURL = helperExecutableURL ?? URL(fileURLWithPath: "/Applications/OpenNotch.app/Contents/Resources/YabaiBarSignalHelper")
        self.yabaiExecutableURL = yabaiExecutableURL
        self.configFileURL = configFileURL
        self.runtimeDirectoryURL = runtimeDirectoryURL
    }

    var runtimeStateURL: URL {
        runtimeDirectoryURL.appendingPathComponent("state.json", isDirectory: false)
    }

    func state(isEligible: Bool) -> YabaiIntegrationState {
        guard isEligible else {
            return .unavailable("Install the app in Applications first")
        }

        guard FileManager.default.fileExists(atPath: helperExecutableURL.path) else {
            return .unavailable("Bundled Yabai helper not found")
        }

        let managedBlock = renderedManagedBlock()
        let contents = (try? String(contentsOf: configFileURL, encoding: .utf8)) ?? ""

        guard let existingBlock = YabaiIntegrationRenderer.managedBlock(in: contents) else {
            return .missing
        }

        return existingBlock == managedBlock ? .installed : .outdated
    }

    @discardableResult
    func ensureInstalled(isEligible: Bool) throws -> YabaiIntegrationState {
        guard isEligible else {
            return .unavailable("Install the app in Applications first")
        }

        try FileManager.default.createDirectory(
            at: configFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try FileManager.default.createDirectory(
            at: runtimeDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let managedBlock = renderedManagedBlock()
        let existingContents = (try? String(contentsOf: configFileURL, encoding: .utf8)) ?? ""
        let mergedContents = YabaiIntegrationRenderer.merge(managedBlock: managedBlock, into: existingContents)

        if mergedContents != existingContents {
            try mergedContents.write(to: configFileURL, atomically: true, encoding: .utf8)
            try YabaiClient(yabaiExecutableURL: yabaiExecutableURL).restartService()
        }

        try bootstrapRuntimeState()
        return .installed
    }

    func bootstrapRuntimeState() throws {
        let process = Process()
        process.executableURL = helperExecutableURL
        process.arguments = ["--signal", YabaiSignalName.bootstrap.rawValue]

        var environment = ProcessInfo.processInfo.environment
        environment["YABAIBAR_RUNTIME_DIR"] = runtimeDirectoryURL.path
        environment["YABAIBAR_YABAI_PATH"] = yabaiExecutableURL.path
        process.environment = environment

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw YabaiClientError.commandFailed(
                command: "\(helperExecutableURL.path) --signal \(YabaiSignalName.bootstrap.rawValue)",
                stderr: "Failed to bootstrap the YabaiBar runtime state."
            )
        }
    }

    private func renderedManagedBlock() -> String {
        YabaiIntegrationRenderer.render(
            executablePath: helperExecutableURL.path,
            runtimeDirectoryPath: runtimeDirectoryURL.path,
            yabaiExecutablePath: yabaiExecutableURL.path
        )
    }
}
