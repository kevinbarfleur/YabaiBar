# Yabai Integration

## Signal Flow
```
yabai event (space_changed, window_focused, etc.)
  ↓
yabairc signal block calls YabaiBarSignalHelper --signal <event>
  ↓
YabaiSignalHandler processes event (reducer pattern)
  ↓
Writes state.json to ~/Library/Application Support/OpenNotch/runtime/
  ↓
YabaiRuntimeMonitor (kqueue/DispatchSource) detects file change
  ↓
AppModel.applyLiveState(YabaiLiveState)
  ↓
reconcileDisplayedState → update activeSpaceIndex, activeStackSummary
```

## Reconciliation Pattern
Multiple retry delays pour obtenir un état cohérent :
- Changement d'espace : [0, 80, 220]ms
- Focus window : [30, 100, 240]ms
- Live state applied : [0, 60, 160]ms (si stack) ou [0, 80, 220]ms (sinon)

Chaque attempt : `fetchActiveSpaceIndex + fetchActiveStackSummary + fetchActiveDisplayUUID`

## YabaiClient Methods
- `fetchSnapshot()` — état complet (spaces, windows, displays, focused window)
- `fetchActiveSpaceIndex()` — espace actif (rapide)
- `fetchActiveStackSummary()` — stack actif (rapide)
- `fetchActiveDisplayUUID()` — display actif
- `focusSpace(index:)` / `focusWindow(id:)` — commandes

## Live State Persistence
- `YabaiLiveState` : activeSpaceIndex, activeDisplayUUID, spaces dict
- `TrackedStackState` : per-space stack tracking (currentIndex, total, focusedWindowID)
- Persisté en JSON à `~/Library/Application Support/OpenNotch/runtime/state.json`
- File-based locking avec `flock()` pour les écritures concurrentes

## Integration Markers in yabairc
```bash
# >>> OpenNotch >>>
# Managed by OpenNotch. Changes inside this block will be replaced.
yabai -m signal --add event=space_changed action='...' label=yabaibar-space-changed
# ... (8 signal types)
# <<< OpenNotch <<<
```
Legacy markers `# >>> YabaiBar >>>` sont aussi détectés pour la migration.
