import Darwin
import Foundation

public enum YabaiSignalHandlerError: LocalizedError {
    case unsupportedInvocation
    case invalidSignalName(String)
    case missingWindowID
    case lockUnavailable
    case runtimeDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedInvocation:
            return "Unsupported VibeNotch signal invocation"
        case let .invalidSignalName(signalName):
            return "Unknown signal name: \(signalName)"
        case .missingWindowID:
            return "Missing YABAI_WINDOW_ID"
        case .lockUnavailable:
            return "Could not acquire VibeNotch runtime lock"
        case .runtimeDirectoryUnavailable:
            return "Could not create the VibeNotch runtime directory"
        }
    }
}

public enum YabaiSignalName: String, Codable, Sendable {
    case bootstrap
    case spaceChanged = "space_changed"
    case windowFocused = "window_focused"
    case windowCreated = "window_created"
    case windowDestroyed = "window_destroyed"
    case windowMoved = "window_moved"
    case windowMinimized = "window_minimized"
    case windowDeminimized = "window_deminimized"
    case applicationTerminated = "application_terminated"
}

private struct PendingYabaiEvent: Codable, Equatable, Sendable {
    let id: UUID
    let signal: YabaiSignalName
    let spaceIndex: Int?
    let windowID: Int?
    let createdAt: Date
}

public struct YabaiSignalHandler: Sendable {
    private let environment: [String: String]
    private let client: YabaiClient
    private let runtimeDirectoryURL: URL
    private let stateURL: URL
    private let lockURL: URL
    private let pendingEventURL: URL
    private let dateProvider: @Sendable () -> Date

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        client: YabaiClient? = nil,
        runtimeDirectoryURL: URL? = nil,
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.environment = environment

        let resolvedRuntimeDirectoryURL = runtimeDirectoryURL ?? Self.defaultRuntimeDirectoryURL()
        self.runtimeDirectoryURL = resolvedRuntimeDirectoryURL
        stateURL = resolvedRuntimeDirectoryURL.appendingPathComponent("state.json", isDirectory: false)
        lockURL = resolvedRuntimeDirectoryURL.appendingPathComponent(".lock", isDirectory: false)
        pendingEventURL = resolvedRuntimeDirectoryURL.appendingPathComponent("pending-event.json", isDirectory: false)
        self.dateProvider = dateProvider

