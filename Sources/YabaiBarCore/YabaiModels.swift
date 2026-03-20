import Foundation

public struct YabaiSnapshot: Equatable, Sendable {
    public let spaces: [SpaceSummary]
    public let activeStackSummary: ActiveStackSummary?

    public init(spaces: [SpaceSummary], activeStackSummary: ActiveStackSummary? = nil) {
        self.spaces = spaces
        self.activeStackSummary = activeStackSummary
    }

    public var activeSpaceIndex: Int? {
        spaces.first(where: \.hasFocus)?.index
    }
}

public struct ActiveStackSummary: Codable, Equatable, Sendable {
    public let spaceIndex: Int
    public let currentIndex: Int
    public let total: Int
    public let focusedWindowID: Int
    public let focusedAppName: String?

    public init(spaceIndex: Int, currentIndex: Int, total: Int, focusedWindowID: Int, focusedAppName: String?) {
        self.spaceIndex = spaceIndex
        self.currentIndex = currentIndex
        self.total = total
        self.focusedWindowID = focusedWindowID
        self.focusedAppName = focusedAppName
    }

    public var badgeLabel: String {
        "\(currentIndex)/\(total)"
    }
}

public struct SpaceSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let index: Int
    public let display: Int
    public let hasFocus: Bool
    public let isVisible: Bool
    public let apps: [String]

    public init(index: Int, display: Int, hasFocus: Bool, isVisible: Bool, apps: [String]) {
        id = index
        self.index = index
        self.display = display
        self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.apps = apps
    }

    public var appSummary: String {
        appSummary(maxApps: 2)
    }

    public func appSummary(maxApps: Int = 2) -> String {
        if apps.isEmpty {
            return "No windows"
        }

        let maximumApps = max(1, maxApps)
        let displayedApps = Array(apps.prefix(maximumApps))
        if apps.count <= maximumApps {
            return displayedApps.joined(separator: ", ")
        }

        return "\(displayedApps.joined(separator: ", ")) +\(apps.count - maximumApps)"
    }
}

public struct RawSpace: Decodable, Equatable, Sendable {
    public let index: Int
    public let type: String?
    public let display: Int
    public let windows: [Int]?
    public let firstWindow: Int?
    public let hasFocus: Bool
    public let isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case index
        case type
        case display
        case windows
        case firstWindow = "first-window"
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
    }
}

public struct RawWindow: Decodable, Equatable, Sendable {
    public let id: Int
    public let app: String
    public let space: Int
    public let stackIndex: Int?
    public let hasFocus: Bool
    public let isHidden: Bool
    public let isMinimized: Bool
    public let isFloating: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case app
        case space
        case stackIndex = "stack-index"
        case hasFocus = "has-focus"
        case isHidden = "is-hidden"
        case isMinimized = "is-minimized"
        case isFloating = "is-floating"
    }
}

public enum YabaiSnapshotBuilder {
    public static func build(spacesData: Data, windowsData: Data, focusedWindowData: Data? = nil) throws -> YabaiSnapshot {
        let decoder = JSONDecoder()
        let rawSpaces = try decoder.decode([RawSpace].self, from: spacesData)
        let rawWindows = try decoder.decode([RawWindow].self, from: windowsData)

        let appsBySpace = Dictionary(grouping: rawWindows.filter { !$0.isHidden && !$0.isMinimized }, by: \.space)
            .mapValues { windows in
                Array(Set(windows.map(\.app))).sorted()
            }

        let spaces = rawSpaces
            .map { space in
                SpaceSummary(
                    index: space.index,
                    display: space.display,
                    hasFocus: space.hasFocus,
                    isVisible: space.isVisible,
                    apps: appsBySpace[space.index, default: []]
                )
            }
            .sorted { lhs, rhs in
                if lhs.display == rhs.display {
                    return lhs.index < rhs.index
                }

                return lhs.display < rhs.display
            }

        return YabaiSnapshot(
            spaces: spaces,
            activeStackSummary: try activeStackSummary(
                activeSpace: rawSpaces.first(where: \.hasFocus),
                rawWindows: rawWindows,
                focusedWindowData: focusedWindowData
            )
        )
    }

    public static func activeSpaceIndex(from spacesData: Data) throws -> Int? {
        let rawSpaces = try JSONDecoder().decode([RawSpace].self, from: spacesData)
        return rawSpaces.first(where: \.hasFocus)?.index
    }

