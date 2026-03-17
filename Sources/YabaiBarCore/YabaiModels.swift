import Foundation

public struct YabaiSnapshot: Equatable, Sendable {
    public let spaces: [SpaceSummary]

    public init(spaces: [SpaceSummary]) {
        self.spaces = spaces
    }

    public var activeSpaceIndex: Int? {
        spaces.first(where: \.hasFocus)?.index
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
        if apps.isEmpty {
            return "No windows"
        }

        let displayedApps = Array(apps.prefix(2))
        if apps.count <= 2 {
            return displayedApps.joined(separator: ", ")
        }

        return "\(displayedApps.joined(separator: ", ")) +\(apps.count - 2)"
    }
}

struct RawSpace: Decodable {
    let index: Int
    let display: Int
    let hasFocus: Bool
    let isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case index
        case display
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
    }
}

struct RawWindow: Decodable {
    let id: Int
    let app: String
    let space: Int
    let isHidden: Bool
    let isMinimized: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case app
        case space
        case isHidden = "is-hidden"
        case isMinimized = "is-minimized"
    }
}

public enum YabaiSnapshotBuilder {
    public static func build(spacesData: Data, windowsData: Data) throws -> YabaiSnapshot {
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

        return YabaiSnapshot(spaces: spaces)
    }

    public static func activeSpaceIndex(from spacesData: Data) throws -> Int? {
        let rawSpaces = try JSONDecoder().decode([RawSpace].self, from: spacesData)
        return rawSpaces.first(where: \.hasFocus)?.index
    }
}
