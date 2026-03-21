import Combine
import Foundation

@MainActor
public final class ModuleRegistry: ObservableObject {
    @Published public private(set) var modules: [any OpenNotchModule] = []
    @Published public var enabledModuleIDs: Set<String> {
        didSet { persistEnabledModules() }
    }
    @Published public var widgetOrder: [String] {
        didSet { persistWidgetOrder() }
    }
    @Published public var leadingSlotOrder: [String] {
        didSet { persistLeadingSlotOrder() }
    }
    @Published public var trailingSlotOrder: [String] {
        didSet { persistTrailingSlotOrder() }
    }
    @Published public var disabledSlotIDs: Set<String> {
        didSet { persistDisabledSlots() }
    }
    @Published public var activeStatusBarModuleID: String? {
        didSet { persistActiveStatusBarModule() }
    }

    private let defaults: UserDefaults

    private enum DefaultsKey {
        static let enabledModules = "OpenNotch.enabledModuleIDs"
        static let widgetOrder = "OpenNotch.widgetOrder"
        static let leadingSlotOrder = "OpenNotch.leadingSlotOrder"
        static let trailingSlotOrder = "OpenNotch.trailingSlotOrder"
        static let disabledSlotIDs = "OpenNotch.disabledSlotIDs"
        static let activeStatusBarModule = "OpenNotch.activeStatusBarModuleID"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabledModuleIDs = Set(defaults.stringArray(forKey: DefaultsKey.enabledModules) ?? [])
        self.widgetOrder = defaults.stringArray(forKey: DefaultsKey.widgetOrder) ?? []
        self.leadingSlotOrder = defaults.stringArray(forKey: DefaultsKey.leadingSlotOrder) ?? []
        self.trailingSlotOrder = defaults.stringArray(forKey: DefaultsKey.trailingSlotOrder) ?? []
        self.disabledSlotIDs = Set(defaults.stringArray(forKey: DefaultsKey.disabledSlotIDs) ?? [])
        self.activeStatusBarModuleID = defaults.string(forKey: DefaultsKey.activeStatusBarModule)
    }

    // MARK: - Registration

    public func register(_ module: any OpenNotchModule) {
        modules.append(module)
        let id = module.identifier.rawValue

        if enabledModuleIDs.isEmpty, modules.count == 1 {
            enabledModuleIDs.insert(id)
        }

        if activeStatusBarModuleID == nil {
            activeStatusBarModuleID = id
        }

        if !widgetOrder.contains(id) {
            widgetOrder.append(id)
        }

        let leadingID = slotID(id, side: .leading)
        if !leadingSlotOrder.contains(leadingID) {
            leadingSlotOrder.append(leadingID)
        }

        let trailingID = slotID(id, side: .trailing)
        if !trailingSlotOrder.contains(trailingID) {
            trailingSlotOrder.append(trailingID)
        }

        if enabledModuleIDs.contains(id) {
            module.activate()
        }
    }

    // MARK: - Modules

    public var enabledModules: [any OpenNotchModule] {
        modules.filter { enabledModuleIDs.contains($0.identifier.rawValue) }
    }

    public var activeStatusBarModule: (any OpenNotchModule)? {
        guard let id = activeStatusBarModuleID else { return nil }
        return enabledModules.first { $0.identifier.rawValue == id }
    }

    public func setEnabled(_ moduleID: ModuleIdentifier, _ enabled: Bool) {
        let id = moduleID.rawValue
        if enabled {
            enabledModuleIDs.insert(id)
            modules.first { $0.identifier == moduleID }?.activate()
        } else {
            enabledModuleIDs.remove(id)
            modules.first { $0.identifier == moduleID }?.deactivate()
        }
    }

    public func isEnabled(_ moduleID: ModuleIdentifier) -> Bool {
        enabledModuleIDs.contains(moduleID.rawValue)
    }

    // MARK: - Widget Order

    public func moveWidgetUp(_ moduleID: String) {
        guard let index = widgetOrder.firstIndex(of: moduleID), index > 0 else { return }
        widgetOrder.swapAt(index, index - 1)
    }

    public func moveWidgetDown(_ moduleID: String) {
        guard let index = widgetOrder.firstIndex(of: moduleID), index < widgetOrder.count - 1 else { return }
        widgetOrder.swapAt(index, index + 1)
    }

