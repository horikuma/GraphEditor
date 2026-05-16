import Foundation

struct EditorStatusInfo {
    let objectCountText: String
    let selectedShapeText: String
    let operationAxisText: String
    let operationValueText: String
}

struct LogicSnapshot {
    let shapes: [GraphShape]
    let selectedShapeID: GraphShape.ID?
    let fillCircles: Bool
}

final class GraphEditorLogic {
    var addableShapeKind = AddableShapeKind.circle
    var strokeColor = LogicColor.accent
    var lineWidth = 3.0
    var fillCircles = false

    private var shapes: [GraphShape]
    private var selectedShapeID: GraphShape.ID?
    private var operationAxis = OperationAxis.shapeSelection

    init() {
        let grid = GraphShape.grid(DrawnGrid(origin: .zero, spacing: 24))
        shapes = [grid]
        selectedShapeID = grid.id
    }

    var statusInfo: EditorStatusInfo {
        EditorStatusInfo(
            objectCountText: "\(shapes.count) objects",
            selectedShapeText: "図形: \(selectedShapeLabel)",
            operationAxisText: "軸: \(operationAxis.title)",
            operationValueText: "値: \(operationValueText)"
        )
    }

    var isClearDisabled: Bool {
        shapes.isEmpty
    }

    var snapshot: LogicSnapshot {
        LogicSnapshot(shapes: shapes, selectedShapeID: selectedShapeID, fillCircles: fillCircles)
    }

    func clear() {
        let grid = GraphShape.grid(DrawnGrid(origin: .zero, spacing: 24))
        shapes = [grid]
        selectedShapeID = grid.id
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

    private var selectedShapeIndex: Int? {
        guard let selectedShapeID else {
            return nil
        }

        return shapes.firstIndex { $0.id == selectedShapeID }
    }

    private var selectedShape: GraphShape? {
        guard let selectedShapeIndex else {
            return nil
        }

        return shapes[selectedShapeIndex]
    }

    private var operationValueText: String {
        switch operationAxis {
        case .shapeSelection:
            if let selectedShapeIndex {
                return "\(selectedShapeIndex + 1) / \(shapes.count)"
            } else {
                return "なし"
            }
        case .xCoordinate, .yCoordinate, .width, .height, .spacing, .xOffset, .yOffset:
            guard
                let selectedShapeIndex,
                let property = operationAxis.editableProperty
            else {
                return "なし"
            }

            return "\(Int(shapes[selectedShapeIndex].value(for: property)))"
        }
    }

    private var selectedShapeLabel: String {
        guard let selectedShapeIndex else {
            return "なし"
        }

        return shapes[selectedShapeIndex].title
    }

    private func appendShape(_ shape: GraphShape) {
        shapes.append(shape)
        selectedShapeID = shape.id
        operationAxis = .shapeSelection
    }

    private func selectPreviousAxis() {
        selectAxis(step: -1)
    }

    private func selectNextAxis() {
        selectAxis(step: 1)
    }

    private func applyLinearOperation(delta: Double) {
        guard !shapes.isEmpty else {
            selectedShapeID = nil
            return
        }

        ensureSelection()

        if operationAxis == .shapeSelection {
            moveSelection(by: delta > 0 ? 1 : -1)
            return
        }

        guard
            let selectedShapeIndex,
            let property = operationAxis.editableProperty,
            shapes[selectedShapeIndex].supportedOperationAxes.contains(operationAxis)
        else {
            return
        }

        shapes[selectedShapeIndex].move(property: property, by: delta)
    }

    private func ensureSelection() {
        if selectedShapeID == nil || selectedShapeIndex == nil {
            selectedShapeID = shapes[0].id
        }

        guard
            let selectedShape,
            selectedShape.supportedOperationAxes.contains(operationAxis)
        else {
            operationAxis = .shapeSelection
            return
        }
    }

    private func selectAxis(step: Int) {
        ensureSelection()

        let axes = selectedShape?.supportedOperationAxes ?? [.shapeSelection]
        guard let currentIndex = axes.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + step + axes.count) % axes.count
        operationAxis = axes[nextIndex]
    }

    private func moveSelection(by delta: Int) {
        guard !shapes.isEmpty else {
            selectedShapeID = nil
            return
        }

        let currentIndex = selectedShapeIndex ?? 0
        let nextIndex = (currentIndex + delta + shapes.count) % shapes.count
        selectedShapeID = shapes[nextIndex].id
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
}
