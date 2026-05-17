import Foundation

extension GraphEditorStore {
    var selectedOperationAxisID: OperationAxis? {
        operationAxis
    }

    var operationAxisRows: [OperationAxisRow] {
        guard let selectedGroup = editingGroup else {
            return []
        }

        return ShapeGroupEditing.supportedOperationAxes(for: selectedGroup).map { axis in
            OperationAxisRow(
                id: axis,
                title: axis.title,
                valueText: operationValueText(for: axis, in: selectedGroup),
                isSelected: axis == operationAxis
            )
        }
    }

    func setOperationAxis(_ axis: OperationAxis) {
        guard
            let selectedGroup = editingGroup,
            ShapeGroupEditing.supportedOperationAxes(for: selectedGroup).contains(axis)
        else {
            return
        }

        operationAxis = axis
    }

    func operationValueText(for axis: OperationAxis, in selectedGroup: ShapeGroup) -> String {
        switch axis {
        case .xCoordinate, .yCoordinate, .width, .height, .spacing, .xOffset, .yOffset, .rotation:
            guard let property = axis.editableProperty else {
                return "なし"
            }

            let value = Int(ShapeGroupEditing.value(for: property, in: selectedGroup))
            return axis == .rotation ? "\(value)°" : "\(value)"
        }
    }
}
