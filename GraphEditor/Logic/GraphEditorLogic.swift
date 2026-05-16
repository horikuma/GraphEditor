import Foundation

struct EditorStatusInfo {
    let objectCountText: String
    let selectedShapeText: String
    let operationAxisText: String
    let operationValueText: String
}

struct LogicSnapshot {
    let shapes: [GraphShape]
    let selectedShapeIDs: Set<GraphShape.ID>
    let fillCircles: Bool
}

private struct InitialGraphGroups {
    let rootGroup: GraphShapeGroup
    let gridGroupID: GraphShapeGroup.ID
    let addedShapesGroupID: GraphShapeGroup.ID
}

final class GraphEditorLogic {
    var addableShapeKind = AddableShapeKind.circle
    var strokeColor = LogicColor.accent
    var lineWidth = 3.0
    var fillCircles = false

    private var rootGroup: GraphShapeGroup
    private var gridGroupID: GraphShapeGroup.ID
    private var addedShapesGroupID: GraphShapeGroup.ID
    private var selectedGroupID: GraphShapeGroup.ID?
    private var operationAxis = OperationAxis.shapeSelection

    init() {
        let initialState = Self.makeInitialGroups()
        rootGroup = initialState.rootGroup
        gridGroupID = initialState.gridGroupID
        addedShapesGroupID = initialState.addedShapesGroupID
        selectedGroupID = gridGroupID
    }

    var statusInfo: EditorStatusInfo {
        EditorStatusInfo(
            objectCountText: "\(rootGroup.shapeCount) objects / \(topLevelGroups.count) groups",
            selectedShapeText: "グループ: \(selectedShapeLabel)",
            operationAxisText: "軸: \(operationAxis.title)",
            operationValueText: "値: \(operationValueText)"
        )
    }

    var isClearDisabled: Bool {
        rootGroup.shapeCount == 0
    }

    var snapshot: LogicSnapshot {
        LogicSnapshot(
            shapes: rootGroup.flattenedShapes,
            selectedShapeIDs: selectedGroup?.shapeIDs ?? [],
            fillCircles: fillCircles
        )
    }

    func clear() {
        let initialState = Self.makeInitialGroups()
        rootGroup = initialState.rootGroup
        gridGroupID = initialState.gridGroupID
        addedShapesGroupID = initialState.addedShapesGroupID
        selectedGroupID = gridGroupID
        operationAxis = .shapeSelection
    }

    func appendShape(at location: LogicPoint, in size: LogicSize) {
        let clampedLocation = Self.clamp(location, in: size)

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
            selectPreviousAxis()
        case .right:
            selectNextAxis()
        case .arrowDown:
            applyLinearOperation(delta: -keyStep(for: modifiers))
        case .arrowUp:
            applyLinearOperation(delta: keyStep(for: modifiers))
        }

        return true
    }

    private var topLevelGroups: [GraphShapeGroup] {
        rootGroup.childGroups
    }

    private var selectedGroupIndex: Int? {
        guard let selectedGroupID else {
            return nil
        }

        return topLevelGroups.firstIndex { $0.id == selectedGroupID }
    }

    private var selectedGroup: GraphShapeGroup? {
        guard let selectedGroupID else {
            return nil
        }

        return rootGroup.group(id: selectedGroupID)
    }

    private var operationValueText: String {
        switch operationAxis {
        case .shapeSelection:
            if let selectedGroupIndex {
                return "\(selectedGroupIndex + 1) / \(topLevelGroups.count)"
            } else {
                return "なし"
            }
        case .xCoordinate, .yCoordinate, .width, .height, .spacing, .xOffset, .yOffset:
            guard
                let selectedGroup,
                let property = operationAxis.editableProperty
            else {
                return "なし"
            }

            return "\(Int(selectedGroup.value(for: property)))"
        }
    }

    private var selectedShapeLabel: String {
        guard let selectedGroup else {
            return "なし"
        }

        return selectedGroup.title
    }

    private func appendShape(_ shape: GraphShape) {
        let group = GraphShapeGroup.primitiveGroup(for: shape)
        rootGroup.appendChild(.group(group), toGroup: addedShapesGroupID)
        selectedGroupID = addedShapesGroupID
        operationAxis = .shapeSelection
    }

    private func selectPreviousAxis() {
        selectAxis(step: -1)
    }

    private func selectNextAxis() {
        selectAxis(step: 1)
    }

    private func applyLinearOperation(delta: Double) {
        guard !topLevelGroups.isEmpty else {
            selectedGroupID = nil
            return
        }

        ensureSelection()

        if operationAxis == .shapeSelection {
            moveSelection(by: delta > 0 ? 1 : -1)
            return
        }

        guard
            let selectedGroupID,
            let selectedGroup,
            let property = operationAxis.editableProperty,
            selectedGroup.supportedOperationAxes.contains(operationAxis)
        else {
            return
        }

        rootGroup.moveGroup(id: selectedGroupID, property: property, by: delta)
    }

    private func ensureSelection() {
        if selectedGroupID == nil || selectedGroupIndex == nil {
            selectedGroupID = topLevelGroups.first?.id
        }

        guard
            let selectedGroup,
            selectedGroup.supportedOperationAxes.contains(operationAxis)
        else {
            operationAxis = .shapeSelection
            return
        }
    }

    private func selectAxis(step: Int) {
        ensureSelection()

        let axes = selectedGroup?.supportedOperationAxes ?? [.shapeSelection]
        guard let currentIndex = axes.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + step + axes.count) % axes.count
        operationAxis = axes[nextIndex]
    }

    private func moveSelection(by delta: Int) {
        guard !topLevelGroups.isEmpty else {
            selectedGroupID = nil
            return
        }

        let currentIndex = selectedGroupIndex ?? 0
        let nextIndex = (currentIndex + delta + topLevelGroups.count) % topLevelGroups.count
        selectedGroupID = topLevelGroups[nextIndex].id
        operationAxis = .shapeSelection
    }

    private func keyStep(for modifiers: LogicKeyModifiers) -> Double {
        modifiers.isShiftPressed ? 10 : 1
    }

    private static func clamp(_ point: LogicPoint, in size: LogicSize) -> LogicPoint {
        LogicPoint(
            xCoordinate: min(max(point.xCoordinate, 0), size.width),
            yCoordinate: min(max(point.yCoordinate, 0), size.height)
        )
    }

    private static func makeInitialGroups() -> InitialGraphGroups {
        let grid = GraphShape.grid(DrawnGrid(origin: .zero, spacing: 24))
        let gridGroup = GraphShapeGroup(title: "初期グリッド", children: [.group(.primitiveGroup(for: grid))])
        let addedShapesGroup = GraphShapeGroup(title: "追加図形", children: [])
        let rootGroup = GraphShapeGroup(
            title: "ルート",
            children: [
                .group(gridGroup),
                .group(addedShapesGroup)
            ]
        )

        return InitialGraphGroups(
            rootGroup: rootGroup,
            gridGroupID: gridGroup.id,
            addedShapesGroupID: addedShapesGroup.id
        )
    }
}
