import Foundation

extension ShapeGroup {
    func hitSelectableID(at location: LogicPoint, selectedIDs: Set<UUID>) -> UUID? {
        for child in children.reversed() where child.hitTest(at: location) {
            return child.hitSelectableID(at: location, selectedIDs: selectedIDs)
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

private extension ShapeGroupElement {
    func hitSelectableID(at location: LogicPoint, selectedIDs: Set<UUID>) -> UUID? {
        switch self {
        case let .group(group):
            guard group.isSelectionContext(for: selectedIDs) else {
                return group.id
            }

            return group.hitSelectableID(at: location, selectedIDs: selectedIDs) ?? group.id
        case let .shape(shape):
            return shape.id
        }
    }
}

private extension ShapeGroup {
    func isSelectionContext(for selectedIDs: Set<UUID>) -> Bool {
        !selectedIDs.isDisjoint(with: ShapeGroupTraversal.selectableIDs(in: self))
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
        let xRadius = size.width / 2
        let yRadius = size.height / 2
        guard xRadius > 0, yRadius > 0 else {
            return false
        }

        let unrotatedLocation = location.rotated(degrees: -rotationDegrees, around: center)
        let xDistance = (unrotatedLocation.xCoordinate - center.xCoordinate) / xRadius
        let yDistance = (unrotatedLocation.yCoordinate - center.yCoordinate) / yRadius
        return xDistance * xDistance + yDistance * yDistance <= 1
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
