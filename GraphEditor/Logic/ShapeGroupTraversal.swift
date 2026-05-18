import Foundation

enum ShapeGroupTraversal {
    static func selectableIDs(in group: ShapeGroup) -> Set<UUID> {
        Set(group.children.flatMap(selectableIDs(in:)))
    }

    static func selectableIDs(in element: ShapeGroupElement) -> Set<UUID> {
        switch element {
        case let .group(group):
            return Set([group.id]).union(group.children.flatMap(selectableIDs(in:)))
        case let .shape(shape):
            return [shape.id]
        }
    }

    static func selectedElements(in group: ShapeGroup, ids: Set<UUID>) -> [ShapeGroupElement] {
        group.children.flatMap { child -> [ShapeGroupElement] in
            if ids.contains(child.id) {
                return [child]
            }

            guard case let .group(group) = child else {
                return []
            }

            return selectedElements(in: group, ids: ids)
        }
    }

    static func updateSelectedElements(
        ids: Set<UUID>,
        in group: inout ShapeGroup,
        transform: (inout ShapeGroupElement) -> Void
    ) {
        for index in group.children.indices {
            if ids.contains(group.children[index].id) {
                transform(&group.children[index])
                continue
            }

            guard case var .group(childGroup) = group.children[index] else {
                continue
            }

            updateSelectedElements(ids: ids, in: &childGroup, transform: transform)
            group.children[index] = .group(childGroup)
        }
    }
}
