import SwiftUI

enum AddableShapeKind: String, CaseIterable, Identifiable {
    case circle
    case grid

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .circle:
            return "円"
        case .grid:
            return "グリッド"
        }
    }
}

struct DrawnCircle: Identifiable, EditableShape {
    let id = UUID()
    var center: CGPoint
    var diameter: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var centroid: CGPoint {
        center
    }

    var supportedOperationAxes: [OperationAxis] {
        [.shapeSelection, .xCoordinate, .yCoordinate, .width, .height]
    }

    var rect: CGRect {
        CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    func value(for property: ShapeEditableProperty) -> CGFloat {
        switch property {
        case .xCoordinate:
            return center.x
        case .yCoordinate:
            return center.y
        case .width:
            return diameter
        case .height:
            return diameter
        case .spacing, .xOffset, .yOffset:
            return 0
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: CGFloat) {
        switch property {
        case .xCoordinate:
            center.x += delta
        case .yCoordinate:
            center.y -= delta
        case .width, .height:
            diameter = max(4, diameter + delta)
        case .spacing, .xOffset, .yOffset:
            break
        }
    }
}

struct DrawnGrid: Identifiable, EditableShape {
    let id = UUID()
    var origin: CGPoint
    var spacing: CGFloat

    var centroid: CGPoint {
        origin
    }

    var supportedOperationAxes: [OperationAxis] {
        [.shapeSelection, .spacing, .xOffset, .yOffset]
    }

    func value(for property: ShapeEditableProperty) -> CGFloat {
        switch property {
        case .spacing:
            return spacing
        case .xOffset:
            return origin.x
        case .yOffset:
            return origin.y
        case .xCoordinate, .yCoordinate, .width, .height:
            return 0
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: CGFloat) {
        switch property {
        case .spacing:
            spacing = max(4, spacing + delta)
        case .xOffset:
            origin.x += delta
        case .yOffset:
            origin.y -= delta
        case .xCoordinate, .yCoordinate, .width, .height:
            break
        }
    }
}

enum GraphShape: Identifiable {
    case circle(DrawnCircle)
    case grid(DrawnGrid)

    var id: UUID {
        switch self {
        case let .circle(circle):
            return circle.id
        case let .grid(grid):
            return grid.id
        }
    }

    var title: String {
        switch self {
        case .circle:
            return "円"
        case .grid:
            return "グリッド"
        }
    }

    var isGrid: Bool {
        if case .grid = self {
            return true
        }

        return false
    }

    var showsCentroidCrossByDefault: Bool {
        switch self {
        case .circle:
            return true
        case .grid:
            return false
        }
    }

    var centroid: CGPoint {
        switch self {
        case let .circle(circle):
            return circle.centroid
        case let .grid(grid):
            return grid.centroid
        }
    }

    var supportedOperationAxes: [OperationAxis] {
        switch self {
        case let .circle(circle):
            return circle.supportedOperationAxes
        case let .grid(grid):
            return grid.supportedOperationAxes
        }
    }

    func value(for property: ShapeEditableProperty) -> CGFloat {
        switch self {
        case let .circle(circle):
            return circle.value(for: property)
        case let .grid(grid):
            return grid.value(for: property)
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: CGFloat) {
        switch self {
        case var .circle(circle):
            circle.move(property: property, by: delta)
            self = .circle(circle)
        case var .grid(grid):
            grid.move(property: property, by: delta)
            self = .grid(grid)
        }
    }
}

struct GraphEditorContent {
    var shapes: [GraphShape]
    var selectedShapeID: GraphShape.ID?
    var operationAxis = OperationAxis.shapeSelection
    var addableShapeKind = AddableShapeKind.circle

    init() {
        let grid = GraphShape.grid(DrawnGrid(origin: .zero, spacing: 24))
        shapes = [grid]
        selectedShapeID = grid.id
    }

    var selectedShapeIndex: Int? {
        guard let selectedShapeID else {
            return nil
        }

        return shapes.firstIndex { $0.id == selectedShapeID }
    }

    var selectedShape: GraphShape? {
        guard let selectedShapeIndex else {
            return nil
        }

        return shapes[selectedShapeIndex]
    }

    var operationValueText: String {
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

    var selectedShapeLabel: String {
        guard let selectedShapeIndex else {
            return "なし"
        }

        return shapes[selectedShapeIndex].title
    }

    mutating func appendCircle(_ circle: DrawnCircle) {
        appendShape(.circle(circle))
    }

    mutating func appendGrid(_ grid: DrawnGrid) {
        appendShape(.grid(grid))
    }

    mutating func clear() {
        shapes = [.grid(DrawnGrid(origin: .zero, spacing: 24))]
        selectedShapeID = shapes.first?.id
        operationAxis = .shapeSelection
    }

    mutating func selectPreviousAxis() {
        selectAxis(step: -1)
    }

    mutating func selectNextAxis() {
        selectAxis(step: 1)
    }

    mutating func applyLinearOperation(delta: CGFloat) {
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

    private mutating func appendShape(_ shape: GraphShape) {
        shapes.append(shape)
        selectedShapeID = shape.id
        operationAxis = .shapeSelection
    }

    private mutating func ensureSelection() {
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

    private mutating func selectAxis(step: Int) {
        ensureSelection()

        let axes = selectedShape?.supportedOperationAxes ?? [.shapeSelection]
        guard let currentIndex = axes.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + step + axes.count) % axes.count
        operationAxis = axes[nextIndex]
    }

    private mutating func moveSelection(by delta: Int) {
        guard !shapes.isEmpty else {
            selectedShapeID = nil
            return
        }

        let currentIndex = selectedShapeIndex ?? 0
        let nextIndex = (currentIndex + delta + shapes.count) % shapes.count
        selectedShapeID = shapes[nextIndex].id
        operationAxis = .shapeSelection
    }
}
