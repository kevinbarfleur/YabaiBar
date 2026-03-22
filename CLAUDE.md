# VibeNotch

Plateforme notch modulaire pour macOS. Transforme le notch MacBook en hub configurable alimenté par des modules built-in.

## Architecture

```
Package.swift / project.yml → 3 targets :
  VibeNotchCore (library)       — Module protocol, registry, CommandRunner, modèles Yabai
  VibeNotch (executable/app)    — Shell notch/statusbar/settings + YabaiModule
  YabaiBarSignalHelper (tool)   — Helper CLI pour signals yabai
```

```
Sources/
├── VibeNotch/              ← App principale (15 fichiers)
│   ├── AppModel.swift          ← Orchestrateur central (~1091 lignes)
│   ├── YabaiModule.swift       ← Module Yabai (adapter sur AppModel)
│   ├── YabaiNotchViews.swift   ← Vues Yabai (MetaballSpaceRail, StackListRow, AppIconView)
│   ├── NotchSurfaceView.swift  ← Shell notch agnostique (rend les slots/widgets des modules)
│   ├── NotchSurfaceController.swift ← Window management per-display
│   ├── StatusItemController.swift   ← Menu bar module-aware
│   ├── SettingsView.swift      ← Settings avec sections par module
│   └── ...
├── VibeNotchCore/          ← Bibliothèque core (10 fichiers)
│   ├── ModuleProtocol.swift    ← Protocol VibeNotchModule
│   ├── ModuleRegistry.swift    ← Registre de modules
│   └── Yabai*.swift            ← Client, modèles, signal handler, live state
└── YabaiBarSignalHelper/   ← Helper CLI
```

## Commandes essentielles

```bash
# Build SPM (vérification rapide)
swift build

# Tests
swift test

# Build app finale (.app bundle via XcodeGen + xcodebuild)
bash scripts/build-app.sh
```

## Deploy & Test (CRITIQUE)

**Après TOUTE modification de code, exécuter ce workflow complet :**

```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

Ne JAMAIS utiliser `swift run` pour tester — ça lance un exécutable SPM, pas le .app bundle avec le signal helper et les resources. Toujours builder et installer le .app dans /Applications.

## Module System

Le protocol `VibeNotchModule` fournit des **default implementations** pour toutes les méthodes — un nouveau module n'a besoin que de 4 propriétés obligatoires + les overrides utiles.

Chaque module peut fournir :
- `closedLeadingView()` / `closedTrailingView()` — slots dans le notch fermé
- `expandedWidgets()` — widgets dans le notch étendu
- `statusBarContent()` — icône/label pour la status bar
- `menuSections()` — items dans le menu contextuel
- `makeSettingsView()` — vue settings du module
- `activate()` / `deactivate()` — lifecycle (timers, connections)

## Contributing a New Module

### 1. Créer le module (`Sources/VibeNotch/{Name}Module.swift`)

```swift
@MainActor
final class TimerModule: ObservableObject, VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.timer")
    let displayName = "Timer"
    let icon = "timer"
    var objectDidChange: (() -> Void)?

    // Override seulement les méthodes nécessaires :
    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] { ... }
    func makeSettingsView() -> AnyView? { AnyView(TimerSettingsView(module: self)) }
}
```

### 2. Créer les vues (`Sources/VibeNotch/{Name}Views.swift`)

Vues self-contained avec `@ObservedObject var module: TimerModule`.

### 3. Enregistrer dans AppModel

Dans `AppModel.startIfNeeded()` :
```swift
let timerModule = TimerModule()
moduleRegistry.register(timerModule)
```

### 4. Build & test

```bash
swift build && swift test && bash scripts/build-app.sh
```

Le notch, la status bar, le menu et les settings intègrent le module automatiquement.

**Modules de référence** : `TodoListModule` (simple, local) · `JiraModule` (API + timer) · `AIQuotaModule` (status bar + indicator)

## Animations

Les animations du notch sont critiques pour l'expérience. Paramètres spring actuels :
- Open : `.spring(response: 0.42, dampingFraction: 0.8)`
- Close : `.spring(response: 0.45, dampingFraction: 1.0)`
- Space rail : `.spring(response: 0.28, dampingFraction: 0.58)`
- Badge stack : `.spring(response: 0.35, dampingFraction: 0.72)`

Ne jamais modifier ces valeurs sans tester visuellement. Ne jamais casser les transitions existantes lors de refactoring.

## Conventions

- Swift 6.2 strict concurrency — `@MainActor` sur toutes les classes UI
- `@Published private(set)` pour les propriétés observables
- Combine (`$property.receive(on: RunLoop.main).sink`) pour les bindings controllers
- Pas d'`import Foundation` si `import AppKit` suffit
- Fichiers Yabai-spécifiques préfixés `Yabai` (YabaiModule, YabaiNotchViews, etc.)
- Types core préfixés `Notch` ou `VibeNotch` (NotchSurfaceView, VibeNotchModule, etc.)
