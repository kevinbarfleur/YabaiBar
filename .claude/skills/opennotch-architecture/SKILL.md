# OpenNotch Architecture

## Module Protocol (`Sources/OpenNotchCore/ModuleProtocol.swift`)

```swift
@MainActor
public protocol OpenNotchModule: AnyObject {
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

## Content Types
- `NotchSlotContent(view: AnyView, width: CGFloat)` — slot dans le notch fermé
- `NotchExpandedWidget(id, moduleID, estimatedHeight, content: AnyView)` — widget dans le notch étendu
- `StatusBarContent(icon, label, tooltip, length)` — contenu status bar
- `ModuleMenuSection(title, items: [NSMenuItem])` — section menu

## Module Registry (`Sources/OpenNotchCore/ModuleRegistry.swift`)
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

## Target Structure
- **OpenNotchCore** : Protocol, Registry, CommandRunner, modèles Yabai
- **OpenNotch** : App shell + YabaiModule (adapter sur AppModel)
- **YabaiBarSignalHelper** : CLI helper pour signals yabai

## YabaiModule (adapter pattern)
`YabaiModule` wraps `AppModel` via `weak var appModel: AppModel?`.
Il délègue toutes les queries à AppModel qui contient encore la logique Yabai.
Phase future : extraire la logique d'AppModel vers YabaiModule directement.
