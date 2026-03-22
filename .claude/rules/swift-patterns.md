# Swift Patterns — VibeNotch

## Swift 6 Strict Concurrency
- `@MainActor` sur toutes les classes UI (views, controllers, view models)
- `Sendable` sur les types de données partagés entre threads
- `@unchecked Sendable` uniquement pour les wrappers AppKit (ex: NotchSlotContent avec AnyView)
- `Task.detached(priority: .userInitiated)` pour le travail background
- `await MainActor.run { }` pour revenir sur le main thread

## SwiftUI
- `@ObservedObject` pour les view models injectés
- `@State` pour l'état local de la vue
- `@Published private(set)` pour les propriétés exposées en lecture seule
- Pas de `@StateObject` dans les vues créées par les controllers AppKit (ownership gérée par le controller)
- `AnyView` uniquement aux frontières de modules (slots, widgets) — jamais dans le code interne

## Combine
- Pattern : `model.$property.receive(on: RunLoop.main).sink { }.store(in: &cancellables)`
- Toujours `.receive(on: RunLoop.main)` pour éviter les crashes threading

## Patterns AppKit/SwiftUI bridge
- `NSHostingView(rootView:)` pour embedder SwiftUI dans AppKit
- Window management via AppKit (NSPanel), contenu via SwiftUI

## Nommage
- Fichiers : PascalCase (AppModel.swift, NotchSurfaceView.swift)
- Types module : préfixe `Yabai` (YabaiModule, YabaiNotchViews)
- Types core : préfixe `Notch` ou `VibeNotch` (NotchSurfaceView, VibeNotchModule)
- Protocols : suffixe descriptif (VibeNotchModule, CommandRunning)
