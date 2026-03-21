# /opennotch:module — Nouveau module OpenNotch

Tu crées un **nouveau module** pour OpenNotch.

## Contexte requis
- Skill: opennotch-architecture
- Référence: Sources/OpenNotch/YabaiModule.swift (module existant)

## Workflow

### Phase 1: Design
1. Définir l'identifiant du module (ex: `com.opennotch.timer`)
2. Définir les slots fournis (leading, trailing, expanded widgets)
3. Définir le contenu status bar (si applicable)
4. Définir les settings du module

### Phase 2: Implement
1. Créer `{ModuleName}Module.swift` dans `Sources/OpenNotch/`
2. Implémenter `OpenNotchModule`
3. Créer les vues dans `{ModuleName}Views.swift`
4. Enregistrer dans `AppModel.startIfNeeded()` : `moduleRegistry.register(monModule)`

### Phase 3: Deploy & Test
Full deploy cycle.
