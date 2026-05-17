import AppKit
import SwiftUI

final class GraphEditorBridge: ObservableObject {
    private let store = GraphEditorStore()

    var addableShapeKind: AddableShapeKind {
        get {
            store.addableShapeKind
        }
        set {
            store.addableShapeKind = newValue
            objectWillChange.send()
        }
    }

    var strokeColor: Color {
        get {
            Self.color(from: store.strokeColor)
        }
        set {
            store.strokeColor = Self.logicColor(from: newValue)
            objectWillChange.send()
        }
    }

    var status: EditorStatus {
        store.status
    }

    var groupTreeRows: [GroupTreeRow] {
        store.groupTreeRows
    }

    var selectedTreeNodeIDs: Set<UUID> {
        get {
            store.selectedTreeNodeIDs
        }
        set {
            store.setTreeSelection(ids: newValue)
            objectWillChange.send()
        }
    }

    var canGroupSelection: Bool {
        store.canGroupSelection
    }

    var canUngroupSelection: Bool {
        store.canUngroupSelection
    }

    var isClearDisabled: Bool {
        store.isClearDisabled
    }

    func clear() {
        store.clear()
        objectWillChange.send()
    }

    func appendShape(at location: CGPoint, in size: CGSize) {
        store.appendShape(at: Self.logicPoint(from: location), in: Self.logicSize(from: size))
        objectWillChange.send()
    }

    func selectShape(at location: CGPoint) {
        store.selectShape(at: Self.logicPoint(from: location))
        objectWillChange.send()
    }

    func groupSelection() {
        store.groupSelection()
        objectWillChange.send()
    }

    func ungroupSelection() {
        store.ungroupSelection()
        objectWillChange.send()
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = Self.keyCommand(from: event) else {
            return false
        }

        let modifiers = LogicKeyModifiers(
            isShiftPressed: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        )
        let handled = store.handleKeyCommand(command, modifiers: modifiers)

        if handled {
            objectWillChange.send()
        }

        return handled
    }

    func drawingPrimitives(in size: CGSize) -> [DrawingPrimitive] {
        let snapshot = store.snapshot
        let grids = snapshot.shapes.filter(\.isGrid).flatMap {
            drawingPrimitives(for: $0, snapshot: snapshot, in: size)
        }
        let nonGrids = snapshot.shapes.filter { !$0.isGrid }.flatMap {
            drawingPrimitives(for: $0, snapshot: snapshot, in: size)
        }
        return grids + nonGrids
    }

    private func drawingPrimitives(
        for shape: DrawingShape,
        snapshot: LogicSnapshot,
        in size: CGSize
    ) -> [DrawingPrimitive] {
        let isSelected = snapshot.selectedShapeIDs.contains(shape.id)
        var primitives = [
            drawingPrimitive(for: shape, isSelected: isSelected, in: size)
        ]

        if shape.showsCentroidCrossByDefault || isSelected {
            primitives.append(
                .centroidCross(
                    CentroidCrossPrimitive(
                        id: UUID(),
                        point: Self.point(from: shape.centroid),
                        isSelected: isSelected
                    )
                )
            )
        }

        return primitives
    }

    private func drawingPrimitive(
        for shape: DrawingShape,
        isSelected: Bool,
        in size: CGSize
    ) -> DrawingPrimitive {
        switch shape {
        case let .circle(circle):
            return .circle(
                CirclePrimitive(
                    id: circle.id,
                    rect: Self.rect(center: circle.center, diameter: circle.diameter),
                    color: Self.color(from: circle.color),
                    isSelected: isSelected
                )
            )
        case let .rectangle(rectangle):
            return .rectangle(
                RectanglePrimitive(
                    id: rectangle.id,
                    rect: Self.rect(center: rectangle.center, size: rectangle.size),
                    color: Self.color(from: rectangle.color),
                    isSelected: isSelected
                )
            )
        case let .grid(grid):
            return drawingPrimitive(for: grid, isSelected: isSelected, in: size)
        }
    }

    private func drawingPrimitive(for grid: DrawnGrid, isSelected: Bool, in size: CGSize) -> DrawingPrimitive {
        .grid(
            GridPrimitive(
                id: grid.id,
                verticalLinePositions: Self.linePositions(
                    origin: grid.origin.xCoordinate,
                    step: grid.spacing,
                    limit: Double(size.width)
                ),
                horizontalLinePositions: Self.linePositions(
                    origin: grid.origin.yCoordinate,
                    step: grid.spacing,
                    limit: Double(size.height)
                ),
                isSelected: isSelected
            )
        )
    }

    private static func keyCommand(from event: NSEvent) -> LogicKeyCommand? {
        switch event.keyCode {
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .arrowDown
        case 126:
            return .arrowUp
        default:
            return nil
        }
    }

    private static func logicPoint(from point: CGPoint) -> LogicPoint {
        LogicPoint(xCoordinate: Double(point.x), yCoordinate: Double(point.y))
    }

    private static func logicSize(from size: CGSize) -> LogicSize {
        LogicSize(width: Double(size.width), height: Double(size.height))
    }

    private static func point(from point: LogicPoint) -> CGPoint {
        CGPoint(x: point.xCoordinate, y: point.yCoordinate)
    }

    private static func rect(center: LogicPoint, diameter: Double) -> CGRect {
        CGRect(
            x: center.xCoordinate - diameter / 2,
            y: center.yCoordinate - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    private static func rect(center: LogicPoint, size: LogicSize) -> CGRect {
        CGRect(
            x: center.xCoordinate - size.width / 2,
            y: center.yCoordinate - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func color(from color: LogicColor) -> Color {
        Color(red: color.red, green: color.green, blue: color.blue, opacity: color.opacity)
    }

    private static func logicColor(from color: Color) -> LogicColor {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .controlAccentColor
        return LogicColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            opacity: Double(nsColor.alphaComponent)
        )
    }

    private static func linePositions(origin: Double, step: Double, limit: Double) -> [CGFloat] {
        let normalizedStep = max(step, 4)
        let start = firstVisibleLineOffset(for: origin, step: normalizedStep)
        return Array(stride(from: start, through: limit, by: normalizedStep)).map { CGFloat($0) }
    }

    private static func firstVisibleLineOffset(for origin: Double, step: Double) -> Double {
        let remainder = origin.truncatingRemainder(dividingBy: step)
        return remainder >= 0 ? remainder : remainder + step
    }
}
