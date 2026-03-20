import Foundation
import Testing
@testable import YabaiBarCore

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
              { "id": 11, "app": "Warp", "space": 2, "stack-index": 1, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 12, "app": "Claude", "space": 4, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 13, "app": "Messages", "space": 4, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
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
              { "id": 21, "app": "Finder", "space": 3, "stack-index": 1, "has-focus": false, "is-hidden": true, "is-minimized": false, "is-floating": false },
              { "id": 22, "app": "Warp", "space": 3, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": true, "is-floating": false },
              { "id": 23, "app": "Claude", "space": 3, "stack-index": 3, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
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
              { "id": 31, "app": "Warp", "space": 3, "stack-index": 20, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 32, "app": "Safari", "space": 3, "stack-index": 10, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 33, "app": "Claude", "space": 3, "stack-index": 30, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )

        let snapshot = try YabaiSnapshotBuilder.build(spacesData: spacesData, windowsData: windowsData)

        #expect(snapshot.activeStackSummary == ActiveStackSummary(spaceIndex: 3, currentIndex: 1, total: 3, focusedWindowID: 32, focusedAppName: "Safari"))
        #expect(snapshot.activeStackSummary?.badgeLabel == "1/3")
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
              { "id": 41, "app": "Warp", "space": 5, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": true },
              { "id": 42, "app": "Safari", "space": 5, "stack-index": 2, "has-focus": false, "is-hidden": true, "is-minimized": false, "is-floating": false },
              { "id": 43, "app": "Claude", "space": 5, "stack-index": 3, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 44, "app": "Messages", "space": 5, "stack-index": 4, "has-focus": false, "is-hidden": false, "is-minimized": true, "is-floating": false },
              { "id": 45, "app": "Notion", "space": 5, "stack-index": 5, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
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
              { "id": 71, "app": "Warp", "space": 7, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 72, "app": "Safari", "space": 7, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 73, "app": "Claude", "space": 7, "stack-index": 3, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
            ]
            """.utf8
        )
        let focusedWindowData = Data(
            """
            { "id": 72, "app": "Safari", "space": 7, "stack-index": 2, "has-focus": true, "is-hidden": false, "is-minimized": false, "is-floating": false }
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
              { "id": 81, "app": "Warp", "space": 8, "stack-index": 1, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 82, "app": "Safari", "space": 8, "stack-index": 2, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false },
              { "id": 83, "app": "Claude", "space": 8, "stack-index": 3, "has-focus": false, "is-hidden": false, "is-minimized": false, "is-floating": false }
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
