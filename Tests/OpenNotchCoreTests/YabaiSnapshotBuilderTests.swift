import Foundation
import Testing
@testable import OpenNotchCore

struct YabaiSnapshotBuilderTests {
    @Test
    func buildsSpacesSortedByDisplayThenIndex() throws {
        let spacesData = Data(
            """
            [
              { "index": 4, "display": 2, "has-focus": false, "is-visible": false },
              { "index": 2, "display": 1, "has-focus": true, "is-visible": true },
              { "index": 1, "display": 1, "has-focus": false, "is-visible": false }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 11, "app": "Warp", "title": "Terminal", "space": 2, "stack-index": 1, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 12, "app": "Claude", "title": "Chat", "space": 4, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 13, "app": "Messages", "title": "Messages", "space": 4, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(spacesData: spacesData, windowsData: windowsData)

        #expect(snapshot.activeSpaceIndex == 2)
        #expect(snapshot.spaces.map(\.index) == [1, 2, 4])
        #expect(snapshot.spaces.map(\.display) == [1, 1, 2])
        #expect(snapshot.spaces[1].apps == ["Warp"])
        #expect(snapshot.spaces[2].apps == ["Claude", "Messages"])
    }

    @Test
    func buildsDisplaysAndActiveDisplayUUID() throws {
        let spacesData = Data(
            """
            [
              { "index": 1, "display": 1, "has-focus": false, "is-visible": false },
              { "index": 2, "display": 2, "has-focus": true, "is-visible": true }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 21, "app": "Warp", "title": "Terminal", "space": 2, "stack-index": 1, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )
        let displaysData = Data(
            """
            [
              { "index": 1, "uuid": "display-a", "spaces": [1], "has-focus": false },
              { "index": 2, "uuid": "display-b", "spaces": [2], "has-focus": true }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(
            spacesData: spacesData,
            windowsData: windowsData,
            displaysData: displaysData
        )

        #expect(snapshot.activeDisplayUUID == "display-b")
        #expect(snapshot.displays.map(\.index) == [1, 2])
        #expect(snapshot.displays[1].uuid == "display-b")
    }

    @Test
    func filtersHiddenAndMinimizedWindowsFromSummary() throws {
        let spacesData = Data(
            """
            [
              { "index": 3, "display": 1, "has-focus": false, "is-visible": false }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 21, "app": "Finder", "title": "Finder", "space": 3, "stack-index": 1, "has-focus": false, "is-hidden": true, "is-minimized": false, "is-floating": false },
              { "id": 22, "app": "Warp", "title": "Terminal", "space": 3, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": true, "is-floating": false },
              { "id": 23, "app": "Claude", "title": "Chat", "space": 3, "stack-index": 3, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(spacesData: spacesData, windowsData: windowsData)

        #expect(snapshot.spaces.count == 1)
        #expect(snapshot.spaces[0].apps == ["Claude"])
    }

    @Test
    func appSummaryTruncatesAfterTwoApps() {
        let summary = SpaceSummary(
            index: 9,
            display: 2,
            hasFocus: false,
            isVisible: false,
            type: "bsp",
            isNativeFullscreen: false,
            apps: ["Claude", "Messages", "Warp"]
        )

        #expect(summary.appSummary == "Claude, Messages +1")
        #expect(summary.appSummary(maxApps: 1) == "Claude +2")
        #expect(summary.appSummary(maxApps: 3) == "Claude, Messages, Warp")
    }

    @Test
    func extractsActiveSpaceIndexFromSpacesPayload() throws {
        let spacesData = Data(
            """
            [
              { "index": 1, "display": 1, "has-focus": false, "is-visible": false },
              { "index": 4, "display": 2, "has-focus": true, "is-visible": true }
            ]
            """.utf8
        )

        let activeSpaceIndex = try YabaiSnapshotBuilder.activeSpaceIndex(from: spacesData)

        #expect(activeSpaceIndex == 4)
    }

    @Test
    func extractsActiveDisplayUUIDFromDisplaysPayload() throws {
        let displaysData = Data(
            """
            [
              { "index": 1, "uuid": "display-a", "spaces": [1, 2], "has-focus": false },
              { "index": 2, "uuid": "display-b", "spaces": [3], "has-focus": true }
            ]
            """.utf8
        )

        let activeDisplayUUID = try YabaiSnapshotBuilder.activeDisplayUUID(from: displaysData)

        #expect(activeDisplayUUID == "display-b")
    }

    @Test
    func buildsActiveStackSummaryForFocusedStackSpace() throws {
        let spacesData = Data(
            """
            [
              { "index": 3, "type": "stack", "display": 1, "has-focus": true, "is-visible": true }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 31, "app": "Warp", "title": "Terminal", "space": 3, "stack-index": 20, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 32, "app": "Safari", "title": "Docs", "space": 3, "stack-index": 10, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 33, "app": "Claude", "title": "Chat", "space": 3, "stack-index": 30, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(spacesData: spacesData, windowsData: windowsData)

        #expect(snapshot.activeStackSummary == ActiveStackSummary(spaceIndex: 3, currentIndex: 1, total: 3, focusedWindowID: 32, focusedAppName: "Safari"))
        #expect(snapshot.activeStackSummary?.badgeLabel == "1/3")
        #expect(snapshot.activeStackItems.map(\.position) == [1, 2, 3])
        #expect(snapshot.activeStackItems.first?.title == "Docs")
    }

    @Test
    func includesActiveSpaceTypeAndFullscreenFlag() throws {
        let spacesData = Data(
            """
            [
              { "index": 6, "type": "bsp", "display": 1, "has-focus": true, "is-visible": true, "is-native-fullscreen": true }
            ]
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 61, "app": "Warp", "title": "Terminal", "space": 6, "stack-index": 1, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(spacesData: spacesData, windowsData: windowsData)

        #expect(snapshot.activeSpaceType == "bsp")
        #expect(snapshot.activeSpaceIsNativeFullscreen)
    }

    @Test
    func excludesFloatingHiddenAndMinimizedWindowsFromActiveStackSummary() throws {
        let spaceData = Data(
            """
            { "index": 5, "type": "stack", "display": 1, "has-focus": true, "is-visible": true }
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 41, "app": "Warp", "title": "Terminal", "space": 5, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": true },
              { "id": 42, "app": "Safari", "title": "Docs", "space": 5, "stack-index": 2, "has-focus": false, "is-hidden": true, "is-minimized": false, "is-floating": false },
              { "id": 43, "app": "Claude", "title": "Chat", "space": 5, "stack-index": 3, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 44, "app": "Messages", "title": "Inbox", "space": 5, "stack-index": 4, "has-focus": false, "is-hidden": false, "is-minimized": true, "is-floating": false },
              { "id": 45, "app": "Notion", "title": "Notes", "space": 5, "stack-index": 5, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let activeStackSummary = try YabaiSnapshotBuilder.activeStackSummary(from: spaceData, windowsData: windowsData)

        #expect(activeStackSummary == ActiveStackSummary(spaceIndex: 5, currentIndex: 1, total: 2, focusedWindowID: 43, focusedAppName: "Claude"))
    }

    @Test
    func prefersDedicatedFocusedWindowPayloadWhenSpaceWindowFocusIsStale() throws {
        let spaceData = Data(
            """
            { "index": 7, "type": "stack", "display": 1, "has-focus": true, "is-visible": true }
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 71, "app": "Warp", "title": "Terminal", "space": 7, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 72, "app": "Safari", "title": "Docs", "space": 7, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 73, "app": "Claude", "title": "Chat", "space": 7, "stack-index": 3, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )
        let focusedWindowData = Data(
            """
            { "id": 72, "app": "Safari", "title": "Docs", "space": 7, "stack-index": 2, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
            """.utf8
        )

        let activeStackSummary = try YabaiSnapshotBuilder.activeStackSummary(
            from: spaceData,
            windowsData: windowsData,
            focusedWindowData: focusedWindowData
        )

        #expect(activeStackSummary == ActiveStackSummary(spaceIndex: 7, currentIndex: 2, total: 3, focusedWindowID: 72, focusedAppName: "Safari"))
    }

    @Test
    func fallsBackToSpaceWindowOrderingWhenNoWindowHasFocusFlag() throws {
        let spaceData = Data(
            """
            { "index": 8, "type": "stack", "display": 1, "windows": [82, 81, 83], "first-window": 82, "has-focus": true, "is-visible": true }
            """.utf8
        )
        let windowsData = Data(
            """
            [
              { "id": 81, "app": "Warp", "title": "Terminal", "space": 8, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 82, "app": "Safari", "title": "Docs", "space": 8, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 83, "app": "Claude", "title": "Chat", "space": 8, "stack-index": 3, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let activeStackSummary = try YabaiSnapshotBuilder.activeStackSummary(
            from: spaceData,
            windowsData: windowsData
        )

        #expect(activeStackSummary == ActiveStackSummary(spaceIndex: 8, currentIndex: 2, total: 3, focusedWindowID: 82, focusedAppName: "Safari"))
    }
}
