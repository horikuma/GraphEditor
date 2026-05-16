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
    let fillCircles: Bool
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

final class GraphEditorLogic {
    var addableShapeKind = AddableShapeKind.circle
    var strokeColor = LogicColor.accent
    var lineWidth = 3.0
    var fillCircles = false

    private var rootGroup: ShapeGroup
    private var selectedNodeIDs: Set<UUID>
    private var nextGroupNumber = 1
    private var operationAxis = OperationAxis.shapeSelection

    init() {
        let initialState = makeInitialShapeTree()
        rootGroup = initialState.rootGroup
        selectedNodeIDs = [initialState.initialSelectionID]
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
            selectedShapeIDs: selectedShapeIDs,
            fillCircles: fillCircles
        )
    }

    func clear() {
        let initialState = makeInitialShapeTree()
        rootGroup = initialState.rootGroup
        selectedNodeIDs = [initialState.initialSelectionID]
        nextGroupNumber = 1
        operationAxis = .shapeSelection
    }

    func appendShape(at location: LogicPoint, in size: LogicSize) {
        let clampedLocation = clamp(location, in: size)

        switch addableShapeKind {
        case .circle:
            appendShape(
                .circle(
                    DrawnCircle(
                        center: clampedLocation,
                        diameter: 48,
                        color: strokeColor,
                        lineWidth: lineWidth
                    )
                )
            )
        case .grid:
            appendShape(.grid(DrawnGrid(origin: clampedLocation, spacing: 24)))
        }
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

    func toggleTreeSelection(id: UUID) {
        guard rootGroup.id != id else {
            return
        }

        if selectedNodeIDs.contains(id) {
            selectedNodeIDs.remove(id)
        } else {
            selectedNodeIDs.insert(id)
        }

        operationAxis = .shapeSelection
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
        operationAxis = .shapeSelection
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
        operationAxis = .shapeSelection
    }

    private var operationValueText: String {
        switch operationAxis {
        case .shapeSelection:
            return "\(selectedNodeIDs.count) selected"
        case .xCoordinate, .yCoordinate, .width, .height, .spacing, .xOffset, .yOffset:
            guard
                let selectedGroup = editingGroup,
                let property = operationAxis.editableProperty
            else {
                return "なし"
            }

            return "\(Int(ShapeGroupEditing.value(for: property, in: selectedGroup)))"
        }
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
        operationAxis = .shapeSelection
    }

    private func applyLinearOperation(delta: Double) {
        guard !rootGroup.children.isEmpty else {
            selectedNodeIDs.removeAll()
            return
        }

        ensureSelection()

        if operationAxis == .shapeSelection {
            moveSelection(by: delta > 0 ? 1 : -1)
            return
        }

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
            operationAxis = .shapeSelection
            return
        }
    }

    private func selectAxis(step: Int) {
        ensureSelection()

        let axes = editingGroup.map(ShapeGroupEditing.supportedOperationAxes) ?? [.shapeSelection]
        guard let currentIndex = axes.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + step + axes.count) % axes.count
        operationAxis = axes[nextIndex]
    }

    private func moveSelection(by delta: Int) {
        guard !rootGroup.children.isEmpty else {
            selectedNodeIDs.removeAll()
            return
        }

        let currentIndex = selectedRootChildIndices.first ?? 0
        let nextIndex = (currentIndex + delta + rootGroup.children.count) % rootGroup.children.count
        selectedNodeIDs = [rootGroup.children[nextIndex].id]
        operationAxis = .shapeSelection
    }

    private func keyStep(for modifiers: LogicKeyModifiers) -> Double {
        modifiers.isShiftPressed ? 10 : 1
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

    private var editingGroup: ShapeGroup? {
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
