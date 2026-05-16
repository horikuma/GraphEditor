import CoreGraphics

enum OperationAxis: CaseIterable {
    case shapeSelection
    case xCoordinate
    case yCoordinate
    case width
    case height

    var title: String {
        switch self {
        case .shapeSelection:
            return "図形選択"
        case .xCoordinate:
            return "X軸座標"
        case .yCoordinate:
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
        case .xCoordinate:
            return .xCoordinate
        case .yCoordinate:
            return .yCoordinate
        case .width:
            return .width
        case .height:
            return .height
        }
    }
}

enum ShapeEditableProperty {
    case xCoordinate
    case yCoordinate
    case width
    case height
}

protocol EditableShape {
    func value(for property: ShapeEditableProperty) -> CGFloat
    mutating func move(property: ShapeEditableProperty, by delta: CGFloat)
}
