# /vibenotch:feature — Nouvelle fonctionnalité

Tu démarres une **feature** pour VibeNotch.

## Contexte requis
- Skill: vibenotch-architecture
- Rule: philosophy.md, swift-patterns.md

## Workflow

### Phase 1: Plan (OBLIGATOIRE)
1. Lire les fichiers concernés
2. Identifier si c'est un nouveau module ou une extension d'existant
3. Créer un plan avec TodoWrite
4. Attendre validation utilisateur

### Phase 2: Implement
1. Implémenter par chunks logiques
2. Respecter la séparation module/core/shell
3. `swift build` après chaque chunk

### Phase 3: Stabilize (QUALITY GATE)
```bash
swift build    # 0 erreurs
swift test     # 100% pass
```

### Phase 4: Deploy & Test
```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

### Phase 5: Land
Utilise `/vibenotch:land` pour commit.
