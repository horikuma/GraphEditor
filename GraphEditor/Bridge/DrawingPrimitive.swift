import SwiftUI

enum DrawingPrimitive: Identifiable {
    case circle(CirclePrimitive)
    case rectangle(RectanglePrimitive)
    case grid(GridPrimitive)
    case centroidCross(CentroidCrossPrimitive)

    var id: UUID {
        switch self {
        case let .circle(info):
            return info.id
        case let .rectangle(info):
            return info.id
        case let .grid(info):
            return info.id
        case let .centroidCross(info):
            return info.id
        }
    }
}

struct CirclePrimitive {
    let id: UUID
    let rect: CGRect
    let color: Color
    let isSelected: Bool
}

struct RectanglePrimitive {
    let id: UUID
    let rect: CGRect
    let rotationDegrees: Double
    let color: Color
    let isSelected: Bool
}

struct GridPrimitive {
    let id: UUID
    let verticalLinePositions: [CGFloat]
    let horizontalLinePositions: [CGFloat]
    let isSelected: Bool
}

struct CentroidCrossPrimitive {
    let id: UUID
    let point: CGPoint
    let isSelected: Bool
}
