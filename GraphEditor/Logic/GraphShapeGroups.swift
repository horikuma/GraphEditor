import Foundation

indirect enum GraphShapeGroupElement {
    case group(GraphShapeGroup)
    case shape(GraphShape)
}

struct GraphShapeGroup: Identifiable, EditableShape {
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

    var supportedOperationAxes: [OperationAxis] {
        let shapes = flattenedShapes
        guard !shapes.isEmpty else {
            return [.shapeSelection]
        }

        if shapes.allSatisfy(\.isGrid) {
            return [.shapeSelection, .spacing, .xOffset, .yOffset]
        }

        return [.shapeSelection, .xCoordinate, .yCoordinate, .width, .height]
    }

    func value(for property: ShapeEditableProperty) -> Double {
        switch property {
        case .xCoordinate:
            return centroid.xCoordinate
        case .yCoordinate:
            return centroid.yCoordinate
        case .width:
            return bounds?.width ?? firstShapeValue(for: property)
        case .height:
            return bounds?.height ?? firstShapeValue(for: property)
        case .spacing, .xOffset, .yOffset:
            return firstShapeValue(for: property)
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch property {
        case .xCoordinate:
            translateBy(xDelta: delta, yDelta: 0)
        case .yCoordinate:
            translateBy(xDelta: 0, yDelta: -delta)
        case .width, .height, .spacing, .xOffset, .yOffset:
            for index in children.indices {
                children[index].move(property: property, by: delta)
            }
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        for index in children.indices {
            children[index].translateBy(xDelta: xDelta, yDelta: yDelta)
        }
    }

    @discardableResult
    mutating func appendChild(_ child: GraphShapeGroupElement, toGroup id: UUID) -> Bool {
        updateGroup(id: id) { group in
            group.children.append(child)
        }
    }

    @discardableResult
    mutating func moveGroup(id: UUID, property: ShapeEditableProperty, by delta: Double) -> Bool {
        updateGroup(id: id) { group in
            group.move(property: property, by: delta)
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

    private mutating func updateGroup(id: UUID, transform: (inout GraphShapeGroup) -> Void) -> Bool {
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

    private func firstShapeValue(for property: ShapeEditableProperty) -> Double {
        flattenedShapes.first { shape in
            shape.supportedOperationAxes.contains {
                $0.editableProperty == property
            }
        }?.value(for: property) ?? 0
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

    mutating func move(property: ShapeEditableProperty, by delta: Double) {
        switch self {
        case var .group(group):
            group.move(property: property, by: delta)
            self = .group(group)
        case var .shape(shape):
            guard shape.supportedOperationAxes.contains(where: { $0.editableProperty == property }) else {
                return
            }

            shape.move(property: property, by: delta)
            self = .shape(shape)
        }
    }

    mutating func translateBy(xDelta: Double, yDelta: Double) {
        switch self {
        case var .group(group):
            group.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .group(group)
        case var .shape(shape):
            shape.translateBy(xDelta: xDelta, yDelta: yDelta)
            self = .shape(shape)
        }
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
