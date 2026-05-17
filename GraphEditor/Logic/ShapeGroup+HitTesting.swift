import Foundation

extension ShapeGroup {
    func hitSelectableID(at location: LogicPoint) -> UUID? {
        for child in children.reversed() where child.hitTest(at: location) {
            return child.id
        }

        return nil
    }
}

private extension ShapeGroupElement {
    func hitTest(at location: LogicPoint) -> Bool {
        switch self {
        case let .group(group):
            return group.children.reversed().contains { $0.hitTest(at: location) }
        case let .shape(shape):
            return shape.hitTest(at: location)
        }
    }
}

private extension DrawingShape {
    func hitTest(at location: LogicPoint) -> Bool {
        switch self {
        case let .circle(circle):
            return circle.hitTest(at: location)
        case let .rectangle(rectangle):
            return rectangle.hitTest(at: location)
        case .grid:
            return false
        }
    }
}

private extension DrawnCircle {
    func hitTest(at location: LogicPoint) -> Bool {
        let radius = diameter / 2
        guard radius > 0 else {
            return false
        }

        let xDistance = location.xCoordinate - center.xCoordinate
        let yDistance = location.yCoordinate - center.yCoordinate
        return xDistance * xDistance + yDistance * yDistance <= radius * radius
    }
}

private extension DrawnRectangle {
    func hitTest(at location: LogicPoint) -> Bool {
        guard let bounds else {
            return false
        }

        let unrotatedLocation = location.rotated(degrees: -rotationDegrees, around: center)
        return unrotatedLocation.xCoordinate >= bounds.minX
            && unrotatedLocation.xCoordinate <= bounds.maxX
            && unrotatedLocation.yCoordinate >= bounds.minY
            && unrotatedLocation.yCoordinate <= bounds.maxY
    }
}
