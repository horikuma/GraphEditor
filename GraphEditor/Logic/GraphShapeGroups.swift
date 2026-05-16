import Foundation

indirect enum GraphShapeGroupElement {
    case group(GraphShapeGroup)
    case shape(GraphShape)
}

struct GraphShapeGroup: Identifiable {
    let id: UUID
    var title: String
    var children: [GraphShapeGroupElement]

    init(id: UUID = UUID(), title: String, children: [GraphShapeGroupElement]) {
        self.id = id
        self.title = title
        self.children = children
    }

    static func primitiveGroup(for shape: GraphShape) -> GraphShapeGroup {
        GraphShapeGroup(title: shape.title, children: [.shape(shape)])
    }

    var flattenedShapes: [GraphShape] {
        children.flatMap(\.flattenedShapes)
    }

    var shapeIDs: Set<GraphShape.ID> {
        Set(flattenedShapes.map(\.id))
    }

    var shapeCount: Int {
        flattenedShapes.count
    }

    var childGroups: [GraphShapeGroup] {
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

    var bounds: LogicRect? {
        flattenedShapes.compactMap(\.bounds).reduce(nil) { partialResult, bounds in
            partialResult?.union(bounds) ?? bounds
        }
    }

    func group(id: UUID) -> GraphShapeGroup? {
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
    mutating func appendChild(_ child: GraphShapeGroupElement, toGroup id: UUID) -> Bool {
        updateGroup(id: id) { group in
            group.children.append(child)
        }
    }

    @discardableResult
    mutating func updateGroup(id: UUID, transform: (inout GraphShapeGroup) -> Void) -> Bool {
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

extension GraphShapeGroupElement {
    var flattenedShapes: [GraphShape] {
        switch self {
        case let .group(group):
            return group.flattenedShapes
        case let .shape(shape):
            return [shape]
        }
    }

    var group: GraphShapeGroup? {
        guard case let .group(group) = self else {
            return nil
        }

        return group
    }

    func group(id: UUID) -> GraphShapeGroup? {
        switch self {
        case let .group(group):
            return group.group(id: id)
        case .shape:
            return nil
        }
    }
}
