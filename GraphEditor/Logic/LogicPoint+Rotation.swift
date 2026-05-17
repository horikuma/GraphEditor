import Foundation

extension LogicPoint {
    func rotated(degrees: Double, around pivot: LogicPoint) -> LogicPoint {
        let radians = degrees * .pi / 180
        let xOffset = xCoordinate - pivot.xCoordinate
        let yOffset = yCoordinate - pivot.yCoordinate
        let cosine = cos(radians)
        let sine = sin(radians)

        return LogicPoint(
            xCoordinate: pivot.xCoordinate + xOffset * cosine - yOffset * sine,
            yCoordinate: pivot.yCoordinate + xOffset * sine + yOffset * cosine
        )
    }
}
