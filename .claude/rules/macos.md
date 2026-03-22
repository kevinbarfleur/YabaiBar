# macOS Best Practices — VibeNotch

## NSPanel (fenêtre notch)
- Style : `.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow`
- Level : `.mainMenu + 3` (au-dessus de tout sauf le dock)
- `canBecomeKey: false`, `canBecomeMain: false` — ne vole jamais le focus
- `hidesOnDeactivate: false` — reste visible quand l'app perd le focus
- `collectionBehavior: [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`

## NSStatusItem (menu bar)
- `NSStatusBar.system.statusItem(withLength:)` pour créer
- `NSStatusBar.system.removeStatusItem()` pour supprimer proprement
- Toujours `cancel tracking` du menu avant de supprimer l'item
- `isTemplate = true` pour les images (s'adaptent au mode clair/sombre)

## Multi-display
- `NSScreen.screens` pour lister les écrans
- Display UUID via `CGDisplayCreateUUIDFromDisplayID`
- Chaque écran a son propre NotchWindowController
- Zombie pattern (8s grace period) pour les écrans déconnectés temporairement

## Notch Detection
- `screen.auxiliaryTopLeftArea` pour détecter la présence du notch hardware
- `screen.safeAreaInsets.top` pour la hauteur du notch
- Fallback : utiliser la hauteur de la menu bar

## App Lifecycle
- `NSApp.setActivationPolicy(.accessory)` — pas d'icône dock
- `SMAppService` pour le login item (macOS 13+)
- Installation dans /Applications nécessaire pour le login item

## Haptics
- `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)`
- Uniquement sur hover du notch en état fermé
- Configurable (peut être désactivé dans les settings)

## System Wake Recovery
- `NSWorkspace.didWakeNotification` pour détecter le réveil
- Multi-attempt recovery : [300, 800, 1500, 3000]ms
- Reconcilier tous les controllers à chaque attempt
