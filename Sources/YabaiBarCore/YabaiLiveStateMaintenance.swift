import Foundation

public enum YabaiLiveStateMaintenance {
    public static func rebuildAll(
        from snapshot: YabaiSnapshot,
        now: Date = Date()
    ) -> YabaiLiveState {
        let entries: [(Int, TrackedStackState)] = snapshot.spaces.compactMap { space in
            guard let summary = summary(for: space) else {
                return nil
            }

            return (
                space.index,
                TrackedStackState(
                    spaceIndex: summary.spaceIndex,
                    currentIndex: summary.currentIndex,
                    total: summary.total,
                    focusedWindowID: summary.focusedWindowID,
                    focusedAppName: summary.focusedAppName,
                    updatedAt: now
                )
            )
        }
        let trackedSpaces = Dictionary(uniqueKeysWithValues: entries)

        return YabaiLiveState(
            activeSpaceIndex: snapshot.activeSpaceIndex,
            activeDisplayUUID: snapshot.activeDisplayUUID,
            spaces: trackedSpaces,
            updatedAt: now
        )
    }

    public static func rebuildSpace(
        _ spaceIndex: Int,
        in state: YabaiLiveState,
        using client: YabaiClient,
        now: Date = Date()
    ) throws -> YabaiLiveState {
        let activeSpaceIndex = (try? client.fetchActiveSpaceIndex()) ?? state.activeSpaceIndex
        let activeDisplayUUID = (try? client.fetchActiveDisplayUUID()) ?? state.activeDisplayUUID
        let spaceData = try client.fetchSpaceData(index: spaceIndex)
        let windowsData = try client.fetchWindowsData(spaceIndex: spaceIndex)
        let preferredWindowData = try preferredWindowData(for: spaceIndex, in: state, using: client)
        let summary = try YabaiSnapshotBuilder.activeStackSummary(
            from: spaceData,
            windowsData: windowsData,
            focusedWindowData: preferredWindowData
        )

        let nextState = YabaiLiveStateReducer.spaceChanged(
            activeSpaceIndex,
            activeDisplayUUID: activeDisplayUUID,
            in: state,
            now: now
        )

        return YabaiLiveStateReducer.trackedStackChanged(
            for: spaceIndex,
            summary: summary,
            activeSpaceIndex: activeSpaceIndex,
            in: nextState,
            now: now
        )
    }

    public static func purgeSpace(
        _ spaceIndex: Int,
        from state: YabaiLiveState,
        now: Date = Date()
    ) -> YabaiLiveState {
        YabaiLiveStateReducer.trackedStackChanged(
            for: spaceIndex,
            summary: nil,
            activeSpaceIndex: state.activeSpaceIndex,
            in: state,
            now: now
        )
    }

    private static func summary(for space: SpaceSummary) -> ActiveStackSummary? {
        guard space.isStack else {
            return nil
        }

        if let stackSummary = space.stackSummary {
            return stackSummary
        }

        guard space.stackItems.count >= 2 else {
            return nil
        }

        let focusedItem = space.stackItems.first(where: \.isFocused) ?? space.stackItems.first
        guard let focusedItem else {
            return nil
        }

        return ActiveStackSummary(
            spaceIndex: space.index,
            currentIndex: focusedItem.position,
            total: space.stackItems.count,
            focusedWindowID: focusedItem.id,
            focusedAppName: focusedItem.app
        )
    }

    private static func preferredWindowData(
        for spaceIndex: Int,
        in state: YabaiLiveState,
        using client: YabaiClient
    ) throws -> Data? {
        if let focusedWindowID = state.spaces[spaceIndex]?.focusedWindowID,
           let windowData = try? client.fetchWindowData(id: focusedWindowID),
           let window = try? JSONDecoder().decode(RawWindow.self, from: windowData),
           window.space == spaceIndex,
           !window.isHidden,
           !window.isMinimized,
           !window.isFloating {
            return windowData
        }

        if let focusedWindowData = try? client.fetchFocusedWindowData(),
           let window = try? JSONDecoder().decode(RawWindow.self, from: focusedWindowData),
           window.space == spaceIndex,
           !window.isHidden,
           !window.isMinimized,
           !window.isFloating {
            return focusedWindowData
        }

        return nil
    }
}
