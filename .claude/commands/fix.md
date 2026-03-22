# /vibenotch:fix — Correction de bug

Tu démarres un **fix** pour VibeNotch.

## Workflow

### Phase 1: Diagnostic
1. Reproduire le bug (lire le code, comprendre le flow)
2. Identifier la cause racine
3. Vérifier si c'est dans le module ou le core

### Phase 2: Fix
1. Appliquer la correction minimale
2. `swift build` pour vérifier

### Phase 3: Deploy & Test
```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

### Phase 4: Land
`/vibenotch:land`
