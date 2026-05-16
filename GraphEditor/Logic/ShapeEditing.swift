import Foundation

enum OperationAxis: CaseIterable {
    case shapeSelection
    case xCoordinate
    case yCoordinate
    case width
    case height
    case spacing
    case xOffset
    case yOffset

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
        case .spacing:
            return "間隔"
        case .xOffset:
            return "X軸移動"
        case .yOffset:
            return "Y軸移動"
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
        case .spacing:
            return .spacing
        case .xOffset:
            return .xOffset
        case .yOffset:
            return .yOffset
        }
    }
}

enum ShapeEditableProperty {
    case xCoordinate
    case yCoordinate
    case width
    case height
    case spacing
    case xOffset
    case yOffset
}

protocol EditableShape {
    var centroid: LogicPoint { get }
    var supportedOperationAxes: [OperationAxis] { get }

    func value(for property: ShapeEditableProperty) -> Double
    mutating func move(property: ShapeEditableProperty, by delta: Double)
}
