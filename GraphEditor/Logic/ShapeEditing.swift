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

}

protocol EditableShape {
    var centroid: LogicPoint { get }
    var supportedOperationAxes: [OperationAxis] { get }

    func value(for axis: OperationAxis) -> Double
    mutating func move(axis: OperationAxis, by delta: Double)
}

protocol RotatableShape {
    var rotationArea: Double { get }

    mutating func rotateBy(degrees: Double, around pivot: LogicPoint)
}
