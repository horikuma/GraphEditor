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

final class GraphEditorBridge: ObservableObject {
    private let logic = GraphEditorLogic()

    var addableShapeKind: AddableShapeKind {
        get {
            logic.addableShapeKind
        }
        set {
            logic.addableShapeKind = newValue
            objectWillChange.send()
        }
    }

    var strokeColor: Color {
        get {
            Self.color(from: logic.strokeColor)
        }
        set {
            logic.strokeColor = Self.logicColor(from: newValue)
            objectWillChange.send()
        }
    }

    var lineWidth: Double {
        get {
            logic.lineWidth
        }
        set {
            logic.lineWidth = newValue
            objectWillChange.send()
        }
    }

    var fillCircles: Bool {
        get {
            logic.fillCircles
        }
        set {
            logic.fillCircles = newValue
            objectWillChange.send()
        }
    }

    var statusInfo: EditorStatusInfo {
        logic.statusInfo
    }

    var isClearDisabled: Bool {
        logic.isClearDisabled
    }

    func clear() {
        logic.clear()
        objectWillChange.send()
    }

    func appendShape(at location: CGPoint, in size: CGSize) {
        logic.appendShape(at: Self.logicPoint(from: location), in: Self.logicSize(from: size))
        objectWillChange.send()
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = Self.keyCommand(from: event) else {
            return false
        }

        let modifiers = LogicKeyModifiers(
            isShiftPressed: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        )
        let handled = logic.handleKeyCommand(command, modifiers: modifiers)

        if handled {
            objectWillChange.send()
        }

        return handled
    }

    func drawingPrimitives(in size: CGSize) -> [DrawingPrimitive] {
        let snapshot = logic.snapshot
        let grids = snapshot.shapes.filter(\.isGrid).flatMap {
            drawingPrimitives(for: $0, snapshot: snapshot, in: size)
        }
        let nonGrids = snapshot.shapes.filter { !$0.isGrid }.flatMap {
            drawingPrimitives(for: $0, snapshot: snapshot, in: size)
        }
        return grids + nonGrids
    }

    private func drawingPrimitives(
        for shape: GraphShape,
        snapshot: LogicSnapshot,
        in size: CGSize
    ) -> [DrawingPrimitive] {
        var primitives: [DrawingPrimitive] = []
        let isSelected = shape.id == snapshot.selectedShapeID

        switch shape {
        case let .circle(circle):
            primitives.append(
                .circle(
                    CircleDrawingInfo(
                        id: circle.id,
                        rect: Self.rect(center: circle.center, diameter: circle.diameter),
                        color: Self.color(from: circle.color),
                        lineWidth: CGFloat(circle.lineWidth),
                        fill: snapshot.fillCircles,
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
            )
        }

        if shape.showsCentroidCrossByDefault || isSelected {
            primitives.append(
                .centroidCross(
                    CentroidCrossDrawingInfo(
                        id: UUID(),
                        point: Self.point(from: shape.centroid),
                        isSelected: isSelected
                    )
                )
            )
        }

        return primitives
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
