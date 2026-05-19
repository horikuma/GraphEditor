import Foundation

struct DrawnCircle: Identifiable, EditableShape, RotatableShape {
    let id = UUID()
    let title: String
    var center: LogicPoint
    var size: LogicSize
    var rotationDegrees = 0.0
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

    var rotationArea: Double {
        .pi * size.width * size.height / 4
    }

    var supportedOperationAxes: [OperationAxis] {
        [.xCoordinate, .yCoordinate, .width, .height, .rotation]
    }

    func value(for axis: OperationAxis) -> Double {
        switch axis {
        case .xCoordinate:
            return center.xCoordinate
        case .yCoordinate:
            return center.yCoordinate
        case .width:
            return size.width
        case .height:
            return size.height
        case .rotation:
            return rotationDegrees
        case .spacing, .xOffset, .yOffset:
            return 0
        }
    }

    mutating func move(axis: OperationAxis, by delta: Double) {
        switch axis {
        case .xCoordinate:
            center.xCoordinate += delta
        case .yCoordinate:
            center.yCoordinate -= delta
        case .width:
            size.width = max(4, size.width + delta)
        case .height:
            size.height = max(4, size.height + delta)
        case .rotation:
            rotationDegrees += delta
        case .spacing, .xOffset, .yOffset:
            break
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        center.xCoordinate += xDelta
        center.yCoordinate += yDelta
    }

    mutating func rotateBy(degrees: Double, around pivot: LogicPoint) {
        center = center.rotated(degrees: degrees, around: pivot)
        rotationDegrees += degrees
    }
}
