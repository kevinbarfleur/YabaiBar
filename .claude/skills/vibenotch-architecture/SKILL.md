# VibeNotch Architecture

## Module Protocol (`Sources/VibeNotchCore/ModuleProtocol.swift`)

```swift
@MainActor
public protocol VibeNotchModule: AnyObject {
    var identifier: ModuleIdentifier { get }
    var displayName: String { get }
    var icon: String { get }  // SF Symbol

    func activate()
    func deactivate()

    func closedLeadingView(for displayUUID: String) -> NotchSlotContent?
    func closedTrailingView(for displayUUID: String) -> NotchSlotContent?
    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget]

    func statusBarContent() -> StatusBarContent?
    func menuSections() -> [ModuleMenuSection]
    func makeSettingsView() -> AnyView?

    func refresh()
    func displayChanged()

    var objectDidChange: (() -> Void)? { get set }
}
```

**Toutes les méthodes ont des default implementations** (nil, [], {}). Un nouveau module n'a besoin que de 4 propriétés + les overrides utiles.

## Content Types
- `NotchSlotContent(view: AnyView, width: CGFloat)` — slot dans le notch fermé
- `NotchExpandedWidget(id, moduleID, estimatedHeight, content: AnyView)` — widget dans le notch étendu
- `StatusBarContent(icon, label, tooltip, length)` — contenu status bar
- `ModuleMenuSection(title, items: [NSMenuItem])` — section menu

## Module Registry (`Sources/VibeNotchCore/ModuleRegistry.swift`)
- `register(_ module)` — enregistre un module (active par défaut si premier)
- `enabledModules` — modules actifs
- `setEnabled(id, bool)` — active/désactive
- `widgetOrder: [String]` — ordre des widgets (persisté UserDefaults)
- `activeStatusBarModuleID` — quel module pilote la status bar
- `orderedWidgets(for displayUUID)` — widgets triés par ordre utilisateur
- `aggregatedLeadingSlots(for displayUUID)` — slots gauche agrégés
- `aggregatedTrailingSlots(for displayUUID)` — slots droite agrégés

## Data Flow
```
Module.closedLeadingView(displayUUID) → NotchSlotContent
    ↓
ModuleRegistry.aggregatedLeadingSlots(displayUUID) → [NotchSlotContent]
    ↓
DisplayNotchWindowController.refresh() (queries registry)
    ↓
YabaiNotchViewModel.update(leadingSlots, trailingSlots, expandedWidgets)
    ↓
NotchSurfaceView renders slots in topBand + widgets in openBody
```

## Module Minimal

```swift
@MainActor
final class TimerModule: ObservableObject, VibeNotchModule {
    let identifier = ModuleIdentifier("com.vibenotch.timer")
    let displayName = "Timer"
    let icon = "timer"
    var objectDidChange: (() -> Void)?

    // Override seulement les méthodes nécessaires :
    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        // ... retourner les widgets du timer
    }
    func makeSettingsView() -> AnyView? {
        AnyView(TimerSettingsView(module: self))
    }
}
```

Enregistrer dans `AppModel.startIfNeeded()` :
```swift
let timerModule = TimerModule()
moduleRegistry.register(timerModule)
```

## Target Structure
- **VibeNotchCore** : Protocol, Registry, CommandRunner, modèles Yabai
- **VibeNotch** : App shell + tous les modules
- **YabaiBarSignalHelper** : CLI helper pour signals yabai

## Modules de référence
- `TodoListModule.swift` — Le plus simple, self-contained, local seulement (~180 lignes)
- `JiraModule.swift` — Pattern API avec timer refresh + Keychain
- `AIQuotaModule.swift` — Status bar + trailing slot indicator
- `YabaiModule.swift` — Adapter sur AppModel (complexe, couplé — ne pas copier ce pattern)

## YabaiModule (adapter pattern — dette technique)
`YabaiModule` wraps `AppModel` via `weak var appModel: AppModel?`.
Il délègue toutes les queries à AppModel qui contient encore la logique Yabai (~600 lignes).
Phase future : extraire vers un `YabaiStateManager` que YabaiModule possèdera directement.
