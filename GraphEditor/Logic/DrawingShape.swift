import Foundation

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

    var rotationArea: Double {
        switch self {
        case let .circle(circle):
            return circle.rotationArea
        case let .rectangle(rectangle):
            return rectangle.rotationArea
        case .grid:
            return 0
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

    mutating func rotateBy(degrees: Double, around pivot: LogicPoint) {
        switch self {
        case var .circle(circle):
            circle.rotateBy(degrees: degrees, around: pivot)
            self = .circle(circle)
        case var .rectangle(rectangle):
            rectangle.rotateBy(degrees: degrees, around: pivot)
            self = .rectangle(rectangle)
        case .grid:
            break
        }
    }
}
