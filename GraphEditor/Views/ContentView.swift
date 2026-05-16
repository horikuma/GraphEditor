import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var logic = GraphEditorLogic()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            drawingSurface
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("追加", selection: $logic.addableShapeKind) {
                ForEach(AddableShapeKind.allCases) { shapeKind in
                    Text(shapeKind.title).tag(shapeKind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .help("追加する図形")

            ColorPicker("Stroke", selection: $logic.strokeColor)
                .labelsHidden()
                .help("線の色")

            Slider(value: $logic.lineWidth, in: 1...16, step: 1) {
                Text("線幅")
            }
            .frame(width: 140)
            .help("線幅")

            Text("\(Int(logic.lineWidth)) px")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Toggle("Fill", isOn: $logic.fillCircles)
                .toggleStyle(.switch)
                .help("円を塗りつぶす")

            Spacer()

            Button {
                logic.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(logic.isClearDisabled)
            .help("すべて消去")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var drawingSurface: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let background = Path(CGRect(origin: .zero, size: size))
                context.fill(background, with: .color(Color(nsColor: .textBackgroundColor)))

                for primitive in logic.drawingPrimitives(in: size) {
                    draw(primitive, in: &context, size: size)
                }
            }
            .background(KeyEventHandlingView(onKeyDown: logic.handleKeyDown))
            .overlay(alignment: .bottomLeading) {
                let status = logic.statusInfo
                HStack(spacing: 14) {
                    Text(status.objectCountText)
                    Text(status.selectedShapeText)
                    Text(status.operationAxisText)
                    Text(status.operationValueText)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(10)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        logic.appendShape(at: value.location, in: geometry.size)
                    }
            )
        }
    }

    private func draw(_ primitive: DrawingPrimitive, in context: inout GraphicsContext, size: CGSize) {
        switch primitive {
        case let .circle(info):
            drawCircle(info, in: &context)
        case let .grid(info):
            drawGrid(info, in: &context, size: size)
        case let .centroidCross(info):
            drawCentroidCross(info, in: &context)
        }
    }

    private func drawCircle(_ info: CircleDrawingInfo, in context: inout GraphicsContext) {
        let path = Path(ellipseIn: info.rect)
        let color = info.color

        if info.fill {
            context.fill(path, with: .color(color.opacity(0.18)))
        }
        context.stroke(path, with: .color(color), lineWidth: info.lineWidth)

        if info.isSelected {
            let selectionRect = info.rect.insetBy(dx: -5, dy: -5)
            context.stroke(
                Path(selectionRect),
                with: .color(Color.primary.opacity(0.45)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        }
    }

    private func drawGrid(_ info: GridDrawingInfo, in context: inout GraphicsContext, size: CGSize) {
        var path = Path()

        info.verticalLinePositions.forEach { gridX in
            path.move(to: CGPoint(x: gridX, y: 0))
            path.addLine(to: CGPoint(x: gridX, y: size.height))
        }

        info.horizontalLinePositions.forEach { gridY in
            path.move(to: CGPoint(x: 0, y: gridY))
            path.addLine(to: CGPoint(x: size.width, y: gridY))
        }

        let opacity = info.isSelected ? 0.28 : 0.16
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.5)
    }

    private func drawCentroidCross(_ info: CentroidCrossDrawingInfo, in context: inout GraphicsContext) {
        var path = Path()
        let length: CGFloat = info.isSelected ? 16 : 12

        path.move(to: CGPoint(x: info.point.x - length / 2, y: info.point.y))
        path.addLine(to: CGPoint(x: info.point.x + length / 2, y: info.point.y))
        path.move(to: CGPoint(x: info.point.x, y: info.point.y - length / 2))
        path.addLine(to: CGPoint(x: info.point.x, y: info.point.y + length / 2))

        let opacity = info.isSelected ? 0.55 : 0.35
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.75)
    }

}
