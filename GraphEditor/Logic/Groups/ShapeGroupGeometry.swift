import Foundation

enum ShapeGroupGeometry {
    static func rotationCentroid(of group: ShapeGroup) -> LogicPoint {
        let weightedValues = group.flattenedShapes.map { shape in
            (centroid: shape.centroid, area: shape.rotationArea)
        }.filter { $0.area > 0 }
        guard !weightedValues.isEmpty else {
            return group.centroid
        }

        let totalArea = weightedValues.reduce(0) { $0 + $1.area }
        let weightedSum = weightedValues.reduce(LogicPoint.zero) { partialResult, value in
            LogicPoint(
                xCoordinate: partialResult.xCoordinate + value.centroid.xCoordinate * value.area,
                yCoordinate: partialResult.yCoordinate + value.centroid.yCoordinate * value.area
            )
        }
        return LogicPoint(
            xCoordinate: weightedSum.xCoordinate / totalArea,
            yCoordinate: weightedSum.yCoordinate / totalArea
        )
    }

    static func translateBy(xDelta: Double, yDelta: Double, in group: inout ShapeGroup) {
        for index in group.children.indices {
            translateBy(xDelta: xDelta, yDelta: yDelta, in: &group.children[index])
        }
    }

    static func rotateBy(degrees: Double, around pivot: LogicPoint, in group: inout ShapeGroup) {
        for index in group.children.indices {
            rotateBy(degrees: degrees, around: pivot, in: &group.children[index])
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

    static func rotateBy(degrees: Double, around pivot: LogicPoint, in element: inout ShapeGroupElement) {
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
