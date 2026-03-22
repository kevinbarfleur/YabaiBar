import AppKit
import OpenNotchCore
import SwiftUI

struct TodoListExpandedContent: View {
    @ObservedObject var module: TodoListModule
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void

    @State private var newItemText = ""

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
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCollapsed)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onToggleCollapse) {
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
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
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

            if !completedItems.isEmpty {
                HStack(spacing: 0) {
                    Text("Completed")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.22))

                    Spacer(minLength: 0)

                    Button {
                        module.clearCompleted()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 9, weight: .medium))
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
            Button {
                module.toggleItem(item.id)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                module.removeItem(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    private func completedRow(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            Button {
                module.toggleItem(item.id)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.green.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.28))
                .strikethrough(color: .white.opacity(0.18))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
