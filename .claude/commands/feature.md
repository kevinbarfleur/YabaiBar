# /opennotch:feature — Nouvelle fonctionnalité

Tu démarres une **feature** pour OpenNotch.

## Contexte requis
- Skill: opennotch-architecture
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
pkill -9 -f "OpenNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/OpenNotch.app
cp -R dist/OpenNotch.app /Applications/OpenNotch.app
open /Applications/OpenNotch.app
```

### Phase 5: Land
Utilise `/opennotch:land` pour commit.
