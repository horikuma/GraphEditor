import Foundation

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
        case .xCoordinate, .yCoordinate, .width, .height, .rotation:
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
        case .xCoordinate, .yCoordinate, .width, .height, .rotation:
            break
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        origin.xCoordinate += xDelta
        origin.yCoordinate += yDelta
    }
}
