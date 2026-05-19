import Foundation

enum ShapeGroupOperation {
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

    static func value(for axis: OperationAxis, in group: ShapeGroup) -> Double {
        switch axis {
        case .xCoordinate:
            return group.centroid.xCoordinate
        case .yCoordinate:
            return group.centroid.yCoordinate
        case .width:
            return group.bounds?.width ?? firstShapeValue(for: axis, in: group)
        case .height:
            return group.bounds?.height ?? firstShapeValue(for: axis, in: group)
        case .spacing, .xOffset, .yOffset, .rotation:
            return firstShapeValue(for: axis, in: group)
        }
    }

    static func moveNodes(
        ids: Set<UUID>,
        axis: OperationAxis,
        by delta: Double,
        in rootGroup: inout ShapeGroup
    ) {
        ShapeGroupTraversal.updateSelectedElements(ids: ids, in: &rootGroup) { element in
            move(axis: axis, by: delta, in: &element)
        }
    }

    static func rotateNodes(ids: Set<UUID>, degrees: Double, in rootGroup: inout ShapeGroup) {
        let selectedElements = ShapeGroupTraversal.selectedElements(in: rootGroup, ids: ids)
        let pivot = ShapeGroupGeometry.rotationCentroid(
            of: ShapeGroup(title: "選択", children: selectedElements)
        )
        ShapeGroupTraversal.updateSelectedElements(ids: ids, in: &rootGroup) { element in
            ShapeGroupGeometry.rotateBy(degrees: degrees, around: pivot, in: &element)
        }
    }

    private static func firstShapeValue(for axis: OperationAxis, in group: ShapeGroup) -> Double {
        group.flattenedShapes.first { shape in
            shape.supportedOperationAxes.contains {
                $0 == axis
            }
        }?.value(for: axis) ?? 0
    }

    private static func move(axis: OperationAxis, by delta: Double, in group: inout ShapeGroup) {
        switch axis {
        case .xCoordinate:
            ShapeGroupGeometry.translateBy(xDelta: delta, yDelta: 0, in: &group)
        case .yCoordinate:
            ShapeGroupGeometry.translateBy(xDelta: 0, yDelta: -delta, in: &group)
        case .rotation:
            ShapeGroupGeometry.rotateBy(
                degrees: delta,
                around: ShapeGroupGeometry.rotationCentroid(of: group),
                in: &group
            )
        case .width, .height, .spacing, .xOffset, .yOffset:
            for index in group.children.indices {
                move(axis: axis, by: delta, in: &group.children[index])
            }
        }
    }

    private static func move(
        axis: OperationAxis,
        by delta: Double,
        in element: inout ShapeGroupElement
    ) {
        switch element {
        case var .group(group):
            move(axis: axis, by: delta, in: &group)
            element = .group(group)
        case var .shape(shape):
            guard shape.supportedOperationAxes.contains(axis) else {
                return
            }

            shape.move(axis: axis, by: delta)
            element = .shape(shape)
        }
    }
}
