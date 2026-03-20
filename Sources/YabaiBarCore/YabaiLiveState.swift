import Foundation

public struct TrackedStackState: Codable, Equatable, Sendable {
    public let spaceIndex: Int
    public let currentIndex: Int
    public let total: Int
    public let focusedWindowID: Int
    public let focusedAppName: String?
    public let updatedAt: Date

    public init(
        spaceIndex: Int,
        currentIndex: Int,
        total: Int,
        focusedWindowID: Int,
        focusedAppName: String?,
        updatedAt: Date
    ) {
        self.spaceIndex = spaceIndex
        self.currentIndex = currentIndex
        self.total = total
        self.focusedWindowID = focusedWindowID
        self.focusedAppName = focusedAppName
        self.updatedAt = updatedAt
    }

    public var activeStackSummary: ActiveStackSummary {
        ActiveStackSummary(
            spaceIndex: spaceIndex,
            currentIndex: currentIndex,
            total: total,
            focusedWindowID: focusedWindowID,
            focusedAppName: focusedAppName
        )
    }
}

public struct YabaiLiveState: Codable, Equatable, Sendable {
    public let version: Int
    public let activeSpaceIndex: Int?
    public let spaces: [Int: TrackedStackState]
    public let updatedAt: Date

    public init(
        version: Int = 1,
        activeSpaceIndex: Int? = nil,
        spaces: [Int: TrackedStackState] = [:],
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.activeSpaceIndex = activeSpaceIndex
        self.spaces = spaces
        self.updatedAt = updatedAt
    }

    public var activeStackSummary: ActiveStackSummary? {
        guard let activeSpaceIndex else {
            return nil
        }

        return spaces[activeSpaceIndex]?.activeStackSummary
    }
}

public enum YabaiLiveStateStore {
    public static func load(from url: URL) throws -> YabaiLiveState? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(YabaiLiveState.self, from: data)
    }

    public static func save(_ state: YabaiLiveState, to url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }
}

public enum YabaiLiveStateReducer {
    public static func spaceChanged(
        _ activeSpaceIndex: Int?,
        in state: YabaiLiveState,
        now: Date = Date()
    ) -> YabaiLiveState {
        YabaiLiveState(
            version: state.version,
            activeSpaceIndex: activeSpaceIndex,
            spaces: state.spaces,
            updatedAt: now
        )
    }

    public static func trackedStackChanged(
        for spaceIndex: Int,
        summary: ActiveStackSummary?,
        activeSpaceIndex: Int?,
        in state: YabaiLiveState,
        now: Date = Date()
    ) -> YabaiLiveState {
        var spaces = state.spaces

        if let summary {
            spaces[spaceIndex] = TrackedStackState(
                spaceIndex: summary.spaceIndex,
                currentIndex: summary.currentIndex,
                total: summary.total,
                focusedWindowID: summary.focusedWindowID,
                focusedAppName: summary.focusedAppName,
                updatedAt: now
            )
        } else {
            spaces.removeValue(forKey: spaceIndex)
        }

        return YabaiLiveState(
            version: state.version,
            activeSpaceIndex: activeSpaceIndex,
            spaces: spaces,
            updatedAt: now
        )
    }
}
