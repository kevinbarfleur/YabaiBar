import AppKit
import VibeNotchCore
import SwiftUI

struct TodoListExpandedContent: View {
    @ObservedObject var module: TodoListModule
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void

    @State private var newItemText = ""
    @State private var editingItemID: UUID?
    @State private var editingText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, isCollapsed ? 0 : 8)

            if !isCollapsed {
                inputField
                    .padding(.bottom, 8)

                itemsList
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, isCollapsed ? 6 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    onToggleCollapse()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Todo List")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.22))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))

                    if module.activeCount > 0 {
                        Text("\(module.activeCount)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Input

    private var inputField: some View {
        HStack(spacing: 6) {
            TextField("Add a task...", text: $newItemText)
                .textFieldStyle(.plain)
                .font(.system(size: module.fontSize, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
                .frame(height: module.fontSize + 4)
                .onSubmit {
                    submitItem()
                }

            if !newItemText.isEmpty {
                Button(action: submitItem) {
                    Image(systemName: "return")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.06))
        }
    }

    private func submitItem() {
        module.addItem(newItemText)
        newItemText = ""
    }

    // MARK: - Items List

    private var itemsList: some View {
        let activeItems = module.items.filter { !$0.isCompleted }
        let completedItems = module.items.filter { $0.isCompleted }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(activeItems) { item in
                activeRow(item)
            }

            if module.showCompleted && !completedItems.isEmpty {
                HStack(spacing: 0) {
                    Text("Completed")
                        .font(.system(size: max(9, module.fontSize - 1), weight: .medium))
                        .foregroundStyle(.white.opacity(0.22))

                    Spacer(minLength: 0)

                    Button {
                        module.clearCompleted()
                    } label: {
                        Text("Clear")
                            .font(.system(size: max(9, module.fontSize - 1), weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
                .padding(.bottom, 2)

                ForEach(completedItems) { item in
                    completedRow(item)
                }
            }
        }
    }

    // MARK: - Rows

    private func activeRow(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            if editingItemID == item.id {
                editField(item)
            } else {
                Button {
                    module.toggleItem(item.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: module.fontSize, weight: .regular))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(item.title)
                            .font(.system(size: module.fontSize, weight: .regular))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Button {
                        editingItemID = item.id
                        editingText = item.title
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: max(8, module.fontSize - 2), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                    .buttonStyle(.plain)

                    Button {
                        module.removeItem(item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: max(8, module.fontSize - 2), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func editField(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            TextField("", text: $editingText)
                .textFieldStyle(.plain)
                .font(.system(size: module.fontSize, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
                .onSubmit {
                    module.updateItemTitle(item.id, editingText)
                    editingItemID = nil
                }

            Button {
                module.updateItemTitle(item.id, editingText)
                editingItemID = nil
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: max(8, module.fontSize - 2), weight: .semibold))
                    .foregroundStyle(.green.opacity(0.6))
            }
            .buttonStyle(.plain)

            Button {
                editingItemID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: max(8, module.fontSize - 2), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.06))
        }
    }

    private func completedRow(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            Button {
                module.toggleItem(item.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: module.fontSize, weight: .regular))
                        .foregroundStyle(.green.opacity(0.6))

                    Text(item.title)
                        .font(.system(size: module.fontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.28))
                        .strikethrough(color: .white.opacity(0.18))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Settings View

struct TodoListSettingsView: View {
    @ObservedObject var module: TodoListModule

    var body: some View {
        Section {
            Picker("Font size", selection: fontSizeBinding) {
                Text("Small (9)").tag(9.0 as CGFloat)
                Text("Default (10)").tag(10.0 as CGFloat)
                Text("Medium (11)").tag(11.0 as CGFloat)
                Text("Large (12)").tag(12.0 as CGFloat)
                Text("X-Large (14)").tag(14.0 as CGFloat)
            }
        } header: {
            Text("Appearance")
        }

        Section {
            Toggle("Show completed", isOn: showCompletedBinding)
        } header: {
            Text("Display")
        }

        Section {
            Button("Clear completed (\(module.completedCount))") {
                module.clearCompleted()
            }
            .disabled(module.completedCount == 0)
        } header: {
            Text("Actions")
        }
    }

    private var fontSizeBinding: Binding<CGFloat> {
        Binding(get: { module.fontSize }, set: { module.fontSize = $0 })
    }

    private var showCompletedBinding: Binding<Bool> {
        Binding(get: { module.showCompleted }, set: { module.showCompleted = $0 })
    }
}
