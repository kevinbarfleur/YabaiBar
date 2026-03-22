# Animation Rules — VibeNotch

## Paramètres Spring (NE PAS MODIFIER sans test visuel)
| Animation | Response | Damping | Usage |
|-----------|----------|---------|-------|
| Open notch | 0.42 | 0.8 | Expansion du notch |
| Close notch | 0.45 | 1.0 | Fermeture du notch |
| Space rail | 0.28 | 0.58 | Déplacement du dot actif |
| Badge stack | 0.35 | 0.72 | Apparition/disparition du badge |
| Hover state | 0.35 | 0.72 | trailingVisibleWidth |

## Règles
- TOUJOURS : Spring animations (jamais linear, jamais easeIn seul)
- TOUJOURS : `.animation()` avec un `value:` explicite
- TOUJOURS : Transitions `.asymmetric()` pour les éléments conditionnels
- TOUJOURS : Tester visuellement après modification

## Transitions
- Badge stack : insertion `.scale(0.6) + .opacity`, removal `.scale(0.8) + .opacity`
- Expanded content : `.opacity` + `.blur(16→0)` + `.offset(y: -10→0)` avec delay 70ms

## Performance
- Compositor properties uniquement (opacity, transform, blur)
- Pas d'animation sur width/height directement — utiliser `frame()` avec des valeurs calculées
- `withAnimation()` pour les changements d'état, `.animation()` pour les changements de valeur

## Anti-patterns
- ❌ `transition: all` équivalent
- ❌ Animation sans explicit `value:` binding
- ❌ Modifier les paramètres spring sans tester
- ❌ Casser les transitions existantes lors de refactoring
