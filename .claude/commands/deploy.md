# /opennotch:deploy — Build, install et lance l'app

## Workflow
```bash
pkill -9 -f "OpenNotch" 2>/dev/null; sleep 1
bash scripts/build-app.sh
rm -rf /Applications/OpenNotch.app
cp -R dist/OpenNotch.app /Applications/OpenNotch.app
open /Applications/OpenNotch.app
```

Confirmer que l'app est visible dans la menu bar et que le notch fonctionne.