        if let client {
            self.client = client
        } else {
            let yabaiPath = environment["YABAIBAR_YABAI_PATH"].map(URL.init(fileURLWithPath:))
            self.client = YabaiClient(yabaiExecutableURL: yabaiPath)
        }
    }

    public static func runIfNeeded(arguments: [String]) -> Int32? {
        guard arguments.count >= 3, arguments[1] == "--signal" else {
            return nil
        }

        let signalName = arguments[2]

        do {
            let signal = try parseSignal(named: signalName)
            let handler = YabaiSignalHandler()
            try handler.handle(signal)
            return 0
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    public func handle(_ signal: YabaiSignalName) throws {
        guard createRuntimeDirectoryIfNeeded() else {
            throw YabaiSignalHandlerError.runtimeDirectoryUnavailable
        }

        try savePendingEvent(capturedEvent(for: signal))
        try processPendingEventsIfPossible()
    }

    private func loadState() throws -> YabaiLiveState {
        try YabaiLiveStateStore.load(from: stateURL) ?? YabaiLiveState()
    }

    private func save(_ state: YabaiLiveState) throws {
        try YabaiLiveStateStore.save(state, to: stateURL)
    }

    private func loadPendingEvent() throws -> PendingYabaiEvent? {
        guard FileManager.default.fileExists(atPath: pendingEventURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: pendingEventURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PendingYabaiEvent.self, from: data)
    }

    private func savePendingEvent(_ event: PendingYabaiEvent) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        try data.write(to: pendingEventURL, options: .atomic)
    }

    private func removePendingEventIfUnchanged(id: UUID) throws {
        guard let currentEvent = try loadPendingEvent(), currentEvent.id == id else {
            return
        }

        try? FileManager.default.removeItem(at: pendingEventURL)
    }

    private func capturedEvent(for signal: YabaiSignalName) -> PendingYabaiEvent {
        PendingYabaiEvent(
            id: UUID(),
            signal: signal,
            spaceIndex: spaceIndexFromEnvironment(),
            windowID: windowIDFromEnvironment(),
            createdAt: dateProvider()
        )
    }

    private func processPendingEventsIfPossible() throws {
        _ = try withExclusiveLock(nonBlocking: true) {
            while let event = try loadPendingEvent() {
                var state = try loadState()
                state = try reduce(state, for: event)
                try save(state)
                try removePendingEventIfUnchanged(id: event.id)
            }
        }
    }

    private func reduce(_ state: YabaiLiveState, for event: PendingYabaiEvent) throws -> YabaiLiveState {
        switch event.signal {
        case .bootstrap:
            return try refreshActiveSpace(in: state, allowRememberedWindow: false)
        case .spaceChanged:
            guard let spaceIndex = event.spaceIndex else {
                return YabaiLiveStateReducer.spaceChanged(
                    nil,
                    activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
                    in: state,
                    now: dateProvider()
                )
            }

            return try reconcileSpaceChange(spaceIndex: spaceIndex, in: state)
        case .windowFocused:
            guard let windowID = event.windowID else {
                throw YabaiSignalHandlerError.missingWindowID
            }

            return try refreshFocusedWindow(windowID: windowID, in: state)
        case .windowCreated, .windowDestroyed, .windowMoved, .windowMinimized, .windowDeminimized, .applicationTerminated:
            return try refreshActiveSpace(in: state)
        }
    }

    private func reconcileSpaceChange(spaceIndex: Int, in state: YabaiLiveState) throws -> YabaiLiveState {
        var latestState = YabaiLiveStateReducer.spaceChanged(
            spaceIndex,
            activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
            in: state,
            now: dateProvider()
        )

        for attempt in 0..<8 {
            let activeSpaceIndex = try client.fetchActiveSpaceIndex()
            guard activeSpaceIndex == spaceIndex else {
                if attempt == 7 {
                    return latestState
                }

                usleep(50_000)
                continue
            }

            latestState = YabaiLiveStateReducer.spaceChanged(
                spaceIndex,
                activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
                in: latestState,
                now: dateProvider()
            )

            let preferredWindowData = currentFocusedWindowData(for: spaceIndex)
            latestState = try refreshSpace(
                index: spaceIndex,
                preferredWindowData: preferredWindowData,
                in: latestState
            )

            if latestState.spaces[spaceIndex] != nil || attempt == 7 {
                return latestState
            }

            usleep(50_000)
        }

        return latestState
    }

    private func refreshFocusedWindow(windowID: Int, in state: YabaiLiveState) throws -> YabaiLiveState {
        for attempt in 0..<6 {
            do {
                let windowData = try client.fetchWindowData(id: windowID)
                let window = try YabaiSignalDecoding.decodeWindow(from: windowData)
                let updatedState = try refreshSpace(
                    index: window.space,
                    preferredWindowData: windowData,
                    in: YabaiLiveStateReducer.spaceChanged(
                        window.space,
                        activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
                        in: state,
                        now: dateProvider()
                    )
                )
                return updatedState
            } catch {
                if attempt == 5 {
                    throw error
                }

                usleep(50_000)
            }
        }

        return state
    }

    private func refreshActiveSpace(in state: YabaiLiveState, allowRememberedWindow: Bool = true) throws -> YabaiLiveState {
        guard let activeSpaceIndex = try client.fetchActiveSpaceIndex() else {
            return YabaiLiveStateReducer.spaceChanged(
                nil,
                activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
                in: state,
                now: dateProvider()
            )
        }

        return try refreshSpace(
            index: activeSpaceIndex,
            preferredWindowData: preferredWindowData(for: activeSpaceIndex, in: state, allowRememberedWindow: allowRememberedWindow),
            in: YabaiLiveStateReducer.spaceChanged(
                activeSpaceIndex,
                activeDisplayUUID: try? client.fetchActiveDisplayUUID(),
                in: state,
                now: dateProvider()
            )
        )
    }

    private func refreshSpace(index: Int, preferredWindowData: Data?, in state: YabaiLiveState) throws -> YabaiLiveState {
        let spaceData = try client.fetchSpaceData(index: index)
        let windowsData = try client.fetchWindowsData(spaceIndex: index)

        let summary = try YabaiSnapshotBuilder.activeStackSummary(
            from: spaceData,
            windowsData: windowsData,
            focusedWindowData: preferredWindowData
        )

        return YabaiLiveStateReducer.trackedStackChanged(
            for: index,
            summary: summary,
            activeSpaceIndex: state.activeSpaceIndex,
            in: state,
            now: dateProvider()
        )
    }

    private func currentFocusedWindowData(for spaceIndex: Int) -> Data? {
        if let focusedWindowData = try? client.fetchFocusedWindowData(),
           let window = try? YabaiSignalDecoding.decodeWindow(from: focusedWindowData),
           window.space == spaceIndex,
           !window.isHidden,
           !window.isMinimized,
           !window.isFloating {
            return focusedWindowData
        }

        return nil
    }

    private func preferredWindowData(for spaceIndex: Int, in state: YabaiLiveState, allowRememberedWindow: Bool) -> Data? {
        if allowRememberedWindow,
           let focusedWindowID = state.spaces[spaceIndex]?.focusedWindowID,
           let windowData = try? client.fetchWindowData(id: focusedWindowID),
           let window = try? YabaiSignalDecoding.decodeWindow(from: windowData),
           window.space == spaceIndex,
           !window.isHidden,
           !window.isMinimized,
           !window.isFloating {
            return windowData
        }

        return currentFocusedWindowData(for: spaceIndex)
    }

    private func spaceIndexFromEnvironment() -> Int? {
        environment["YABAI_SPACE_INDEX"].flatMap(Int.init)
    }

    private func windowIDFromEnvironment() -> Int? {
        environment["YABAI_WINDOW_ID"].flatMap(Int.init)
    }

    private func withExclusiveLock<T>(nonBlocking: Bool = false, _ body: () throws -> T) throws -> T? {
        let fileDescriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            throw YabaiSignalHandlerError.lockUnavailable
        }

        defer {
            flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
        }

        let flags = nonBlocking ? LOCK_EX | LOCK_NB : LOCK_EX
        guard flock(fileDescriptor, flags) == 0 else {
            if nonBlocking, errno == EWOULDBLOCK {
                return nil
            }

            throw YabaiSignalHandlerError.lockUnavailable
        }

        return try body()
    }

    private func createRuntimeDirectoryIfNeeded() -> Bool {
        do {
            try FileManager.default.createDirectory(at: runtimeDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    private static func defaultRuntimeDirectoryURL() -> URL {
        if let configuredRuntimeDirectory = ProcessInfo.processInfo.environment["YABAIBAR_RUNTIME_DIR"] {
            return URL(fileURLWithPath: configuredRuntimeDirectory, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("VibeNotch", isDirectory: true)
            .appendingPathComponent("runtime", isDirectory: true)
    }

    private static func parseSignal(named signalName: String) throws -> YabaiSignalName {
        guard let signal = YabaiSignalName(rawValue: signalName) else {
            throw YabaiSignalHandlerError.invalidSignalName(signalName)
        }

        return signal
    }
}

public enum YabaiSignalDecoding {
    public static func decodeWindow(from data: Data) throws -> RawWindow {
        try JSONDecoder().decode(RawWindow.self, from: data)
    }
}
