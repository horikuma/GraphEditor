import SwiftUI
import AppKit

struct ContentView: View {
    @State private var content = GraphEditorContent()
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var strokeColor = Color.accentColor
    @State private var lineWidth = 3.0
    @State private var fillCircles = false

    private var previewCircle: DrawnCircle? {
        guard let dragStart, let dragCurrent else {
            return nil
        }

        return Self.circle(from: dragStart, to: dragCurrent, color: strokeColor, lineWidth: lineWidth)
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
                content.clear()
                dragStart = nil
                dragCurrent = nil
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(content.circles.isEmpty && previewCircle == nil)
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

                for circle in content.circles {
                    draw(
                        circle,
                        in: &context,
                        fill: fillCircles,
                        opacity: 1,
                        isSelected: circle.id == content.selectedCircleID
                    )
                }

                if let previewCircle {
                    draw(previewCircle, in: &context, fill: fillCircles, opacity: 0.65, isSelected: false)
                }
            }
            .background(KeyEventHandlingView(onKeyDown: handleKeyDown))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 14) {
                    Text("\(content.circles.count) circles")
                    Text("軸: \(content.operationAxis.title)")
                    Text("値: \(content.operationValueText)")
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
                        let circle = Self.circle(from: start, to: end, color: strokeColor, lineWidth: lineWidth)

                        if circle.diameter >= 4 {
                            content.appendCircle(circle)
                        }

                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func draw(
        _ circle: DrawnCircle,
        in context: inout GraphicsContext,
        fill: Bool,
        opacity: Double,
        isSelected: Bool
    ) {
        let path = Path(ellipseIn: circle.rect)
        let color = circle.color.opacity(opacity)

        if fill {
            context.fill(path, with: .color(color.opacity(0.18)))
        }
        context.stroke(path, with: .color(color), lineWidth: circle.lineWidth)

        if isSelected {
            let selectionRect = circle.rect.insetBy(dx: -5, dy: -5)
            context.stroke(
                Path(selectionRect),
                with: .color(Color.primary.opacity(0.45)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123:
            content.selectPreviousAxis()
        case 124:
            content.selectNextAxis()
        case 125:
            content.applyLinearOperation(delta: -1)
        case 126:
            content.applyLinearOperation(delta: 1)
        default:
            return false
        }

        return true
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let step: CGFloat = 24

        stride(from: CGFloat.zero, through: size.width, by: step).forEach { gridX in
            path.move(to: CGPoint(x: gridX, y: 0))
            path.addLine(to: CGPoint(x: gridX, y: size.height))
        }

        stride(from: CGFloat.zero, through: size.height, by: step).forEach { gridY in
            path.move(to: CGPoint(x: 0, y: gridY))
            path.addLine(to: CGPoint(x: size.width, y: gridY))
        }

        context.stroke(path, with: .color(Color.secondary.opacity(0.12)), lineWidth: 0.5)
    }

    private static func circle(from start: CGPoint, to end: CGPoint, color: Color, lineWidth: CGFloat) -> DrawnCircle {
        let rect = circleRect(from: start, to: end)

        return DrawnCircle(
            center: CGPoint(x: rect.midX, y: rect.midY),
            diameter: rect.width,
            color: color,
            lineWidth: lineWidth
        )
    }

    private static func circleRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let diameter = min(abs(end.x - start.x), abs(end.y - start.y))
        let originX = end.x >= start.x ? start.x : start.x - diameter
        let originY = end.y >= start.y ? start.y : start.y - diameter

        return CGRect(x: originX, y: originY, width: diameter, height: diameter)
    }

    private static func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}

private struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyEventNSView {
        let view = KeyEventNSView()
        view.onKeyDown = onKeyDown

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyEventNSView, context: Context) {
        nsView.onKeyDown = onKeyDown

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyEventNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }

        super.keyDown(with: event)
    }
}
