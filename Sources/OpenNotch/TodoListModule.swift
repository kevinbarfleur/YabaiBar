import AppKit
import Combine
import OpenNotchCore
import SwiftUI

struct TodoItem: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
}

@MainActor
final class TodoListModule: ObservableObject, OpenNotchModule {
    let identifier = ModuleIdentifier("com.opennotch.todolist")
    let displayName = "Todo List"
    let icon = "checklist"

    var objectDidChange: (() -> Void)?

    @Published private(set) var items: [TodoItem] = []

    var activeCount: Int { items.filter { !$0.isCompleted }.count }
    var completedCount: Int { items.filter { $0.isCompleted }.count }

    private enum DefaultsKey {
        static let items = "TodoList.items"
    }

    init() {
        loadItems()
    }

    // MARK: - CRUD

    func addItem(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(id: UUID(), title: trimmed, isCompleted: false, createdAt: Date()), at: 0)
        saveItems()
        objectDidChange?()
    }

    func toggleItem(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        saveItems()
        objectDidChange?()
    }

    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
        objectDidChange?()
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted }
        saveItems()
        objectDidChange?()
    }

    // MARK: - Persistence

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.items),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: DefaultsKey.items)
        }
    }

    // MARK: - Lifecycle

    func activate() {}
    func deactivate() {}
    func refresh() {}
    func displayChanged() {}

    // MARK: - Module Content

    func closedLeadingView(for displayUUID: String) -> NotchSlotContent? { nil }

    func closedTrailingView(for displayUUID: String) -> NotchSlotContent? {
        guard activeCount > 0 else { return nil }
        return NotchSlotContent(
            view: AnyView(
                Text("\(activeCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
            ),
            width: 14
        )
    }

    func expandedWidgets(for displayUUID: String) -> [NotchExpandedWidget] {
        let widgetID = "todolist-widget"
        let collapsed = isWidgetCollapsed(widgetID)

        let headerHeight: CGFloat = 32
        let padding: CGFloat = 23
        let inputHeight: CGFloat = 30

        var contentHeight: CGFloat = 0
        if collapsed {
            return [
                NotchExpandedWidget(
                    id: widgetID,
                    moduleID: identifier,
                    estimatedHeight: 40,
                    content: AnyView(
                        TodoListExpandedContent(
                            module: self,
                            isCollapsed: true,
                            onToggleCollapse: { [weak self] in
                                setWidgetCollapsed(widgetID, false)
                                self?.objectDidChange?()
                            }
                        )
                    )
                ),
            ]
        }

        let activeItems = items.filter { !$0.isCompleted }
        let completedItems = items.filter { $0.isCompleted }
        contentHeight += inputHeight
        contentHeight += CGFloat(activeItems.count) * 24
        if !completedItems.isEmpty {
            contentHeight += 20 + CGFloat(completedItems.count) * 24
        }

        let estimatedHeight = headerHeight + contentHeight + padding

        return [
            NotchExpandedWidget(
                id: widgetID,
                moduleID: identifier,
                estimatedHeight: estimatedHeight,
                content: AnyView(
                    TodoListExpandedContent(
                        module: self,
                        isCollapsed: false,
                        onToggleCollapse: { [weak self] in
                            setWidgetCollapsed(widgetID, true)
                            self?.objectDidChange?()
                        }
                    )
                )
            ),
        ]
    }

    func statusBarContent() -> StatusBarContent? { nil }
    func menuSections() -> [ModuleMenuSection] { [] }
    func makeSettingsView() -> AnyView? { nil }
}
