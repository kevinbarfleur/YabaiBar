import Foundation
import Testing
@testable import YabaiBarCore

struct YabaiIntegrationRendererTests {
    @Test
    func mergeAppendsManagedBlockWhenMissing() {
        let existing = """
        #!/usr/bin/env sh

        yabai -m config layout bsp
        """

        let block = YabaiIntegrationRenderer.render(
            executablePath: "/Applications/YabaiBar.app/Contents/MacOS/YabaiBar",
            runtimeDirectoryPath: "/Users/test/Library/Application Support/YabaiBar/runtime",
            yabaiExecutablePath: "/opt/homebrew/bin/yabai"
        )

        let merged = YabaiIntegrationRenderer.merge(managedBlock: block, into: existing)

        #expect(merged.contains(YabaiIntegrationRenderer.startMarker))
        #expect(merged.contains("event=window_focused"))
        #expect(merged.contains("--signal space_changed"))
    }

    @Test
    func mergeReplacesExistingManagedBlock() {
        let original = """
        yabai -m config layout bsp

        # >>> YabaiBar >>>
        old
        # <<< YabaiBar <<<
        """

        let replacement = """
        # >>> YabaiBar >>>
        new
        # <<< YabaiBar <<<
        """

        let merged = YabaiIntegrationRenderer.merge(managedBlock: replacement, into: original)

        #expect(merged.contains("new"))
        #expect(!merged.contains("old"))
    }

    @Test
    func spaceChangedPreservesTrackedStackForSpace() {
        let now = Date(timeIntervalSince1970: 10)
        let trackedState = TrackedStackState(
            spaceIndex: 3,
            currentIndex: 2,
            total: 4,
            focusedWindowID: 42,
            focusedAppName: "Warp",
            updatedAt: now
        )

        let state = YabaiLiveState(activeSpaceIndex: 1, activeDisplayUUID: "display-a", spaces: [3: trackedState], updatedAt: now)
        let updated = YabaiLiveStateReducer.spaceChanged(3, activeDisplayUUID: "display-b", in: state, now: now.addingTimeInterval(1))

        #expect(updated.activeSpaceIndex == 3)
        #expect(updated.activeDisplayUUID == "display-b")
        #expect(updated.spaces[3] == trackedState)
        #expect(updated.activeStackSummary?.badgeLabel == "2/4")
    }

    @Test
    func trackedStackChangedStoresAndRemovesSummary() {
        let start = YabaiLiveState(activeSpaceIndex: 4)
        let summary = ActiveStackSummary(spaceIndex: 4, currentIndex: 3, total: 5, focusedWindowID: 88, focusedAppName: "Slack")

        let stored = YabaiLiveStateReducer.trackedStackChanged(for: 4, summary: summary, activeSpaceIndex: 4, in: start)
        #expect(stored.activeStackSummary == summary)

        let removed = YabaiLiveStateReducer.trackedStackChanged(for: 4, summary: nil, activeSpaceIndex: 4, in: stored)
        #expect(removed.activeStackSummary == nil)
        #expect(removed.spaces[4] == nil)
    }
}
