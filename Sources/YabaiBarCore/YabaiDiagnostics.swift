import Foundation

public struct YabaiDiagnosticsSnapshot: Equatable, Sendable {
    public let displays: [DisplayDiagnosticSummary]
    public let activeDisplayUUID: String?
    public let activeSpaceIndex: Int?

    public init(
        displays: [DisplayDiagnosticSummary],
        activeDisplayUUID: String?,
        activeSpaceIndex: Int?
    ) {
        self.displays = displays
        self.activeDisplayUUID = activeDisplayUUID
        self.activeSpaceIndex = activeSpaceIndex
    }

    public var spaces: [SpaceDiagnosticSummary] {
        displays.flatMap(\.spaces)
    }
}

public struct DisplayDiagnosticSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let index: Int
    public let uuid: String?
    public let hasFocus: Bool
    public let spaces: [SpaceDiagnosticSummary]

    public init(index: Int, uuid: String?, hasFocus: Bool, spaces: [SpaceDiagnosticSummary]) {
        id = index
        self.index = index
        self.uuid = uuid
        self.hasFocus = hasFocus
        self.spaces = spaces
    }
}

public struct SpaceDiagnosticSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let index: Int
    public let display: Int
    public let type: String?
    public let hasFocus: Bool
    public let isVisible: Bool
    public let isNativeFullscreen: Bool
    public let liveStackSummary: ActiveStackSummary?
    public let windows: [WindowDiagnosticItem]

    public init(
        index: Int,
        display: Int,
        type: String?,
        hasFocus: Bool,
        isVisible: Bool,
        isNativeFullscreen: Bool,
        liveStackSummary: ActiveStackSummary?,
        windows: [WindowDiagnosticItem]
    ) {
        id = index
        self.index = index
        self.display = display
        self.type = type
        self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.isNativeFullscreen = isNativeFullscreen
        self.liveStackSummary = liveStackSummary
        self.windows = windows
    }

    public var isStack: Bool {
        type?.lowercased() == "stack"
    }

    public var countedStackWindowCount: Int {
        windows.filter(\.countsTowardStack).count
    }
}

public struct WindowDiagnosticItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let pid: Int
    public let app: String
    public let title: String
    public let stackIndex: Int?
    public let hasFocus: Bool
    public let isHidden: Bool
    public let isMinimized: Bool
    public let isFloating: Bool
    public let countsTowardStack: Bool
    public let countedPosition: Int?

    public init(
        id: Int,
        pid: Int,
        app: String,
        title: String,
        stackIndex: Int?,
        hasFocus: Bool,
        isHidden: Bool,
        isMinimized: Bool,
        isFloating: Bool,
        countsTowardStack: Bool,
        countedPosition: Int?
    ) {
        self.id = id
        self.pid = pid
        self.app = app
        self.title = title
        self.stackIndex = stackIndex
        self.hasFocus = hasFocus
        self.isHidden = isHidden
        self.isMinimized = isMinimized
        self.isFloating = isFloating
        self.countsTowardStack = countsTowardStack
        self.countedPosition = countedPosition
    }
}

public enum YabaiDiagnosticsBuilder {
    public static func build(
        spacesData: Data,
        windowsData: Data,
        displaysData: Data,
        focusedWindowData: Data? = nil
    ) throws -> YabaiDiagnosticsSnapshot {
        let decoder = JSONDecoder()
        let rawSpaces = try decoder.decode([RawSpace].self, from: spacesData)
        let rawWindows = try decoder.decode([RawWindow].self, from: windowsData)
        let rawDisplays = try decoder.decode([RawDisplay].self, from: displaysData)
        let focusedWindow = try decodeWindow(from: focusedWindowData)

        let spacesByDisplay = Dictionary(grouping: rawSpaces, by: \.display)
        let displays = rawDisplays
            .sorted(by: { $0.index < $1.index })
            .map { display in
                let spaces = (spacesByDisplay[display.index] ?? [])
                    .sorted(by: { $0.index < $1.index })
                    .map { space in
                        buildSpaceSummary(
                            from: space,
                            rawWindows: rawWindows,
                            focusedWindow: focusedWindow
                        )
                    }

                return DisplayDiagnosticSummary(
                    index: display.index,
                    uuid: display.uuid,
                    hasFocus: display.hasFocus,
                    spaces: spaces
                )
            }

        return YabaiDiagnosticsSnapshot(
            displays: displays,
            activeDisplayUUID: rawDisplays.first(where: \.hasFocus)?.uuid,
            activeSpaceIndex: rawSpaces.first(where: \.hasFocus)?.index
        )
    }

