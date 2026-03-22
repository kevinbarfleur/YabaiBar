# /vibenotch:module — Nouveau module VibeNotch

Tu crées un **nouveau module** pour VibeNotch.

## Contexte requis
- Skill: vibenotch-architecture
- Référence simple: `Sources/VibeNotch/TodoListModule.swift` (module self-contained)
- Référence API: `Sources/VibeNotch/JiraModule.swift` (timer + API externe)

## Template minimal

Le protocol a des **default implementations** pour toutes les méthodes. Un module minimal :

```swift
@MainActor
final class {Name}Module: ObservableObject, VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.{name}")
    let displayName = "{Display Name}"
    let icon = "{sf.symbol.name}"
    var objectDidChange: (() -> Void)?

    // Override uniquement les méthodes nécessaires
}
```

## Workflow

### Phase 1: Design
1. Définir l'identifiant (`com.vibenotch.{name}`)
2. Quels slots ? (leading, trailing, expanded widgets)
3. Status bar content ? Menu sections ?
4. Settings nécessaires ?
5. Lifecycle : timers, connexions API, cleanup ?

### Phase 2: Implement
1. Créer `{Name}Module.swift` dans `Sources/VibeNotch/`
2. Conformer à `VibeNotchModule` (override seulement les méthodes utiles)
3. Créer `{Name}Views.swift` pour les vues (si le module a des widgets/settings)
4. Enregistrer dans `AppModel.startIfNeeded()` : `moduleRegistry.register({name}Module)`
5. Ajouter les UserDefaults keys dans `SettingsBackupManager.allKeys` si applicable

### Phase 3: Deploy & Test
Full deploy cycle :
```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

Vérifier : module visible dans Settings, slots/widgets rendus dans le notch.
