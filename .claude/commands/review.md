# /vibenotch:review — Review de code

Invoquer le **senior-reviewer** pour une review complète.

## Workflow
1. Lire tous les fichiers modifiés
2. Vérifier l'architecture (séparation module/core/shell)
3. Vérifier les animations
4. Quality gate (`swift build`, `swift test`)
5. Produire un verdict : ✅ APPROVED / ⚠️ CONCERNS / ❌ BLOCKED
