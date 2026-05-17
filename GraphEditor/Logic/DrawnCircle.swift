import Foundation

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
