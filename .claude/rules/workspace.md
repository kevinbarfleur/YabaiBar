# Workspace — VibeNotch

## Structure du projet
- `Package.swift` — SPM targets (build rapide, tests)
- `project.yml` — XcodeGen spec (génère le .xcodeproj pour le .app bundle)
- `scripts/build-app.sh` — Build complet : xcodegen → xcodebuild → dist/

## Workflow de développement

### Cycle rapide (vérification compilation)
```bash
swift build
swift test
```

### Cycle complet (test en conditions réelles)
```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

### Quality Gate (obligatoire avant land)
1. `swift build` — 0 erreurs
2. `swift test` — 100% pass
3. `bash scripts/build-app.sh` — BUILD SUCCEEDED
4. Test visuel : changer d'espace, hover notch, ouvrir settings

## Conventions Git
- Branches : `main` uniquement (pas de feature branches pour l'instant)
- Commits : message concis, impératif, anglais
- Pas de push --force sur main
