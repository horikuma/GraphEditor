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
    let lineWidth: Double

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
        [.shapeSelection, .xCoordinate, .yCoordinate, .width, .height]
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
        [.shapeSelection, .spacing, .xOffset, .yOffset]
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

    var centroid: LogicPoint {
        switch self {
        case let .circle(circle):
            return circle.centroid
        case let .grid(grid):
            return grid.centroid
        }
    }

    var bounds: LogicRect? {
        switch self {
        case let .circle(circle):
            return circle.bounds
        case let .grid(grid):
            return grid.bounds
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

    func value(for property: ShapeEditableProperty) -> Double {
        switch self {
        case let .circle(circle):
            return circle.value(for: property)
        case let .grid(grid):
            return grid.value(for: property)
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch self {
        case var .circle(circle):
            circle.move(property: property, by: delta)
            self = .circle(circle)
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
        case var .grid(grid):
            grid.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .grid(grid)
        }
    }
}