    public func orderedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        let allWidgets = enabledModules.flatMap { $0.expandedWidgets(for: displayUUID) }
        return allWidgets.sorted { lhs, rhs in
            let lhsIndex = widgetOrder.firstIndex(of: lhs.moduleID.rawValue) ?? Int.max
            let rhsIndex = widgetOrder.firstIndex(of: rhs.moduleID.rawValue) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    // MARK: - Slot Order & Visibility

    public enum SlotSide: String {
        case leading, trailing
    }

    public func slotID(_ moduleID: String, side: SlotSide) -> String {
        "\(moduleID).\(side.rawValue)"
    }

    public func moduleID(from slotID: String) -> String? {
        if slotID.hasSuffix(".leading") {
            return String(slotID.dropLast(".leading".count))
        }
        if slotID.hasSuffix(".trailing") {
            return String(slotID.dropLast(".trailing".count))
        }
        return nil
    }

    public func isSlotEnabled(_ slotID: String) -> Bool {
        !disabledSlotIDs.contains(slotID)
    }

    public func setSlotEnabled(_ slotID: String, _ enabled: Bool) {
        if enabled {
            disabledSlotIDs.remove(slotID)
        } else {
            disabledSlotIDs.insert(slotID)
        }
    }

    public func moveSlotUp(_ slotID: String, side: SlotSide) {
        switch side {
        case .leading:
            guard let index = leadingSlotOrder.firstIndex(of: slotID), index > 0 else { return }
            leadingSlotOrder.swapAt(index, index - 1)
        case .trailing:
            guard let index = trailingSlotOrder.firstIndex(of: slotID), index > 0 else { return }
            trailingSlotOrder.swapAt(index, index - 1)
        }
    }

    public func moveSlotDown(_ slotID: String, side: SlotSide) {
        switch side {
        case .leading:
            guard let index = leadingSlotOrder.firstIndex(of: slotID), index < leadingSlotOrder.count - 1 else { return }
            leadingSlotOrder.swapAt(index, index + 1)
        case .trailing:
            guard let index = trailingSlotOrder.firstIndex(of: slotID), index < trailingSlotOrder.count - 1 else { return }
            trailingSlotOrder.swapAt(index, index + 1)
        }
    }

    public func slotLabel(for slotID: String) -> String {
        guard let modID = moduleID(from: slotID),
              let module = modules.first(where: { $0.identifier.rawValue == modID }) else {
            return slotID
        }
        return module.displayName
    }

    public func aggregatedLeadingSlots(for displayUUID: String) -> [NotchSlotContent] {
        orderedSlots(for: displayUUID, side: .leading, order: leadingSlotOrder) { module, uuid in
            module.closedLeadingView(for: uuid)
        }
    }

    public func aggregatedTrailingSlots(for displayUUID: String) -> [NotchSlotContent] {
        orderedSlots(for: displayUUID, side: .trailing, order: trailingSlotOrder) { module, uuid in
            module.closedTrailingView(for: uuid)
        }
    }

    private func orderedSlots(
        for displayUUID: String,
        side: SlotSide,
        order: [String],
        slotProvider: (any OpenNotchModule, String) -> NotchSlotContent?
    ) -> [NotchSlotContent] {
        let enabledIDs = order.filter { sid in
            guard let modID = moduleID(from: sid) else { return false }
            return isEnabled(ModuleIdentifier(modID)) && isSlotEnabled(sid)
        }

        return enabledIDs.compactMap { sid -> NotchSlotContent? in
            guard let modID = moduleID(from: sid),
                  let module = modules.first(where: { $0.identifier.rawValue == modID }) else {
                return nil
            }
            return slotProvider(module, displayUUID)
        }
    }

    // MARK: - Refresh

    public func refreshAll() {
        enabledModules.forEach { $0.refresh() }
    }

    // MARK: - Persistence

    private func persistEnabledModules() {
        defaults.set(Array(enabledModuleIDs), forKey: DefaultsKey.enabledModules)
    }

    private func persistWidgetOrder() {
        defaults.set(widgetOrder, forKey: DefaultsKey.widgetOrder)
    }

    private func persistLeadingSlotOrder() {
        defaults.set(leadingSlotOrder, forKey: DefaultsKey.leadingSlotOrder)
    }

    private func persistTrailingSlotOrder() {
        defaults.set(trailingSlotOrder, forKey: DefaultsKey.trailingSlotOrder)
    }

    private func persistDisabledSlots() {
        defaults.set(Array(disabledSlotIDs), forKey: DefaultsKey.disabledSlotIDs)
    }

    private func persistActiveStatusBarModule() {
        defaults.set(activeStatusBarModuleID, forKey: DefaultsKey.activeStatusBarModule)
    }
}
