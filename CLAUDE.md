# OpenNotch

Plateforme notch modulaire pour macOS. Transforme le notch MacBook en hub configurable alimenté par des modules built-in.

## Architecture

```
Package.swift / project.yml → 3 targets :
  OpenNotchCore (library)       — Module protocol, registry, CommandRunner, modèles Yabai
  OpenNotch (executable/app)    — Shell notch/statusbar/settings + YabaiModule
  YabaiBarSignalHelper (tool)   — Helper CLI pour signals yabai
```

```
Sources/
├── OpenNotch/              ← App principale (15 fichiers)
│   ├── AppModel.swift          ← Orchestrateur central (~1091 lignes)
│   ├── YabaiModule.swift       ← Module Yabai (adapter sur AppModel)
│   ├── YabaiNotchViews.swift   ← Vues Yabai (MetaballSpaceRail, StackListRow, AppIconView)
│   ├── NotchSurfaceView.swift  ← Shell notch agnostique (rend les slots/widgets des modules)
│   ├── NotchSurfaceController.swift ← Window management per-display
│   ├── StatusItemController.swift   ← Menu bar module-aware
│   ├── SettingsView.swift      ← Settings avec sections par module
│   └── ...
├── OpenNotchCore/          ← Bibliothèque core (10 fichiers)
│   ├── ModuleProtocol.swift    ← Protocol OpenNotchModule
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
pkill -9 -f "OpenNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/OpenNotch.app
cp -R dist/OpenNotch.app /Applications/OpenNotch.app
open /Applications/OpenNotch.app
```

Ne JAMAIS utiliser `swift run` pour tester — ça lance un exécutable SPM, pas le .app bundle avec le signal helper et les resources. Toujours builder et installer le .app dans /Applications.

## Module System

Ajouter un module :
1. Créer une classe conforme à `OpenNotchModule` (voir `ModuleProtocol.swift`)
2. L'enregistrer dans `AppModel.startIfNeeded()` via `moduleRegistry.register(monModule)`
3. Le notch, la status bar, le menu et les settings l'intègrent automatiquement

Chaque module fournit :
- `closedLeadingView()` / `closedTrailingView()` — slots dans le notch fermé
- `expandedWidgets()` — widgets dans le notch étendu
- `statusBarContent()` — icône/label pour la status bar
- `menuSections()` — items dans le menu contextuel
- `makeSettingsView()` — vue settings du module

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
- Types core préfixés `Notch` ou `OpenNotch` (NotchSurfaceView, OpenNotchModule, etc.)
