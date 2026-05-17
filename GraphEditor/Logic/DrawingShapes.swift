import Foundation

struct LogicPoint {
    var xCoordinate: Double
    var yCoordinate: Double

    static let zero = LogicPoint(xCoordinate: 0, yCoordinate: 0)
}

struct LogicSize {
    var width: Double
    var height: Double
}

struct LogicRect {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double {
        maxX - minX
    }

    var height: Double {
        maxY - minY
    }

    func union(_ other: LogicRect) -> LogicRect {
        LogicRect(
            minX: min(minX, other.minX),
            minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY)
        )
    }
}

struct LogicColor {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    static let accent = LogicColor(red: 0, green: 0.478, blue: 1, opacity: 1)
}

enum AddableShapeKind: String, CaseIterable, Identifiable {
    case circle
    case rectangle

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .circle:
            return "円"
        case .rectangle:
            return "矩形"
        }
    }
}

enum LogicKeyCommand {
    case left
    case right
    case arrowDown
    case arrowUp
}

struct LogicKeyModifiers {
    var isShiftPressed: Bool
}

struct DrawnCircle: Identifiable, EditableShape {
    let id = UUID()
    var center: LogicPoint
    var diameter: Double
    let color: LogicColor

    var centroid: LogicPoint {
        center
    }

    var bounds: LogicRect? {
        LogicRect(
            minX: center.xCoordinate - diameter / 2,
            minY: center.yCoordinate - diameter / 2,
            maxX: center.xCoordinate + diameter / 2,
            maxY: center.yCoordinate + diameter / 2
        )
    }

    var supportedOperationAxes: [OperationAxis] {
        [.xCoordinate, .yCoordinate, .width, .height]
    }

    func value(for property: ShapeEditableProperty) -> Double {
        switch property {
        case .xCoordinate:
            return center.xCoordinate
        case .yCoordinate:
            return center.yCoordinate
        case .width:
            return diameter
        case .height:
            return diameter
        case .spacing, .xOffset, .yOffset:
            return 0
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch property {
        case .xCoordinate:
            center.xCoordinate += delta
        case .yCoordinate:
            center.yCoordinate -= delta
        case .width, .height:
            diameter = max(4, diameter + delta)
        case .spacing, .xOffset, .yOffset:
            break
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        center.xCoordinate += xDelta
        center.yCoordinate += yDelta
    }
}

struct DrawnRectangle: Identifiable, EditableShape {
    let id = UUID()
    var center: LogicPoint
    var size: LogicSize
    let color: LogicColor

    var centroid: LogicPoint {
        center
    }

    var bounds: LogicRect? {
        LogicRect(
            minX: center.xCoordinate - size.width / 2,
            minY: center.yCoordinate - size.height / 2,
            maxX: center.xCoordinate + size.width / 2,
            maxY: center.yCoordinate + size.height / 2
        )
    }

    var supportedOperationAxes: [OperationAxis] {
        [.xCoordinate, .yCoordinate, .width, .height]
    }

    func value(for property: ShapeEditableProperty) -> Double {
        switch property {
        case .xCoordinate:
            return center.xCoordinate
        case .yCoordinate:
            return center.yCoordinate
        case .width:
            return size.width
        case .height:
            return size.height
        case .spacing, .xOffset, .yOffset:
            return 0
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch property {
        case .xCoordinate:
            center.xCoordinate += delta
        case .yCoordinate:
            center.yCoordinate -= delta
        case .width:
            size.width = max(4, size.width + delta)
        case .height:
            size.height = max(4, size.height + delta)
        case .spacing, .xOffset, .yOffset:
            break
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        center.xCoordinate += xDelta
        center.yCoordinate += yDelta
    }
}

struct DrawnGrid: Identifiable, EditableShape {
    let id = UUID()
    var origin: LogicPoint
    var spacing: Double

    var centroid: LogicPoint {
        origin
    }

    var bounds: LogicRect? {
        nil
    }

    var supportedOperationAxes: [OperationAxis] {
        [.spacing, .xOffset, .yOffset]
    }

    func value(for property: ShapeEditableProperty) -> Double {
        switch property {
        case .spacing:
            return spacing
        case .xOffset:
            return origin.xCoordinate
        case .yOffset:
            return origin.yCoordinate
        case .xCoordinate, .yCoordinate, .width, .height:
            return 0
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch property {
        case .spacing:
            spacing = max(4, spacing + delta)
        case .xOffset:
            origin.xCoordinate += delta
        case .yOffset:
            origin.yCoordinate -= delta
        case .xCoordinate, .yCoordinate, .width, .height:
            break
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        origin.xCoordinate += xDelta
        origin.yCoordinate += yDelta
    }
}

enum DrawingShape: Identifiable {
    case circle(DrawnCircle)
    case rectangle(DrawnRectangle)
    case grid(DrawnGrid)

    var id: UUID {
        switch self {
        case let .circle(circle):
            return circle.id
        case let .rectangle(rectangle):
            return rectangle.id
        case let .grid(grid):
            return grid.id
        }
    }

    var title: String {
        switch self {
        case .circle:
            return "円"
        case .rectangle:
            return "矩形"
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
        case .circle, .rectangle:
            return true
        case .grid:
            return false
        }
    }

    var centroid: LogicPoint {
        switch self {
        case let .circle(circle):
            return circle.centroid
        case let .rectangle(rectangle):
            return rectangle.centroid
        case let .grid(grid):
            return grid.centroid
        }
    }

    var bounds: LogicRect? {
        switch self {
        case let .circle(circle):
            return circle.bounds
        case let .rectangle(rectangle):
            return rectangle.bounds
        case let .grid(grid):
            return grid.bounds
        }
    }

    var supportedOperationAxes: [OperationAxis] {
        switch self {
        case let .circle(circle):
            return circle.supportedOperationAxes
        case let .rectangle(rectangle):
            return rectangle.supportedOperationAxes
        case let .grid(grid):
            return grid.supportedOperationAxes
        }
    }

    func value(for property: ShapeEditableProperty) -> Double {
        switch self {
        case let .circle(circle):
            return circle.value(for: property)
        case let .rectangle(rectangle):
            return rectangle.value(for: property)
        case let .grid(grid):
            return grid.value(for: property)
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch self {
        case var .circle(circle):
            circle.move(property: property, by: delta)
            self = .circle(circle)
        case var .rectangle(rectangle):
            rectangle.move(property: property, by: delta)
            self = .rectangle(rectangle)
        case var .grid(grid):
            grid.move(property: property, by: delta)
            self = .grid(grid)
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        switch self {
        case var .circle(circle):
            circle.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .circle(circle)
        case var .rectangle(rectangle):
            rectangle.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .rectangle(rectangle)
        case var .grid(grid):
            grid.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .grid(grid)
        }
    }
}
