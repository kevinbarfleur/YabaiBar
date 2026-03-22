import AppKit
import SwiftUI

public struct ModuleIdentifier: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct NotchSlotContent: @unchecked Sendable {
    public let view: AnyView
    public let width: CGFloat

    public init(view: AnyView, width: CGFloat) {
        self.view = view
        self.width = width
    }
}

public struct NotchExpandedWidget: Identifiable {
    public let id: String
    public let moduleID: ModuleIdentifier
    public let estimatedHeight: CGFloat
    public let content: AnyView

    public init(id: String, moduleID: ModuleIdentifier, estimatedHeight: CGFloat, content: AnyView) {
        self.id = id
        self.moduleID = moduleID
        self.estimatedHeight = estimatedHeight
        self.content = content
    }
}

public struct StatusBarContent {
    public let icon: NSImage?
    public let label: String?
    public let tooltip: String?
    public let length: CGFloat

    public init(icon: NSImage?, label: String?, tooltip: String?, length: CGFloat) {
        self.icon = icon
        self.label = label
        self.tooltip = tooltip
        self.length = length
    }
}

public struct ModuleMenuSection {
    public let title: String?
    public let items: [NSMenuItem]

    public init(title: String? = nil, items: [NSMenuItem]) {
        self.title = title
        self.items = items
    }
}

@MainActor
public protocol VibeNotchModule: AnyObject {
    var identifier: ModuleIdentifier { get }
    var displayName: String { get }
    var icon: String { get }

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

// MARK: - Default Implementations

public extension VibeNotchModule {
    func activate() {}
    func deactivate() {}
    func refresh() {}
    func displayChanged() {}
    func closedLeadingView(for displayUUID: String) -> NotchSlotContent? { nil }
    func closedTrailingView(for displayUUID: String) -> NotchSlotContent? { nil }
    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] { [] }
    func statusBarContent() -> StatusBarContent? { nil }
    func menuSections() -> [ModuleMenuSection] { [] }
    func makeSettingsView() -> AnyView? { nil }
}
