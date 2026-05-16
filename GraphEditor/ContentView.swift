import SwiftUI

struct DrawnCircle: Identifiable {
    let id = UUID()
    let rect: CGRect
    let color: Color
    let lineWidth: CGFloat
}

struct ContentView: View {
    @State private var circles: [DrawnCircle] = []
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var strokeColor = Color.accentColor
    @State private var lineWidth = 3.0
    @State private var fillCircles = false

    private var previewCircle: DrawnCircle? {
        guard let dragStart, let dragCurrent else {
            return nil
        }

        return DrawnCircle(
            rect: Self.circleRect(from: dragStart, to: dragCurrent),
            color: strokeColor,
            lineWidth: lineWidth
        )
    }

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
            ColorPicker("Stroke", selection: $strokeColor)
                .labelsHidden()
                .help("線の色")

            Slider(value: $lineWidth, in: 1...16, step: 1) {
                Text("線幅")
            }
            .frame(width: 140)
            .help("線幅")

            Text("\(Int(lineWidth)) px")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Toggle("Fill", isOn: $fillCircles)
                .toggleStyle(.switch)
                .help("円を塗りつぶす")

            Spacer()

            Button {
                circles.removeAll()
                dragStart = nil
                dragCurrent = nil
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(circles.isEmpty && previewCircle == nil)
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

                drawGrid(in: &context, size: size)

                for circle in circles {
                    draw(circle, in: &context, fill: fillCircles, opacity: 1)
                }

                if let previewCircle {
                    draw(previewCircle, in: &context, fill: fillCircles, opacity: 0.65)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text("\(circles.count) circles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(10)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        dragCurrent = Self.clamp(value.location, in: geometry.size)
                    }
                    .onEnded { value in
                        let start = dragStart ?? value.startLocation
                        let end = Self.clamp(value.location, in: geometry.size)
                        let rect = Self.circleRect(from: start, to: end)

                        if rect.width >= 4, rect.height >= 4 {
                            circles.append(
                                DrawnCircle(
                                    rect: rect,
                                    color: strokeColor,
                                    lineWidth: lineWidth
                                )
                            )
                        }

                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func draw(_ circle: DrawnCircle, in context: inout GraphicsContext, fill: Bool, opacity: Double) {
        let path = Path(ellipseIn: circle.rect)
        let color = circle.color.opacity(opacity)

        if fill {
            context.fill(path, with: .color(color.opacity(0.18)))
        }
        context.stroke(path, with: .color(color), lineWidth: circle.lineWidth)
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let step: CGFloat = 24

        stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.stroke(path, with: .color(Color.secondary.opacity(0.12)), lineWidth: 0.5)
    }

    private static func circleRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let diameter = min(abs(end.x - start.x), abs(end.y - start.y))
        let x = end.x >= start.x ? start.x : start.x - diameter
        let y = end.y >= start.y ? start.y : start.y - diameter

        return CGRect(x: x, y: y, width: diameter, height: diameter)
    }

    private static func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
