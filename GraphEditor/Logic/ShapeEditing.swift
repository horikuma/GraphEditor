import Foundation

enum OperationAxis: String, CaseIterable, Identifiable {
    case xCoordinate
    case yCoordinate
    case width
    case height
    case spacing
    case xOffset
    case yOffset
    case rotation

    var id: Self {
        self
    }

    var title: String {
        switch self {
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
        case .rotation:
            return "回転"
        }
    }

    var editableProperty: ShapeEditableProperty? {
        switch self {
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
        case .rotation:
            return .rotation
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
    case rotation
}

protocol EditableShape {
    var centroid: LogicPoint { get }
    var supportedOperationAxes: [OperationAxis] { get }

    func value(for property: ShapeEditableProperty) -> Double
    mutating func move(property: ShapeEditableProperty, by delta: Double)
}

protocol RotatableShape {
    var rotationArea: Double { get }

    mutating func rotateBy(degrees: Double, around pivot: LogicPoint)
}
