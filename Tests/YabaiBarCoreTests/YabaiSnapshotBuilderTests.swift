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
              { "id": 11, "app": "Warp", "space": 2, "is-hidden": false, "is-minimized": false },
              { "id": 12, "app": "Claude", "space": 4, "is-hidden": false, "is-minimized": false },
              { "id": 13, "app": "Messages", "space": 4, "is-hidden": false, "is-minimized": false }
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
              { "id": 21, "app": "Finder", "space": 3, "is-hidden": true, "is-minimized": false },
              { "id": 22, "app": "Warp", "space": 3, "is-hidden": false, "is-minimized": true },
              { "id": 23, "app": "Claude", "space": 3, "is-hidden": false, "is-minimized": false }
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
}
