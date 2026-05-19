import SwiftUI

extension ContentView {
    var treeSelection: Binding<Set<UUID>> {
        Binding(
            get: {
                bridge.selectedTreeNodeIDs
            },
            set: { newValue in
                focusedPane = .tree
                bridge.selectedTreeNodeIDs = newValue
            }
        )
    }

    var operationAxisSelection: Binding<OperationAxis?> {
        Binding(
            get: {
                bridge.selectedOperationAxisID
            },
            set: { newValue in
                guard let newValue else {
                    return
                }

                focusedPane = .operationAxis
                bridge.selectOperationAxis(newValue)
            }
        )
    }

    var groupTreePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupTreeHeader
            Divider()
            groupToolbar
            Divider()
            groupTreeList
            Divider()
            operationAxisPanel
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var groupTreeHeader: some View {
        Text("Group Tree")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private var groupToolbar: some View {
        HStack(spacing: 8) {
            Button {
                bridge.groupSelection()
            } label: {
                Label("Group", systemImage: "folder.badge.plus")
            }
            .disabled(!bridge.canGroupSelection)

            Button {
                bridge.ungroupSelection()
            } label: {
                Label("Ungroup", systemImage: "folder.badge.minus")
            }
            .disabled(!bridge.canUngroupSelection)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var groupTreeList: some View {
        List(selection: treeSelection) {
            ForEach(bridge.groupTreeRows) { row in
                groupTreeRow(row)
                    .tag(row.id)
                    .selectionDisabled(!row.isSelectable)
            }
        }
        .listStyle(.sidebar)
        .background(
            TreeReturnKeyHandlingView {
                focusedPane = .graph
                graphFocusRequest += 1
            }
        )
        .overlay {
            focusRing(isFocused: focusedPane == .tree)
        }
    }

    var operationAxisPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Operation Axes")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            List(selection: operationAxisSelection) {
                ForEach(bridge.operationAxisRows) { row in
                    operationAxisRow(row)
                        .tag(row.id)
                }
            }
            .frame(minHeight: 120, maxHeight: 180)
            .listStyle(.sidebar)
            .overlay {
                focusRing(isFocused: focusedPane == .operationAxis)
            }
        }
    }

    private func groupTreeRow(_ row: GroupTreeRow) -> some View {
        HStack(spacing: 6) {
            Image(systemName: row.isGroup ? "folder" : "circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(row.isGroup ? Color.primary : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                Text(row.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(row.depth * 14) + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .selectedRowBackground(isSelected: row.isSelected, isFocused: focusedPane == .tree)
        .opacity(row.isSelectable ? 1 : 0.72)
    }

    private func operationAxisRow(_ row: OperationAxisRow) -> some View {
        HStack(spacing: 8) {
            Text(row.title)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(row.valueText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .selectedRowBackground(isSelected: row.isSelected, isFocused: focusedPane == .operationAxis)
    }
}

private extension View {
    func selectedRowBackground(isSelected: Bool, isFocused: Bool) -> some View {
        background {
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(isFocused ? 0.18 : 0.10))
            }
        }
        .overlay {
            if isSelected, !isFocused {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
            }
        }
    }
}
