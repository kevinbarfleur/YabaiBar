# /vibenotch:deploy — Build, install et lance l'app

## Workflow
```bash
pkill -9 -f "VibeNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/VibeNotch.app
cp -R dist/VibeNotch.app /Applications/VibeNotch.app
open /Applications/VibeNotch.app
```

Confirmer que l'app est visible dans la menu bar et que le notch fonctionne.
