import Foundation

struct EditorStatus {
    let objectCountText: String
    let selectedShapeText: String
    let operationAxisText: String
    let operationValueText: String
}

struct LogicSnapshot {
    let shapes: [DrawingShape]
    let selectedShapeIDs: Set<DrawingShape.ID>
}

struct GroupTreeRow: Identifiable {
    let id: UUID
    let depth: Int
    let title: String
    let detail: String
    let isGroup: Bool
    let isSelected: Bool
    let isSelectable: Bool
}

private struct InitialShapeTree {
    let rootGroup: ShapeGroup
    let initialSelectionID: UUID
}

final class GraphEditorStore {
    var addableShapeKind = AddableShapeKind.circle
    var strokeColor = LogicColor.accent

    private var rootGroup: ShapeGroup
    private var selectedNodeIDs: Set<UUID>
    private var nextGroupNumber = 1
    var operationAxis = OperationAxis.xCoordinate

    init() {
        let initialState = makeInitialShapeTree()
        rootGroup = initialState.rootGroup
        selectedNodeIDs = [initialState.initialSelectionID]
        normalizeOperationAxis()
    }

    var status: EditorStatus {
        EditorStatus(
            objectCountText: "\(rootGroup.shapeCount) objects / \(rootGroup.childGroups.count) groups",
            selectedShapeText: "グループ: \(selectedShapeLabel)",
            operationAxisText: "軸: \(operationAxis.title)",
            operationValueText: "値: \(operationValueText)"
        )
    }

    var groupTreeRows: [GroupTreeRow] {
        rows(for: rootGroup, depth: 0)
    }

    var selectedTreeNodeIDs: Set<UUID> {
        selectedNodeIDs
    }

    var canGroupSelection: Bool {
        selectedRootChildIndices.count >= 2
    }

    var canUngroupSelection: Bool {
        selectedRootChildIndices.contains { index in
            rootGroup.children[index].isGroup
        }
    }

    var isClearDisabled: Bool {
        rootGroup.shapeCount == 0
    }

    var snapshot: LogicSnapshot {
        LogicSnapshot(
            shapes: rootGroup.flattenedShapes,
            selectedShapeIDs: selectedShapeIDs
        )
    }

    func clear() {
        let initialState = makeInitialShapeTree()
        rootGroup = initialState.rootGroup
        selectedNodeIDs = [initialState.initialSelectionID]
        nextGroupNumber = 1
        normalizeOperationAxis()
    }

    func appendShape(at location: LogicPoint, in size: LogicSize) {
        let clampedLocation = clamp(location, in: size)
        appendShape(
            makeDrawingShape(
                kind: addableShapeKind,
                location: clampedLocation,
                color: strokeColor
            )
        )
    }

    func selectShape(at location: LogicPoint) {
        guard let selectedID = rootGroup.hitSelectableID(at: location) else {
            selectedNodeIDs.removeAll()
            normalizeOperationAxis()
            return
        }

        selectedNodeIDs = [selectedID]
        normalizeOperationAxis()
    }

    func handleKeyCommand(_ command: LogicKeyCommand, modifiers: LogicKeyModifiers) -> Bool {
        switch command {
        case .left:
            selectAxis(step: -1)
        case .right:
            selectAxis(step: 1)
        case .arrowDown:
            applyLinearOperation(delta: -keyStep(for: modifiers))
        case .arrowUp:
            applyLinearOperation(delta: keyStep(for: modifiers))
        }

        return true
    }

    func setTreeSelection(ids: Set<UUID>) {
        let selectableIDs = Set(rootGroup.children.map(\.id))
        selectedNodeIDs = ids.intersection(selectableIDs)
        normalizeOperationAxis()
    }

    func groupSelection() {
        let indices = selectedRootChildIndices
        guard indices.count >= 2 else {
            return
        }

        let selectedChildren = indices.map { rootGroup.children[$0] }
        for index in indices.reversed() {
            rootGroup.children.remove(at: index)
        }

        let group = ShapeGroup(title: "新規グループ\(nextGroupNumber)", children: selectedChildren)
        nextGroupNumber += 1
        rootGroup.children.append(.group(group))
        normalizeRootChildrenOrder()
        selectedNodeIDs = [group.id]
        normalizeOperationAxis()
    }

    func ungroupSelection() {
        let indices = selectedRootChildIndices.filter { rootGroup.children[$0].isGroup }
        guard !indices.isEmpty else {
            return
        }

        let ungroupedShapes = indices.flatMap { index in
            rootGroup.children[index].flattenedShapes.map(ShapeGroupElement.shape)
        }
        for index in indices.reversed() {
            rootGroup.children.remove(at: index)
        }

        rootGroup.children.append(contentsOf: ungroupedShapes)
        selectedNodeIDs = Set(ungroupedShapes.flatMap(\.shapeIDs))
        normalizeOperationAxis()
    }

    private var operationValueText: String {
        guard let selectedGroup = editingGroup else {
            return "なし"
        }

        return operationValueText(for: operationAxis, in: selectedGroup)
    }