    public static func activeStackSummary(from spaceData: Data, windowsData: Data, focusedWindowData: Data? = nil) throws -> ActiveStackSummary? {
        guard !spaceData.isEmpty else {
            return nil
        }

        let decoder = JSONDecoder()
        let rawSpace = try decoder.decode(RawSpace.self, from: spaceData)
        let rawWindows = try decoder.decode([RawWindow].self, from: windowsData)
        return try activeStackSummary(activeSpace: rawSpace, rawWindows: rawWindows, focusedWindowData: focusedWindowData)
    }

    private static func activeStackSummary(activeSpace: RawSpace?, rawWindows: [RawWindow], focusedWindowData: Data?) throws -> ActiveStackSummary? {
        let focusedWindow = try decodeFocusedWindow(from: focusedWindowData)
            ?? rawWindows.first(where: \.hasFocus)
            ?? focusedWindowFromSpaceOrdering(activeSpace: activeSpace, rawWindows: rawWindows)
        return stackSummary(for: focusedWindow, activeSpace: activeSpace, rawWindows: rawWindows)
    }

    private static func decodeFocusedWindow(from focusedWindowData: Data?) throws -> RawWindow? {
        guard let focusedWindowData, !focusedWindowData.isEmpty else {
            return nil
        }

        return try JSONDecoder().decode(RawWindow.self, from: focusedWindowData)
    }

    private static func focusedWindowFromSpaceOrdering(activeSpace: RawSpace?, rawWindows: [RawWindow]) -> RawWindow? {
        guard let activeSpace else {
            return nil
        }

        let windowsByID = Dictionary(uniqueKeysWithValues: rawWindows.map { ($0.id, $0) })

        if let orderedWindowIDs = activeSpace.windows {
            for windowID in orderedWindowIDs {
                guard let window = windowsByID[windowID] else {
                    continue
                }

                if !window.isHidden, !window.isMinimized, !window.isFloating {
                    return window
                }
            }
        }

        if let firstWindowID = activeSpace.firstWindow,
           let firstWindow = windowsByID[firstWindowID],
           !firstWindow.isHidden,
           !firstWindow.isMinimized,
           !firstWindow.isFloating {
            return firstWindow
        }

        return nil
    }

    private static func stackSummary(for focusedWindow: RawWindow?, activeSpace: RawSpace?, rawWindows: [RawWindow]) -> ActiveStackSummary? {
        guard let activeSpace, activeSpace.type == "stack" else {
            return nil
        }

        let stackWindows = rawWindows
            .filter { window in
                window.space == activeSpace.index && !window.isHidden && !window.isMinimized && !window.isFloating
            }
            .sorted { lhs, rhs in
                switch (lhs.stackIndex, rhs.stackIndex) {
                case let (left?, right?) where left != right:
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.id < rhs.id
                }
            }

        guard stackWindows.count >= 2 else {
            return nil
        }

        guard let focusedWindow,
              focusedWindow.space == activeSpace.index,
              !focusedWindow.isHidden,
              !focusedWindow.isMinimized,
              !focusedWindow.isFloating else {
            return nil
        }

        guard let currentIndex = stackPosition(of: focusedWindow, in: stackWindows) else {
            return nil
        }

        return ActiveStackSummary(
            spaceIndex: activeSpace.index,
            currentIndex: currentIndex,
            total: stackWindows.count,
            focusedWindowID: focusedWindow.id,
            focusedAppName: focusedWindow.app
        )
    }

    private static func stackPosition(of focusedWindow: RawWindow, in stackWindows: [RawWindow]) -> Int? {
        let total = stackWindows.count

        if let normalizedIndex = normalizedStackIndex(of: focusedWindow, in: stackWindows), (1...total).contains(normalizedIndex) {
            return normalizedIndex
        }

        guard let focusedWindowIndex = stackWindows.firstIndex(where: { $0.id == focusedWindow.id }) else {
            return nil
        }

        return focusedWindowIndex + 1
    }

    private static func normalizedStackIndex(of focusedWindow: RawWindow, in stackWindows: [RawWindow]) -> Int? {
        guard let focusedStackIndex = focusedWindow.stackIndex else {
            return nil
        }

        let stackIndexes = stackWindows.compactMap(\.stackIndex)
        guard stackIndexes.count == stackWindows.count else {
            return nil
        }

        let sortedIndexes = stackIndexes.sorted()
        let total = stackWindows.count

        if sortedIndexes == Array(1...total) {
            return focusedStackIndex
        }

        if sortedIndexes == Array(0..<total) {
            return focusedStackIndex + 1
        }

        if (1...total).contains(focusedStackIndex) {
            return focusedStackIndex
        }

        if (0..<total).contains(focusedStackIndex) {
            return focusedStackIndex + 1
        }

        return nil
    }
}
