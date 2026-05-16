import AppKit
import SwiftUI

enum DrawingPrimitive: Identifiable {
    case circle(CircleDrawingInfo)
    case grid(GridDrawingInfo)
    case centroidCross(CentroidCrossDrawingInfo)

    var id: UUID {
        switch self {
        case let .circle(info):
            return info.id
        case let .grid(info):
            return info.id
        case let .centroidCross(info):
            return info.id
        }
    }
}

struct CircleDrawingInfo {
    let id: UUID
    let rect: CGRect
    let color: Color
    let lineWidth: CGFloat
    let fill: Bool
    let isSelected: Bool
}

struct GridDrawingInfo {
    let id: UUID
    let verticalLinePositions: [CGFloat]
    let horizontalLinePositions: [CGFloat]
    let isSelected: Bool
}

struct CentroidCrossDrawingInfo {
    let id: UUID
    let point: CGPoint
    let isSelected: Bool
}

struct EditorStatusInfo {
    let objectCountText: String
    let selectedShapeText: String
    let operationAxisText: String
    let operationValueText: String
}

final class GraphEditorLogic: ObservableObject {
    @Published var addableShapeKind = AddableShapeKind.circle
    @Published var strokeColor = Color.accentColor
    @Published var lineWidth = 3.0
    @Published var fillCircles = false

    @Published private var shapes: [GraphShape]
    @Published private var selectedShapeID: GraphShape.ID?
    @Published private var operationAxis = OperationAxis.shapeSelection

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

    func drawingPrimitives(in size: CGSize) -> [DrawingPrimitive] {
        let grids = shapes.filter(\.isGrid).flatMap { drawingPrimitives(for: $0, in: size) }
        let nonGrids = shapes.filter { !$0.isGrid }.flatMap { drawingPrimitives(for: $0, in: size) }
        return grids + nonGrids
    }

    func clear() {
        let grid = GraphShape.grid(DrawnGrid(origin: .zero, spacing: 24))
        shapes = [grid]
        selectedShapeID = grid.id
        operationAxis = .shapeSelection
    }

    func appendShape(at location: CGPoint, in size: CGSize) {
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

    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123:
            selectPreviousAxis()
        case 124:
            selectNextAxis()
        case 125:
            applyLinearOperation(delta: -keyStep(for: event))
        case 126:
            applyLinearOperation(delta: keyStep(for: event))
        default:
            return false
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

    private func applyLinearOperation(delta: CGFloat) {
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

    private func keyStep(for event: NSEvent) -> CGFloat {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) ? 10 : 1
    }

    private func drawingPrimitives(for shape: GraphShape, in size: CGSize) -> [DrawingPrimitive] {
        var primitives: [DrawingPrimitive] = []
        let isSelected = shape.id == selectedShapeID

        switch shape {
        case let .circle(circle):
            primitives.append(
                .circle(
                    CircleDrawingInfo(
                        id: circle.id,
                        rect: circle.rect,
                        color: circle.color,
                        lineWidth: circle.lineWidth,
                        fill: fillCircles,
                        isSelected: isSelected
                    )
                )
            )
        case let .grid(grid):
            primitives.append(
                .grid(
                    GridDrawingInfo(
                        id: grid.id,
                        verticalLinePositions: Self.linePositions(
                            origin: grid.origin.x,
                            step: grid.spacing,
                            limit: size.width
                        ),
                        horizontalLinePositions: Self.linePositions(
                            origin: grid.origin.y,
                            step: grid.spacing,
                            limit: size.height
                        ),
                        isSelected: isSelected
                    )
                )
            )
        }

        if shape.showsCentroidCrossByDefault || isSelected {
            primitives.append(
                .centroidCross(
                    CentroidCrossDrawingInfo(
                        id: UUID(),
                        point: shape.centroid,
                        isSelected: isSelected
                    )
                )
            )
        }

        return primitives
    }

    private static func linePositions(origin: CGFloat, step: CGFloat, limit: CGFloat) -> [CGFloat] {
        let normalizedStep = max(step, 4)
        let start = firstVisibleLineOffset(for: origin, step: normalizedStep)
        return Array(stride(from: start, through: limit, by: normalizedStep))
    }

    private static func firstVisibleLineOffset(for origin: CGFloat, step: CGFloat) -> CGFloat {
        let remainder = origin.truncatingRemainder(dividingBy: step)
        return remainder >= 0 ? remainder : remainder + step
    }

    private static func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