    private var selectedShapeLabel: String {
        guard let selectedGroup = editingGroup else {
            return "なし"
        }

        return selectedGroup.title
    }

    private func appendShape(_ shape: DrawingShape) {
        rootGroup.children.append(.shape(shape))
        selectedNodeIDs = [shape.id]
        normalizeOperationAxis()
    }

    private func applyLinearOperation(delta: Double) {
        guard !rootGroup.children.isEmpty else {
            selectedNodeIDs.removeAll()
            return
        }

        ensureSelection()

        guard
            let selectedGroup = editingGroup,
            let property = operationAxis.editableProperty,
            ShapeGroupEditing.supportedOperationAxes(for: selectedGroup).contains(operationAxis)
        else {
            return
        }

        ShapeGroupEditing.moveNodes(ids: selectedNodeIDs, property: property, by: delta, in: &rootGroup)
    }

    private func ensureSelection() {
        if selectedNodeIDs.isEmpty || selectedRootChildIndices.isEmpty {
            selectedNodeIDs = rootGroup.children.first.map { [$0.id] } ?? []
        }

        guard
            let selectedGroup = editingGroup,
            ShapeGroupEditing.supportedOperationAxes(for: selectedGroup).contains(operationAxis)
        else {
            normalizeOperationAxis()
            return
        }
    }

    private func selectAxis(step: Int) {
        ensureSelection()

        let axes = editingGroup.map(ShapeGroupEditing.supportedOperationAxes) ?? []
        guard !axes.isEmpty else {
            return
        }
        guard let currentIndex = axes.firstIndex(of: operationAxis) else {
            operationAxis = axes[0]
            return
        }

        let nextIndex = (currentIndex + step + axes.count) % axes.count
        operationAxis = axes[nextIndex]
    }

    private func keyStep(for modifiers: LogicKeyModifiers) -> Double {
        modifiers.isShiftPressed ? 10 : 1
    }

    private func normalizeOperationAxis() {
        let axes = editingGroup.map(ShapeGroupEditing.supportedOperationAxes) ?? []
        if let axis = axes.first {
            operationAxis = axis
        }
    }

    private func normalizeRootChildrenOrder() {
        rootGroup.children = rootGroup.children.filter(\.isGroup) + rootGroup.children.filter { !$0.isGroup }
    }

    private var selectedRootChildIndices: [Int] {
        rootGroup.children.indices.filter { selectedNodeIDs.contains(rootGroup.children[$0].id) }
    }

    private var selectedShapeIDs: Set<DrawingShape.ID> {
        Set(selectedRootChildIndices.flatMap { rootGroup.children[$0].shapeIDs })
    }

    var editingGroup: ShapeGroup? {
        let selectedElements = selectedRootChildIndices.map { rootGroup.children[$0] }
        guard !selectedElements.isEmpty else {
            return nil
        }

        if selectedElements.count == 1, case let .group(group) = selectedElements[0] {
            return group
        }

        return ShapeGroup(title: "選択", children: selectedElements)
    }

    private func rows(for group: ShapeGroup, depth: Int) -> [GroupTreeRow] {
        let row = GroupTreeRow(
            id: group.id,
            depth: depth,
            title: group.title,
            detail: "\(group.shapeCount) objects",
            isGroup: true,
            isSelected: selectedNodeIDs.contains(group.id),
            isSelectable: depth == 1
        )

        return [row] + group.children.flatMap { rows(for: $0, depth: depth + 1) }
    }

    private func rows(for element: ShapeGroupElement, depth: Int) -> [GroupTreeRow] {
        switch element {
        case let .group(group):
            return rows(for: group, depth: depth)
        case let .shape(shape):
            return [
                GroupTreeRow(
                    id: shape.id,
                    depth: depth,
                    title: shape.title,
                    detail: "primitive",
                    isGroup: false,
                    isSelected: selectedNodeIDs.contains(shape.id),
                    isSelectable: depth == 1
                )
            ]
        }
    }

}

private func clamp(_ point: LogicPoint, in size: LogicSize) -> LogicPoint {
    LogicPoint(
        xCoordinate: min(max(point.xCoordinate, 0), size.width),
        yCoordinate: min(max(point.yCoordinate, 0), size.height)
    )
}

private func makeDrawingShape(
    kind: AddableShapeKind,
    location: LogicPoint,
    color: LogicColor
) -> DrawingShape {
    switch kind {
    case .circle:
        return .circle(
            DrawnCircle(
                center: location,
                diameter: 48,
                color: color
            )
        )
    case .rectangle:
        return .rectangle(
            DrawnRectangle(
                center: location,
                size: LogicSize(width: 72, height: 48),
                color: color
            )
        )
    }
}

private func makeInitialShapeTree() -> InitialShapeTree {
    let grid = DrawingShape.grid(DrawnGrid(origin: .zero, spacing: 24))
    let rootGroup = ShapeGroup(
        title: "ルート",
        children: [.shape(grid)]
    )

    return InitialShapeTree(
        rootGroup: rootGroup,
        initialSelectionID: grid.id
    )
}
