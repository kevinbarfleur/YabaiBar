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
        return try YabaiSnapshotBuilder.build(
            spacesData: spacesOutput.stdout,
            windowsData: windowsOutput.stdout
        )
    }

    public func fetchActiveSpaceIndex() throws -> Int? {
        let spacesOutput = try run(arguments: ["-m", "query", "--spaces"])
        return try YabaiSnapshotBuilder.activeSpaceIndex(from: spacesOutput.stdout)
    }

    public func focusSpace(index: Int) throws {
        _ = try run(arguments: ["-m", "space", "--focus", String(index)])
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
