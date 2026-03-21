# Notch Surface — Geometry & Behavior

## Window Stack

```
NotchSurfaceCoordinator (per-app, manages all displays)
  ↓
DisplayNotchWindowController (per-display)
  ├── YabaiNotchViewModel (state + sizing)
  ├── YabaiNotchWindow (NSPanel subclass)
  └── NotchSurfaceView (SwiftUI, module-agnostic)
```

## Geometry Constants
| Constant | Value | Usage |
|----------|-------|-------|
| notchClosedTopRadius | 6 | Coin haut fermé |
| notchClosedBottomRadius | 14 | Coin bas fermé |
| notchOpenTopRadius | 19 | Coin haut ouvert |
| notchOpenBottomRadius | 24 | Coin bas ouvert |
| notchShadowPadding | 20 | Espace pour l'ombre |
| notchOpenHorizontalPadding | 12 | Padding horizontal ouvert |
| notchOpenBottomPadding | 12 | Padding bas ouvert |
| notchOpenMinimumWidth | 420 | Largeur min ouverte |

## Sizing Chain
```
closedNotchSize.width = leadingWidth + centerWidth + trailingReservedWidth(64)
closedNotchSize.height = max(30, screen.resolvedNotchHeight)

openContentHeight = closedHeight + sum(widgets.estimatedHeight)
openOuterSize.height = max(closedHeight + 12 + 28, openContentHeight + 12)
openOuterSize.width = max(closedNotchSize.width, min(screenWidth - 48, 420))

windowSize = (openOuterSize.width, openOuterSize.height + 20 shadow)
```

**CRITIQUE** : `openContentHeight` DOIT inclure `closedHeight` car la frame disponible pour openBody = `openOuterSize.height - 12 - closedNotchSize.height`

## Hover Flow
1. Mouse enter → `isHovering = true` (animated)
2. Haptic feedback si fermé + haptics enabled
3. Delay `minimumHoverDuration` (default 0.3s)
4. Si toujours hovering → `open(animated: true)`
5. Mouse leave → delay 100ms → `isHovering = false`, `close(animated: true)`

## Zombie Pattern (screen hotplug)
- Écran disparaît → controller moved to zombie pool (deadline: now + 8s)
- Écran réapparaît → controller revived from zombie pool
- Deadline passed → controller destroyed

## lastStableContent (transient gaps)
Quand un module ne renvoie pas de contenu (pendant un changement d'espace),
le controller réutilise le dernier contenu stable pour éviter un flash.
