# VibeNotch — AI Coding Agent Guide

Modular notch platform for macOS. Transforms the MacBook notch into a configurable hub powered by built-in modules (Yabai spaces, Jira issues, AI quota, Todo list).

## Architecture

```
Package.swift / project.yml → 3 targets:
  VibeNotchCore (library)       — Module protocol, registry, CommandRunner, Yabai models
  VibeNotch (executable/app)    — Shell notch/statusbar/settings + all modules
  YabaiBarSignalHelper (tool)   — CLI helper for yabai signals
```

### Key Files

| File | Role |
|------|------|
| `Sources/VibeNotchCore/ModuleProtocol.swift` | `VibeNotchModule` protocol + default implementations |
| `Sources/VibeNotchCore/ModuleRegistry.swift` | Module ordering, visibility, persistence |
| `Sources/VibeNotch/AppModel.swift` | Central orchestrator, module registration |
| `Sources/VibeNotch/NotchSurfaceView.swift` | Module-agnostic notch renderer |
| `Sources/VibeNotch/NotchSurfaceController.swift` | Per-display window management |
| `Sources/VibeNotch/StatusItemController.swift` | Menu bar, module-aware |
| `Sources/VibeNotch/SettingsView.swift` | Settings UI, delegates to modules |

### Existing Modules

| Module | ID | Pattern |
|--------|----|---------|
| `YabaiModule` | `com.vibenotch.yabai` | Adapter on AppModel (complex) |
| `JiraModule` | `com.vibenotch.jira` | API + timer refresh |
| `AIQuotaModule` | `com.vibenotch.aiquota` | OAuth + status indicator |
| `TodoListModule` | `com.vibenotch.todolist` | Local CRUD (simplest) |

## Build / Test / Deploy

```bash
swift build                    # Quick compilation check
swift test                     # Unit tests (18 tests)
bash scripts/build-app.sh     # Full .app bundle

# Deploy (after ANY code change):
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

Never use `swift run` — always build and install the .app bundle.

## Creating a New Module

1. Create `{Name}Module.swift` in `Sources/VibeNotch/`
2. Conform to `VibeNotchModule` — only 4 required properties, all methods have defaults
3. Create `{Name}Views.swift` for UI components
4. Register in `AppModel.startIfNeeded()`
5. Build & test: `swift build && swift test && bash scripts/build-app.sh`

See `TodoListModule.swift` for the simplest reference implementation.

## Critical Constraints

- **Swift 6.2 strict concurrency**: `@MainActor` on all UI classes, `Sendable` on data types
- **Spring animations only**: Never linear/easeIn. Parameters in `.claude/rules/animation.md`
- **macOS native**: NSPanel, NSStatusItem, NSHapticFeedbackManager — no cross-platform abstractions
- **Module independence**: Modules must not reference each other. No cross-module coupling
- **No god objects**: Don't add logic to AppModel — put it in the module
- **Naming**: Module files `{Name}Module.swift` + `{Name}Views.swift`, IDs `com.vibenotch.{name}`

## Tool-Specific Config

- **Claude Code**: `.claude/` directory (agents, commands, rules, skills)
- **Cursor**: `.cursor/rules/*.mdc` + `.cursorrules`
