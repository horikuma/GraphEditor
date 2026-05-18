import Foundation

indirect enum ShapeGroupElement {
    case group(ShapeGroup)
    case shape(DrawingShape)

    var id: UUID {
        switch self {
        case let .group(group):
            return group.id
        case let .shape(shape):
            return shape.id
        }
    }

    var title: String {
        switch self {
        case let .group(group):
            return group.title
        case let .shape(shape):
            return shape.title
        }
    }

    var isGroup: Bool {
        if case .group = self {
            return true
        }

        return false
    }

    var shapeIDs: Set<DrawingShape.ID> {
        Set(flattenedShapes.map(\.id))
    }

    var shapeCount: Int {
        flattenedShapes.count
    }
}

struct ShapeGroup: Identifiable {
    let id: UUID
    var title: String
    var children: [ShapeGroupElement]

    init(id: UUID = UUID(), title: String, children: [ShapeGroupElement]) {
        self.id = id
        self.title = title
        self.children = children
    }

    static func primitiveGroup(for shape: DrawingShape) -> ShapeGroup {
        ShapeGroup(title: shape.title, children: [.shape(shape)])
    }

    var flattenedShapes: [DrawingShape] {
        children.flatMap(\.flattenedShapes)
    }

    var shapeIDs: Set<DrawingShape.ID> {
        Set(flattenedShapes.map(\.id))
    }

    var shapeCount: Int {
        flattenedShapes.count
    }

    var childGroups: [ShapeGroup] {
        children.compactMap(\.group)
    }

    var centroid: LogicPoint {
        let centroids = flattenedShapes.map(\.centroid)
        guard !centroids.isEmpty else {
            return .zero
        }

        let sum = centroids.reduce(LogicPoint.zero) { partialResult, point in
            LogicPoint(
                xCoordinate: partialResult.xCoordinate + point.xCoordinate,
                yCoordinate: partialResult.yCoordinate + point.yCoordinate
            )
        }
        return LogicPoint(
            xCoordinate: sum.xCoordinate / Double(centroids.count),
            yCoordinate: sum.yCoordinate / Double(centroids.count)
        )
    }

    var rotationCentroid: LogicPoint {
        let weightedValues = flattenedShapes.map { shape in
            (centroid: shape.centroid, area: shape.rotationArea)
        }.filter { $0.area > 0 }
        guard !weightedValues.isEmpty else {
            return centroid
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

    var bounds: LogicRect? {
        flattenedShapes.compactMap(\.bounds).reduce(nil) { partialResult, bounds in
            partialResult?.union(bounds) ?? bounds
        }
    }

    func group(id: UUID) -> ShapeGroup? {
        if self.id == id {
            return self
        }

        for child in children {
            if let group = child.group(id: id) {
                return group
            }
        }

        return nil
    }

    @discardableResult
    mutating func appendChild(_ child: ShapeGroupElement, toGroup id: UUID) -> Bool {
        updateGroup(id: id) { group in
            group.children.append(child)
        }
    }

    @discardableResult
    mutating func updateGroup(id: UUID, transform: (inout ShapeGroup) -> Void) -> Bool {
        if self.id == id {
            transform(&self)
            return true
        }

        for index in children.indices {
            guard case var .group(group) = children[index] else {
                continue
            }

            if group.updateGroup(id: id, transform: transform) {
                children[index] = .group(group)
                return true
            }
        }

        return false
    }
}

extension ShapeGroupElement {
    var selectableIDs: Set<UUID> {
        switch self {
        case let .group(group):
            return Set([group.id]).union(group.children.flatMap(\.selectableIDs))
        case let .shape(shape):
            return [shape.id]
        }
    }

    var flattenedShapes: [DrawingShape] {
        switch self {
        case let .group(group):
            return group.flattenedShapes
        case let .shape(shape):
            return [shape]
        }
    }

    var group: ShapeGroup? {
        guard case let .group(group) = self else {
            return nil
        }

        return group
    }

    func group(id: UUID) -> ShapeGroup? {
        switch self {
        case let .group(group):
            return group.group(id: id)
        case .shape:
            return nil
        }
    }
}

extension ShapeGroup {
    var selectableIDs: Set<UUID> {
        Set(children.flatMap(\.selectableIDs))
    }

    func selectedElements(ids: Set<UUID>) -> [ShapeGroupElement] {
        children.flatMap { child -> [ShapeGroupElement] in
            if ids.contains(child.id) {
                return [child]
            }

            guard case let .group(group) = child else {
                return []
            }

            return group.selectedElements(ids: ids)
        }
    }

    mutating func updateSelectedElements(
        ids: Set<UUID>,
        transform: (inout ShapeGroupElement) -> Void
    ) {
        for index in children.indices {
            if ids.contains(children[index].id) {
                transform(&children[index])
                continue
            }

            guard case var .group(group) = children[index] else {
                continue
            }

            group.updateSelectedElements(ids: ids, transform: transform)
            children[index] = .group(group)
        }
    }
}
