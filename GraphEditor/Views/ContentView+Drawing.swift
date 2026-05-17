import SwiftUI

extension ContentView {
    func draw(_ primitive: DrawingPrimitive, in context: inout GraphicsContext, size: CGSize) {
        switch primitive {
        case let .circle(info):
            drawCircle(info, in: &context)
        case let .rectangle(info):
            drawRectangle(info, in: &context)
        case let .grid(info):
            drawGrid(info, in: &context, size: size)
        case let .centroidCross(info):
            drawCentroidCross(info, in: &context)
        }
    }

    private func drawCircle(_ circle: CirclePrimitive, in context: inout GraphicsContext) {
        let path = Path(ellipseIn: circle.rect)
        let color = circle.color

        context.fill(path, with: .color(color.opacity(0.18)))

        if circle.isSelected {
            let selectionRect = circle.rect.insetBy(dx: -5, dy: -5)
            context.stroke(
                Path(selectionRect),
                with: .color(Color.primary.opacity(0.45)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        }
    }

    private func drawRectangle(_ rectangle: RectanglePrimitive, in context: inout GraphicsContext) {
        let path = Path(rectangle.rect)
        let color = rectangle.color
        var rotatedContext = context
        let center = CGPoint(x: rectangle.rect.midX, y: rectangle.rect.midY)

        rotatedContext.translateBy(x: center.x, y: center.y)
        rotatedContext.rotate(by: .degrees(rectangle.rotationDegrees))
        rotatedContext.translateBy(x: -center.x, y: -center.y)
        rotatedContext.fill(path, with: .color(color.opacity(0.18)))

        if rectangle.isSelected {
            let selectionRect = rectangle.rect.insetBy(dx: -5, dy: -5)
            rotatedContext.stroke(
                Path(selectionRect),
                with: .color(Color.primary.opacity(0.45)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        }
    }

    private func drawGrid(_ grid: GridPrimitive, in context: inout GraphicsContext, size: CGSize) {
        var path = Path()

        grid.verticalLinePositions.forEach { gridX in
            path.move(to: CGPoint(x: gridX, y: 0))
            path.addLine(to: CGPoint(x: gridX, y: size.height))
        }

        grid.horizontalLinePositions.forEach { gridY in
            path.move(to: CGPoint(x: 0, y: gridY))
            path.addLine(to: CGPoint(x: size.width, y: gridY))
        }

        let opacity = grid.isSelected ? 0.28 : 0.16
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.5)
    }

    private func drawCentroidCross(_ cross: CentroidCrossPrimitive, in context: inout GraphicsContext) {
        var path = Path()
        let length: CGFloat = cross.isSelected ? 16 : 12

        path.move(to: CGPoint(x: cross.point.x - length / 2, y: cross.point.y))
        path.addLine(to: CGPoint(x: cross.point.x + length / 2, y: cross.point.y))
        path.move(to: CGPoint(x: cross.point.x, y: cross.point.y - length / 2))
        path.addLine(to: CGPoint(x: cross.point.x, y: cross.point.y + length / 2))

        let opacity = cross.isSelected ? 0.55 : 0.35
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.75)
    }
}
