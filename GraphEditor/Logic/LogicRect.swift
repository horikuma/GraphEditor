import Foundation

struct LogicRect {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double {
        maxX - minX
    }

    var height: Double {
        maxY - minY
    }

    func union(_ other: LogicRect) -> LogicRect {
        LogicRect(
            minX: min(minX, other.minX),
            minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY)
        )
    }
}
