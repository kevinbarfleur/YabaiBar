import Foundation

public struct CommandOutput: Equatable, Sendable {
    public let stdout: Data
    public let stderr: Data
    public let exitCode: Int32

    public init(stdout: Data, stderr: Data, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }

    public var stdoutString: String {
        String(decoding: stdout, as: UTF8.self)
    }

    public var stderrString: String {
        String(decoding: stderr, as: UTF8.self)
    }
}

public protocol CommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) throws -> CommandOutput
}

private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        let value = storage
        lock.unlock()
        return value
    }
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(executableURL: URL, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutAccumulator = DataAccumulator()
        let stderrAccumulator = DataAccumulator()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }

            stdoutAccumulator.append(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }

            stderrAccumulator.append(data)
        }

        try process.run()
        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStdout.isEmpty {
            stdoutAccumulator.append(remainingStdout)
        }

        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStderr.isEmpty {
            stderrAccumulator.append(remainingStderr)
        }

        return CommandOutput(
            stdout: stdoutAccumulator.data,
            stderr: stderrAccumulator.data,
            exitCode: process.terminationStatus
        )
    }
}