    private static func buildSpaceSummary(
        from rawSpace: RawSpace,
        rawWindows: [RawWindow],
        focusedWindow: RawWindow?
    ) -> SpaceDiagnosticSummary {
        let windowsForSpace = rawWindows
            .filter { $0.space == rawSpace.index }
            .sorted(by: diagnosticsWindowSort)

        let countedWindows = rawWindowsForStack(space: rawSpace, rawWindows: rawWindows)
        let resolvedFocusedWindow = resolvedFocusedWindow(
            for: rawSpace,
            rawWindows: rawWindows,
            focusedWindow: focusedWindow
        )
        let liveStackSummary = stackSummary(
            for: rawSpace,
            countedWindows: countedWindows,
            focusedWindow: resolvedFocusedWindow
        )

        let windows = windowsForSpace.map { window in
            let countsTowardStack = rawSpace.type?.lowercased() == "stack"
                && !window.isHidden
                && !window.isMinimized
                && !window.isFloating

            return WindowDiagnosticItem(
                id: window.id,
                pid: window.pid ?? 0,
                app: window.app,
                title: window.title,
                stackIndex: window.stackIndex,
                hasFocus: window.hasFocus || resolvedFocusedWindow?.id == window.id,
                isHidden: window.isHidden,
                isMinimized: window.isMinimized,
                isFloating: window.isFloating,
                countsTowardStack: countsTowardStack,
                countedPosition: countsTowardStack ? stackPosition(of: window, in: countedWindows) : nil
            )
        }

        return SpaceDiagnosticSummary(
            index: rawSpace.index,
            display: rawSpace.display,
            type: rawSpace.type,
            hasFocus: rawSpace.hasFocus,
            isVisible: rawSpace.isVisible,
            isNativeFullscreen: rawSpace.isNativeFullscreen ?? false,
            liveStackSummary: liveStackSummary,
            windows: windows
        )
    }

    private static func diagnosticsWindowSort(lhs: RawWindow, rhs: RawWindow) -> Bool {
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

    private static func rawWindowsForStack(space: RawSpace, rawWindows: [RawWindow]) -> [RawWindow] {
        guard space.type?.lowercased() == "stack" else {
            return []
        }

        return rawWindows
            .filter { window in
                window.space == space.index && !window.isHidden && !window.isMinimized && !window.isFloating
            }
            .sorted(by: diagnosticsWindowSort)
    }

    private static func resolvedFocusedWindow(
        for rawSpace: RawSpace,
        rawWindows: [RawWindow],
        focusedWindow: RawWindow?
    ) -> RawWindow? {
        if let focusedWindow,
           focusedWindow.space == rawSpace.index,
           !focusedWindow.isHidden,
           !focusedWindow.isMinimized,
           !focusedWindow.isFloating {
            return focusedWindow
        }

        if let focusedWindowForSpace = rawWindows.first(where: { window in
            window.space == rawSpace.index && window.hasFocus && !window.isHidden && !window.isMinimized && !window.isFloating
        }) {
            return focusedWindowForSpace
        }

        let windowsByID = Dictionary(uniqueKeysWithValues: rawWindows.map { ($0.id, $0) })

        if let orderedWindowIDs = rawSpace.windows {
            for windowID in orderedWindowIDs {
                guard let window = windowsByID[windowID] else {
                    continue
                }

                if !window.isHidden, !window.isMinimized, !window.isFloating {
                    return window
                }
            }
        }

        if let firstWindowID = rawSpace.firstWindow,
           let firstWindow = windowsByID[firstWindowID],
           !firstWindow.isHidden,
           !firstWindow.isMinimized,
           !firstWindow.isFloating {
            return firstWindow
        }

        return nil
    }

    private static func stackSummary(
        for rawSpace: RawSpace,
        countedWindows: [RawWindow],
        focusedWindow: RawWindow?
    ) -> ActiveStackSummary? {
        guard rawSpace.type?.lowercased() == "stack", countedWindows.count >= 2 else {
            return nil
        }

        guard let focusedWindow,
              focusedWindow.space == rawSpace.index,
              !focusedWindow.isHidden,
              !focusedWindow.isMinimized,
              !focusedWindow.isFloating,
              let currentIndex = stackPosition(of: focusedWindow, in: countedWindows) else {
            return nil
        }

        return ActiveStackSummary(
            spaceIndex: rawSpace.index,
            currentIndex: currentIndex,
            total: countedWindows.count,
            focusedWindowID: focusedWindow.id,
            focusedAppName: focusedWindow.app
        )
    }

    private static func stackPosition(of window: RawWindow, in stackWindows: [RawWindow]) -> Int? {
        if let normalizedIndex = normalizedStackIndex(of: window, in: stackWindows), (1...stackWindows.count).contains(normalizedIndex) {
            return normalizedIndex
        }

        guard let windowIndex = stackWindows.firstIndex(where: { $0.id == window.id }) else {
            return nil
        }

        return windowIndex + 1
    }

    private static func normalizedStackIndex(of window: RawWindow, in stackWindows: [RawWindow]) -> Int? {
        guard let stackIndex = window.stackIndex else {
            return nil
        }

        let rawIndexes = stackWindows.compactMap(\.stackIndex)
        guard rawIndexes.count == stackWindows.count else {
            return nil
        }

        let sortedIndexes = rawIndexes.sorted()
        let total = stackWindows.count

        if sortedIndexes == Array(1...total) {
            return stackIndex
        }

        if sortedIndexes == Array(0..<total) {
            return stackIndex + 1
        }

        if (1...total).contains(stackIndex) {
            return stackIndex
        }

        if (0..<total).contains(stackIndex) {
            return stackIndex + 1
        }

        return nil
    }

    private static func decodeWindow(from data: Data?) throws -> RawWindow? {
        guard let data, !data.isEmpty else {
            return nil
        }

        return try JSONDecoder().decode(RawWindow.self, from: data)
    }
}
