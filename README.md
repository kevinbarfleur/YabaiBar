# YabaiBar

YabaiBar is a native macOS companion for `yabai`.

It shows the current space in the native macOS menu bar, adds a compact `2/4` badge when the active space uses `stack`, lists the existing spaces with the apps inside them, and adds a notch surface inspired by `TheBoredTeam/boring.notch` for a more integrated overview.

## Features

- Shows the active `yabai` space in the native macOS menu bar
- Adds a notch surface with hover expansion and per-screen tracking
- Shows the current stack position like `2/4` for the active stacked space
- Tracks the active stacked window via native `yabai` signals instead of fast polling
- Updates the active space label quickly when macOS changes spaces
- Lists only real, existing spaces
- Shows the apps currently present in each space
- Adds a diagnostics view for displays, spaces, windows, and local stack tracking
- Focuses a space when you click it
- Focuses a stacked window directly from the notch detail panel
- Opens `~/.config/yabai/yabairc` and the Yabai config folder
- Offers to move itself into `Applications`
- Supports launch at login with `SMAppService`
- Stays alive with a degraded status if `yabai` is unavailable
- Exposes notch behavior settings, including hover open, hover delay, and haptics
- Lets you recheck all spaces or a single space when local stack tracking drifts

## Requirements

- macOS 14 or later
- `yabai` installed and working
- `yabai` available in `/opt/homebrew/bin/yabai` or `/usr/local/bin/yabai`
- Apple's Xcode toolchain, via Xcode 16 or later, for local builds
- permission to let YabaiBar manage a small labeled block inside `~/.config/yabai/yabairc`

## Fastest Build Path

```sh
git clone git@github.com:kevinbarfleur/YabaiBar.git
cd YabaiBar
./scripts/build-app.sh
open dist/YabaiBar.app
```

You do not need to open Xcode for this path, but the script still uses Apple's `xcodebuild` under the hood.

## Build In Xcode

```sh
git clone git@github.com:kevinbarfleur/YabaiBar.git
cd YabaiBar
open YabaiBar.xcodeproj
```

Build and run the `YabaiBar` target.

## Development

```sh
swift build
swift test
```

If you want to regenerate the Xcode project instead of using the committed one:

```sh
brew install xcodegen
xcodegen generate
```

## Install And Use

1. Build `YabaiBar.app`.
2. Launch the app.
3. Accept the move to `Applications` if prompted.
4. Let the app register for launch at login if you want it to start automatically.
5. Let the app install or repair its `yabai` signal integration if prompted by the menu state.
6. Click the menu bar item to see spaces and switch between them.
7. Hover the notch surface to open the compact overview panel, or disable it from the menu if you prefer menu bar only.
8. Open `Settings → Diagnostics` to inspect stack counts, compare live `yabai` data with YabaiBar's local runtime state, recheck a space, or purge stale local entries.

## Notes

- YabaiBar keeps the spaces menu based on `yabai` CLI queries.
- The active stack badge is driven by `yabai signal` events written into a local runtime state file.
- `Refresh` updates the visible UI state. `Recheck` rebuilds YabaiBar's local stack runtime state from fresh `yabai` queries.
- The notch companion renders once per display. On screens without a hardware notch it falls back to a centered pill.
- `Launch at login` only works correctly from a real `.app` bundle in a stable location.
- If macOS asks for login item approval, YabaiBar exposes a shortcut to the relevant system settings.
- YabaiBar manages a labeled block inside `~/.config/yabai/yabairc` so it can register and repair its own signal integration safely.
- `./scripts/build-app.sh` is a thin wrapper around `xcodebuild`, so the CLI path is simple but still relies on Apple's Xcode toolchain being installed.

## Attribution

The notch window architecture, hover behavior, and animation model are adapted from [`TheBoredTeam/boring.notch`](https://github.com/TheBoredTeam/boring.notch).

That reuse is intentional and the repository license reflects it.

## CI

GitHub Actions runs a simple validation pipeline:

- `swift test`
- app bundle build via `./scripts/build-app.sh`

## License

GPL-3.0. See [LICENSE](LICENSE).
