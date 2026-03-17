# YabaiBar

YabaiBar is a small native macOS menu bar app for `yabai`.

It shows the current space in the native menu bar, lists the existing spaces with the apps inside them, and lets you switch spaces with one click without replacing the macOS menu bar.

## Features

- Shows the active `yabai` space in the native macOS menu bar
- Updates the active space label immediately when macOS changes spaces
- Lists only real, existing spaces
- Shows the apps currently present in each space
- Focuses a space when you click it
- Opens `~/.config/yabai/yabairc` and the Yabai config folder
- Offers to move itself into `Applications`
- Supports launch at login with `SMAppService`
- Stays alive with a degraded status if `yabai` is unavailable

## Requirements

- macOS 14 or later
- `yabai` installed and working
- `yabai` available in `/opt/homebrew/bin/yabai` or `/usr/local/bin/yabai`
- Apple's Xcode toolchain, via Xcode 16 or later, for local builds

## Fastest Build Path

If you just want the app and do not plan to edit the code, the shortest path is:

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

On first launch, the app can offer to:

- move itself into `Applications`
- enable launch at login

## Build From Terminal

```sh
git clone git@github.com:kevinbarfleur/YabaiBar.git
cd YabaiBar
./scripts/build-app.sh
```

The app bundle is written to:

```sh
dist/YabaiBar.app
```

## Development

The Swift package stays available for local development and tests:

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
5. Click the menu bar item to see spaces and switch between them.

## Notes

- YabaiBar queries `yabai` via the CLI and does not replace the native macOS menu bar.
- `Launch at login` only works correctly from a real `.app` bundle in a stable location.
- If macOS asks for login item approval, YabaiBar exposes a shortcut to the relevant system settings.
- `./scripts/build-app.sh` is a thin wrapper around `xcodebuild`, so the CLI path is simple but still relies on Apple's Xcode toolchain being installed.

## CI

GitHub Actions runs a simple validation pipeline:

- `swift test`
- app bundle build via `./scripts/build-app.sh`

## License

MIT. See [LICENSE](LICENSE).
