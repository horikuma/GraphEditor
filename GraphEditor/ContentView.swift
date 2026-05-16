import SwiftUI
import AppKit

struct ContentView: View {
    @State private var content = GraphEditorContent()
    @State private var strokeColor = Color.accentColor
    @State private var lineWidth = 3.0
    @State private var fillCircles = false

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
            Picker("追加", selection: $content.addableShapeKind) {
                ForEach(AddableShapeKind.allCases) { shapeKind in
                    Text(shapeKind.title).tag(shapeKind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .help("追加する図形")

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
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(content.shapes.isEmpty)
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

                for shape in content.shapes where shape.isGrid {
                    drawShape(
                        shape,
                        in: &context,
                        size: size,
                        fill: fillCircles,
                        isSelected: shape.id == content.selectedShapeID
                    )
                }

                for shape in content.shapes where !shape.isGrid {
                    drawShape(
                        shape,
                        in: &context,
                        size: size,
                        fill: fillCircles,
                        isSelected: shape.id == content.selectedShapeID
                    )
                }

            }
            .background(KeyEventHandlingView(onKeyDown: handleKeyDown))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 14) {
                    Text("\(content.shapes.count) objects")
                    Text("図形: \(content.selectedShapeLabel)")
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
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        let location = Self.clamp(value.location, in: geometry.size)
                        appendShape(at: location)
                    }
            )
        }
    }

    private func appendShape(at location: CGPoint) {
        switch content.addableShapeKind {
        case .circle:
            content.appendCircle(
                DrawnCircle(
                    center: location,
                    diameter: 48,
                    color: strokeColor,
                    lineWidth: lineWidth
                )
            )
        case .grid:
            content.appendGrid(DrawnGrid(origin: location, spacing: 24))
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123:
            content.selectPreviousAxis()
        case 124:
            content.selectNextAxis()
        case 125:
            content.applyLinearOperation(delta: -keyStep(for: event))
        case 126:
            content.applyLinearOperation(delta: keyStep(for: event))
        default:
            return false
        }

        return true
    }

    private func keyStep(for event: NSEvent) -> CGFloat {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) ? 10 : 1
    }

    private func drawShape(
        _ shape: GraphShape,
        in context: inout GraphicsContext,
        size: CGSize,
        fill: Bool,
        isSelected: Bool
    ) {
        switch shape {
        case let .circle(circle):
            drawCircle(circle, in: &context, fill: fill, opacity: 1, isSelected: isSelected)
        case let .grid(grid):
            drawGrid(grid, in: &context, size: size, isSelected: isSelected)
        }

        if shape.showsCentroidCrossByDefault || isSelected {
            drawCentroidCross(at: shape.centroid, in: &context, isSelected: isSelected)
        }
    }

    private func drawCircle(
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

    private func drawGrid(_ grid: DrawnGrid, in context: inout GraphicsContext, size: CGSize, isSelected: Bool) {
        var path = Path()
        let step = max(grid.spacing, 4)
        let startX = Self.firstVisibleLineOffset(for: grid.origin.x, step: step)
        let startY = Self.firstVisibleLineOffset(for: grid.origin.y, step: step)

        stride(from: startX, through: size.width, by: step).forEach { gridX in
            path.move(to: CGPoint(x: gridX, y: 0))
            path.addLine(to: CGPoint(x: gridX, y: size.height))
        }

        stride(from: startY, through: size.height, by: step).forEach { gridY in
            path.move(to: CGPoint(x: 0, y: gridY))
            path.addLine(to: CGPoint(x: size.width, y: gridY))
        }

        let opacity = isSelected ? 0.28 : 0.16
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.5)
    }

    private func drawCentroidCross(at point: CGPoint, in context: inout GraphicsContext, isSelected: Bool) {
        var path = Path()
        let length: CGFloat = isSelected ? 16 : 12

        path.move(to: CGPoint(x: point.x - length / 2, y: point.y))
        path.addLine(to: CGPoint(x: point.x + length / 2, y: point.y))
        path.move(to: CGPoint(x: point.x, y: point.y - length / 2))
        path.addLine(to: CGPoint(x: point.x, y: point.y + length / 2))

        let opacity = isSelected ? 0.55 : 0.35
        context.stroke(path, with: .color(Color.gray.opacity(opacity)), lineWidth: 0.75)
    }

    private static func firstVisibleLineOffset(for origin: CGFloat, step: CGFloat) -> CGFloat {
        let remainder = origin.truncatingRemainder(dividingBy: step)
        return remainder >= 0 ? remainder : remainder + step
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
