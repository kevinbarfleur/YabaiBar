import Foundation
import Testing
@testable import OpenNotchCore

struct YabaiDiagnosticsTests {
    @Test
    func buildsDiagnosticsSnapshotWithCountedAndExcludedWindows() throws {
        let spacesData = Data(
            """
            [
              { "index": 1, "type": "stack", "display": 1, "windows": [11, 12, 13, 14], "first-window": 11, "has-focus": true, "is-visible": true }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 11, "pid": 100, "app": "Warp", "title": "Terminal", "space": 1, "stack-index": 10, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 12, "pid": 101, "app": "Safari", "title": "Docs", "space": 1, "stack-index": 20, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 13, "pid": 102, "app": "Slack", "title": "Team", "space": 1, "stack-index": 30, "has-focus": false, "is-hidden": true, "is-minimized": false, "is-floating": false },
              { "id": 14, "pid": 103, "app": "Notes", "title": "Quick", "space": 1, "stack-index": 40, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": true }
            ]
            """.utf8
        )
        let displaysData = Data(
            """
            [
              { "index": 1, "uuid": "display-a", "spaces": [1], "has-focus": true }
            ]
            """.utf8
        )

        let diagnostics = try YabaiDiagnosticsBuilder.build(
            spacesData: spacesData,
            windowsData: windowsData,
            displaysData: displaysData
        )

        #expect(diagnostics.activeSpaceIndex == 1)
        #expect(diagnostics.activeDisplayUUID == "display-a")
        #expect(diagnostics.displays.count == 1)

        let space = try #require(diagnostics.displays.first?.spaces.first)
        #expect(space.countedStackWindowCount == 2)
        #expect(space.liveStackSummary?.badgeLabel == "2/2")
        #expect(space.windows.map(\.id) == [11, 12, 13, 14])
        #expect(space.windows.first(where: { $0.id == 11 })?.countedPosition == 1)
        #expect(space.windows.first(where: { $0.id == 12 })?.countedPosition == 2)
        #expect(space.windows.first(where: { $0.id == 13 })?.countsTowardStack == false)
        #expect(space.windows.first(where: { $0.id == 14 })?.countsTowardStack == false)
    }

    @Test
    func rebuildAllCreatesTrackedEntriesForStackSpaces() throws {
        let spacesData = Data(
            """
            [
              { "index": 1, "type": "stack", "display": 1, "has-focus": true, "is-visible": true },
              { "index": 2, "type": "bsp", "display": 1, "has-focus": false, "is-visible": false }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 21, "pid": 200, "app": "Warp", "title": "Terminal", "space": 1, "stack-index": 1, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 22, "pid": 201, "app": "Safari", "title": "Docs", "space": 1, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 23, "pid": 202, "app": "Notes", "title": "Notes", "space": 2, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )
        let displaysData = Data(
            """
            [
              { "index": 1, "uuid": "display-a", "spaces": [1, 2], "has-focus": true }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(
            spacesData: spacesData,
            windowsData: windowsData,
            displaysData: displaysData
        )

        let rebuiltState = YabaiLiveStateMaintenance.rebuildAll(from: snapshot, now: Date(timeIntervalSince1970: 42))

        #expect(rebuiltState.activeSpaceIndex == 1)
        #expect(rebuiltState.activeDisplayUUID == "display-a")
        #expect(rebuiltState.spaces.keys.sorted() == [1])
        #expect(rebuiltState.spaces[1]?.focusedWindowID == 21)
        #expect(rebuiltState.spaces[1]?.total == 2)
    }

    @Test
    func purgeSpaceRemovesOnlyTargetedTrackedEntry() {
        let now = Date(timeIntervalSince1970: 10)
        let state = YabaiLiveState(
            activeSpaceIndex: 1,
            activeDisplayUUID: "display-a",
            spaces: [
                1: TrackedStackState(spaceIndex: 1, currentIndex: 1, total: 2, focusedWindowID: 11, focusedAppName: "Warp", updatedAt: now),
                3: TrackedStackState(spaceIndex: 3, currentIndex: 2, total: 4, focusedWindowID: 31, focusedAppName: "Slack", updatedAt: now),
            ],
            updatedAt: now
        )

        let purgedState = YabaiLiveStateMaintenance.purgeSpace(1, from: state, now: now.addingTimeInterval(1))

        #expect(purgedState.activeSpaceIndex == 1)
        #expect(purgedState.spaces[1] == nil)
        #expect(purgedState.spaces[3]?.focusedWindowID == 31)
    }
}
