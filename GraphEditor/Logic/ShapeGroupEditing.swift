import Foundation

enum ShapeGroupEditing {
    static func supportedOperationAxes(for group: ShapeGroup) -> [OperationAxis] {
        let shapes = group.flattenedShapes
        guard !shapes.isEmpty else {
            return []
        }

        if shapes.allSatisfy(\.isGrid) {
            return [.spacing, .xOffset, .yOffset]
        }

        return [.xCoordinate, .yCoordinate, .width, .height, .rotation]
    }

    static func value(for property: ShapeEditableProperty, in group: ShapeGroup) -> Double {
        switch property {
        case .xCoordinate:
            return group.centroid.xCoordinate
        case .yCoordinate:
            return group.centroid.yCoordinate
        case .width:
            return group.bounds?.width ?? firstShapeValue(for: property, in: group)
        case .height:
            return group.bounds?.height ?? firstShapeValue(for: property, in: group)
        case .spacing, .xOffset, .yOffset, .rotation:
            return firstShapeValue(for: property, in: group)
        }
    }

    @discardableResult
    static func moveGroup(
        id: ShapeGroup.ID,
        property: ShapeEditableProperty,
        by delta: Double,
        in rootGroup: inout ShapeGroup
    ) -> Bool {
        rootGroup.updateGroup(id: id) { group in
            move(property: property, by: delta, in: &group)
        }
    }

    static func moveNodes(
        ids: Set<UUID>,
        property: ShapeEditableProperty,
        by delta: Double,
        in rootGroup: inout ShapeGroup
    ) {
        for index in rootGroup.children.indices where ids.contains(rootGroup.children[index].id) {
            move(property: property, by: delta, in: &rootGroup.children[index])
        }
    }

    private static func firstShapeValue(for property: ShapeEditableProperty, in group: ShapeGroup) -> Double {
        group.flattenedShapes.first { shape in
            shape.supportedOperationAxes.contains {
                $0.editableProperty == property
            }
        }?.value(for: property) ?? 0
    }

    private static func move(property: ShapeEditableProperty, by delta: Double, in group: inout ShapeGroup) {
        switch property {
        case .xCoordinate:
            translateBy(xDelta: delta, yDelta: 0, in: &group)
        case .yCoordinate:
            translateBy(xDelta: 0, yDelta: -delta, in: &group)
        case .rotation:
            rotateBy(degrees: delta, around: group.centroid, in: &group)
        case .width, .height, .spacing, .xOffset, .yOffset:
            for index in group.children.indices {
                move(property: property, by: delta, in: &group.children[index])
            }
        }
    }

    private static func move(
        property: ShapeEditableProperty,
        by delta: Double,
        in element: inout ShapeGroupElement
    ) {
        switch element {
        case var .group(group):
            move(property: property, by: delta, in: &group)
            element = .group(group)
        case var .shape(shape):
            guard shape.supportedOperationAxes.contains(where: { $0.editableProperty == property }) else {
                return
            }

            shape.move(property: property, by: delta)
            element = .shape(shape)
        }
    }

    private static func translateBy(xDelta: Double, yDelta: Double, in group: inout ShapeGroup) {
        for index in group.children.indices {
            translateBy(xDelta: xDelta, yDelta: yDelta, in: &group.children[index])
        }
    }

    private static func translateBy(xDelta: Double, yDelta: Double, in element: inout ShapeGroupElement) {
        switch element {
        case var .group(group):
            translateBy(xDelta: xDelta, yDelta: yDelta, in: &group)
            element = .group(group)
        case var .shape(shape):
            shape.translateBy(xDelta: xDelta, yDelta: yDelta)
            element = .shape(shape)
        }
    }

    private static func rotateBy(degrees: Double, around pivot: LogicPoint, in group: inout ShapeGroup) {
        for index in group.children.indices {
            rotateBy(degrees: degrees, around: pivot, in: &group.children[index])
        }
    }

    private static func rotateBy(
        degrees: Double,
        around pivot: LogicPoint,
        in element: inout ShapeGroupElement
    ) {
        switch element {
        case var .group(group):
            rotateBy(degrees: degrees, around: pivot, in: &group)
            element = .group(group)
        case var .shape(shape):
            shape.rotateBy(degrees: degrees, around: pivot)
            element = .shape(shape)
        }
    }
}
