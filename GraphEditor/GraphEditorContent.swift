import SwiftUI

struct DrawnCircle: Identifiable, EditableShape {
    let id = UUID()
    var center: CGPoint
    var diameter: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var rect: CGRect {
        CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    func value(for property: ShapeEditableProperty) -> CGFloat {
        switch property {
        case .x:
            return center.x
        case .y:
            return center.y
        case .width:
            return diameter
        case .height:
            return diameter
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: CGFloat) {
        switch property {
        case .x:
            center.x += delta
        case .y:
            center.y -= delta
        case .width, .height:
            diameter = max(4, diameter + delta)
        }
    }
}

struct GraphEditorContent {
    var circles: [DrawnCircle] = []
    var selectedCircleID: DrawnCircle.ID?
    var operationAxis = OperationAxis.shapeSelection

    var selectedCircleIndex: Int? {
        guard let selectedCircleID else {
            return nil
        }

        return circles.firstIndex { $0.id == selectedCircleID }
    }

    var operationValueText: String {
        switch operationAxis {
        case .shapeSelection:
            if let selectedCircleIndex {
                return "\(selectedCircleIndex + 1) / \(circles.count)"
            } else {
                return "なし"
            }
        case .x, .y, .width, .height:
            guard
                let selectedCircleIndex,
                let property = operationAxis.editableProperty
            else {
                return "なし"
            }

            return "\(Int(circles[selectedCircleIndex].value(for: property)))"
        }
    }

    mutating func appendCircle(_ circle: DrawnCircle) {
        circles.append(circle)
        selectedCircleID = circle.id
    }

    mutating func clear() {
        circles.removeAll()
        selectedCircleID = nil
    }

    mutating func selectPreviousAxis() {
        guard let currentIndex = OperationAxis.allCases.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let previousIndex = (currentIndex - 1 + OperationAxis.allCases.count) % OperationAxis.allCases.count
        operationAxis = OperationAxis.allCases[previousIndex]
    }

    mutating func selectNextAxis() {
        guard let currentIndex = OperationAxis.allCases.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + 1) % OperationAxis.allCases.count
        operationAxis = OperationAxis.allCases[nextIndex]
    }

    mutating func applyLinearOperation(delta: CGFloat) {
        guard !circles.isEmpty else {
            selectedCircleID = nil
            return
        }

        if selectedCircleID == nil || selectedCircleIndex == nil {
            selectedCircleID = circles[0].id
        }

        if operationAxis == .shapeSelection {
            moveSelection(by: Int(delta))
            return
        }

        guard
            let selectedCircleIndex,
            let property = operationAxis.editableProperty
        else {
            return
        }

        circles[selectedCircleIndex].move(property: property, by: delta)
    }

    private mutating func moveSelection(by delta: Int) {
        guard !circles.isEmpty else {
            selectedCircleID = nil
            return
        }

        let currentIndex = selectedCircleIndex ?? 0
        let nextIndex = (currentIndex + delta + circles.count) % circles.count
        selectedCircleID = circles[nextIndex].id
    }
}
