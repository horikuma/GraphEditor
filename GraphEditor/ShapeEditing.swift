import CoreGraphics

enum OperationAxis: CaseIterable {
    case shapeSelection
    case x
    case y
    case width
    case height

    var title: String {
        switch self {
        case .shapeSelection:
            return "図形選択"
        case .x:
            return "X軸座標"
        case .y:
            return "Y軸座標"
        case .width:
            return "Width"
        case .height:
            return "Height"
        }
    }

    var editableProperty: ShapeEditableProperty? {
        switch self {
        case .shapeSelection:
            return nil
        case .x:
            return .x
        case .y:
            return .y
        case .width:
            return .width
        case .height:
            return .height
        }
    }
}

enum ShapeEditableProperty {
    case x
    case y
    case width
    case height
}

protocol EditableShape {
    func value(for property: ShapeEditableProperty) -> CGFloat
    mutating func move(property: ShapeEditableProperty, by delta: CGFloat)
}
