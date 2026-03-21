import Foundation

public struct YabaiClient: Sendable {
    private let runner: any CommandRunning
    private let yabaiExecutableURL: URL

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        yabaiExecutableURL: URL? = nil
    ) {
        self.runner = runner
        self.yabaiExecutableURL = yabaiExecutableURL ?? Self.defaultExecutableURL()
    }

    public func fetchSnapshot() throws -> YabaiSnapshot {
        let spacesOutput = try run(arguments: ["-m", "query", "--spaces"])
        let windowsOutput = try run(arguments: ["-m", "query", "--windows"])
        let displaysOutput = try run(arguments: ["-m", "query", "--displays"])
        return try YabaiSnapshotBuilder.build(
            spacesData: spacesOutput.stdout,
            windowsData: windowsOutput.stdout,
            displaysData: displaysOutput.stdout,
            focusedWindowData: try? run(arguments: ["-m", "query", "--windows", "--window"]).stdout
        )
    }

    public func fetchDiagnosticsSnapshot() throws -> YabaiDiagnosticsSnapshot {
        let spacesOutput = try run(arguments: ["-m", "query", "--spaces"])
        let windowsOutput = try run(arguments: ["-m", "query", "--windows"])
        let displaysOutput = try run(arguments: ["-m", "query", "--displays"])
        return try YabaiDiagnosticsBuilder.build(
            spacesData: spacesOutput.stdout,
            windowsData: windowsOutput.stdout,
            displaysData: displaysOutput.stdout,
            focusedWindowData: try? run(arguments: ["-m", "query", "--windows", "--window"]).stdout
        )
    }

    public func fetchActiveSpaceIndex() throws -> Int? {
        let spacesOutput = try run(arguments: ["-m", "query", "--spaces"])
        return try YabaiSnapshotBuilder.activeSpaceIndex(from: spacesOutput.stdout)
    }

    public func fetchActiveStackSummary() throws -> ActiveStackSummary? {
        let spaceOutput = try run(arguments: ["-m", "query", "--spaces", "--space"])
        let windowsOutput = try run(arguments: ["-m", "query", "--windows", "--space"])
        return try YabaiSnapshotBuilder.activeStackSummary(
            from: spaceOutput.stdout,
            windowsData: windowsOutput.stdout,
            focusedWindowData: try? run(arguments: ["-m", "query", "--windows", "--window"]).stdout
        )
    }

    public func fetchActiveDisplayUUID() throws -> String? {
        let displaysOutput = try run(arguments: ["-m", "query", "--displays"])
        return try YabaiSnapshotBuilder.activeDisplayUUID(from: displaysOutput.stdout)
    }

    public func fetchDisplaysData() throws -> Data {
        try run(arguments: ["-m", "query", "--displays"]).stdout
    }

    public func fetchSpaceData(index: Int) throws -> Data {
        try run(arguments: ["-m", "query", "--spaces", "--space", String(index)]).stdout
    }

    public func fetchWindowsData(spaceIndex: Int) throws -> Data {
        try run(arguments: ["-m", "query", "--windows", "--space", String(spaceIndex)]).stdout
    }

    public func fetchWindowData(id: Int) throws -> Data {
        try run(arguments: ["-m", "query", "--windows", "--window", String(id)]).stdout
    }

    public func fetchFocusedWindowData() throws -> Data {
        try run(arguments: ["-m", "query", "--windows", "--window"]).stdout
    }

    public func focusSpace(index: Int) throws {
        _ = try run(arguments: ["-m", "space", "--focus", String(index)])
    }

    public func focusWindow(id: Int) throws {
        _ = try run(arguments: ["-m", "window", "--focus", String(id)])
    }

    public func restartService() throws {
        _ = try run(arguments: ["--restart-service"])
    }

    public static func defaultExecutableURL() -> URL {
        let candidates = [
            "/opt/homebrew/bin/yabai",
            "/usr/local/bin/yabai",
        ]

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return URL(fileURLWithPath: candidates[0])
    }

    private func run(arguments: [String]) throws -> CommandOutput {
        let output = try runner.run(executableURL: yabaiExecutableURL, arguments: arguments)

        if output.exitCode != 0 {
            throw YabaiClientError.commandFailed(
                command: ([yabaiExecutableURL.path] + arguments).joined(separator: " "),
                stderr: output.stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return output
    }
}

public enum YabaiClientError: LocalizedError {
    case commandFailed(command: String, stderr: String)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(command, stderr):
            if stderr.isEmpty {
                return "Command failed: \(command)"
            }

            return stderr
        }
    }
}
