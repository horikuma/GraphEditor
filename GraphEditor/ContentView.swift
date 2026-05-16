import SwiftUI
import AppKit

enum OperationAxis: CaseIterable {
    case shapeSelection
    case x
    case y
    case width
    case height

    var title: String {
        switch self {
        case .shapeSelection:
            return "図形選択"
        case .x:
            return "X軸座標"
        case .y:
            return "Y軸座標"
        case .width:
            return "Width"
        case .height:
            return "Height"
        }
    }

    var editableProperty: ShapeEditableProperty? {
        switch self {
        case .shapeSelection:
            nil
        case .x:
            .x
        case .y:
            .y
        case .width:
            .width
        case .height:
            .height
        }
    }
}

enum ShapeEditableProperty {
    case x
    case y
    case width
    case height
}

protocol EditableShape {
    func value(for property: ShapeEditableProperty) -> CGFloat
    mutating func move(property: ShapeEditableProperty, by delta: CGFloat)
}

struct DrawnCircle: Identifiable, EditableShape {
    let id = UUID()
    var rect: CGRect
    let color: Color
    let lineWidth: CGFloat

    func value(for property: ShapeEditableProperty) -> CGFloat {
        switch property {
        case .x:
            rect.origin.x
        case .y:
            rect.origin.y
        case .width:
            rect.width
        case .height:
            rect.height
        }
    }

    mutating func move(property: ShapeEditableProperty, by delta: CGFloat) {
        switch property {
        case .x:
            rect.origin.x += delta
        case .y:
            rect.origin.y += delta
        case .width, .height:
            let diameter = max(4, rect.width + delta)
            rect.size = CGSize(width: diameter, height: diameter)
        }
    }
}

struct ContentView: View {
    @State private var circles: [DrawnCircle] = []
    @State private var selectedCircleID: DrawnCircle.ID?
    @State private var operationAxis = OperationAxis.shapeSelection
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var strokeColor = Color.accentColor
    @State private var lineWidth = 3.0
    @State private var fillCircles = false

    private var selectedCircleIndex: Int? {
        guard let selectedCircleID else {
            return nil
        }

        return circles.firstIndex { $0.id == selectedCircleID }
    }

    private var operationValueText: String {
        switch operationAxis {
        case .shapeSelection:
            if let selectedCircleIndex {
                return "\(selectedCircleIndex + 1) / \(circles.count)"
            } else {
                return "なし"
            }
        case .x, .y, .width, .height:
            guard
                let selectedCircleIndex,
                let property = operationAxis.editableProperty
            else {
                return "なし"
            }

            return "\(Int(circles[selectedCircleIndex].value(for: property)))"
        }
    }

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
                selectedCircleID = nil
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
                    draw(
                        circle,
                        in: &context,
                        fill: fillCircles,
                        opacity: 1,
                        isSelected: circle.id == selectedCircleID
                    )
                }

                if let previewCircle {
                    draw(previewCircle, in: &context, fill: fillCircles, opacity: 0.65, isSelected: false)
                }
            }
            .background(KeyEventHandlingView(onKeyDown: handleKeyDown))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 14) {
                    Text("\(circles.count) circles")
                    Text("軸: \(operationAxis.title)")
                    Text("値: \(operationValueText)")
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
                        let rect = Self.circleRect(from: start, to: end)

                        if rect.width >= 4, rect.height >= 4 {
                            let circle = DrawnCircle(
                                rect: rect,
                                color: strokeColor,
                                lineWidth: lineWidth
                            )
                            circles.append(circle)
                            selectedCircleID = circle.id
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
            selectPreviousAxis()
        case 124:
            selectNextAxis()
        case 125:
            applyLinearOperation(delta: -1)
        case 126:
            applyLinearOperation(delta: 1)
        default:
            return false
        }

        return true
    }

    private func selectPreviousAxis() {
        guard let currentIndex = OperationAxis.allCases.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let previousIndex = (currentIndex - 1 + OperationAxis.allCases.count) % OperationAxis.allCases.count
        operationAxis = OperationAxis.allCases[previousIndex]
    }

    private func selectNextAxis() {
        guard let currentIndex = OperationAxis.allCases.firstIndex(of: operationAxis) else {
            operationAxis = .shapeSelection
            return
        }

        let nextIndex = (currentIndex + 1) % OperationAxis.allCases.count
        operationAxis = OperationAxis.allCases[nextIndex]
    }

    private func applyLinearOperation(delta: CGFloat) {
        guard !circles.isEmpty else {
            selectedCircleID = nil
            return
        }

        if selectedCircleID == nil || selectedCircleIndex == nil {
            selectedCircleID = circles[0].id
        }

        if operationAxis == .shapeSelection {
            moveSelection(by: Int(delta))
            return
        }

        guard
            let selectedCircleIndex,
            let property = operationAxis.editableProperty
        else {
            return
        }

        circles[selectedCircleIndex].move(property: property, by: delta)
    }

    private func moveSelection(by delta: Int) {
        guard !circles.isEmpty else {
            selectedCircleID = nil
            return
        }

        let currentIndex = selectedCircleIndex ?? 0
        let nextIndex = (currentIndex + delta + circles.count) % circles.count
        selectedCircleID = circles[nextIndex].id
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
