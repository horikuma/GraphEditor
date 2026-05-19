import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject var bridge = GraphEditorBridge()
    @State var graphFocusRequest = 0
    @State var graphZoomScale = 1.0
    @State var graphOffset = CGSize.zero
    @State var graphCursorLocation = CGPoint.zero
    @State var graphZoomGestureStartScale: Double?
    @State var graphZoomGestureStartOffset: CGSize?
    @State var graphZoomGestureAnchorLocation: CGPoint?
    @State var graphZoomGestureAnchorGraphLocation: CGPoint?
    @State var selectionDragLastGraphLocation: CGPoint?
    @State var focusedPane = FocusedPane.graph

    private var currentGraphZoomScale: Double {
        graphZoomScale
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                drawingSurface
                Divider()
                groupTreePanel
            }
        }
        .frame(minWidth: 900, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("追加", selection: $bridge.addableShapeKind) {
                ForEach(AddableShapeKind.allCases) { shapeKind in
                    Text(shapeKind.title).tag(shapeKind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .help("追加する図形")

            ColorPicker("Stroke", selection: $bridge.strokeColor)
                .labelsHidden()
                .help("線の色")

            Spacer()

            Button {
                bridge.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(bridge.isClearDisabled)
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

                let zoomScale = currentGraphZoomScale
                let scaledSize = scaledGraphSize(size)

                context.translateBy(x: graphOffset.width, y: graphOffset.height)
                context.scaleBy(x: zoomScale, y: zoomScale)
                for primitive in bridge.drawingPrimitives(in: scaledSize) {
                    draw(primitive, in: &context, size: scaledSize)
                }
            }
            .background(
                GraphInputHandlingView(
                    focusRequest: graphFocusRequest,
                    onKeyDown: bridge.handleKeyDown,
                    onScroll: panGraph
                )
            )
            .overlay(alignment: .bottomLeading) {
                let status = bridge.status
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
            .overlay {
                focusRing(isFocused: focusedPane == .graph)
            }
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                if case let .active(location) = phase {
                    graphCursorLocation = location
                }
            }
            .gesture(
                SpatialTapGesture(count: 2, coordinateSpace: .local)
                    .onEnded { value in
                        focusedPane = .graph
                        graphFocusRequest += 1
                        let scaledLocation = scaledGraphLocation(value.location)
                        let scaledSize = scaledGraphSize(geometry.size)
                        bridge.appendShape(at: scaledLocation, in: scaledSize)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture(count: 1, coordinateSpace: .local)
                    .onEnded { value in
                        focusedPane = .graph
                        graphFocusRequest += 1
                        bridge.selectShape(at: scaledGraphLocation(value.location))
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        updateSelectionDrag(value: value)
                    }
                    .onEnded { _ in
                        resetSelectionDrag()
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        updateGraphZoom(magnification: value, viewportSize: geometry.size)
                    }
                    .onEnded { value in
                        updateGraphZoom(magnification: value, viewportSize: geometry.size)
                        resetGraphZoomGesture()
                    }
            )
        }
    }

    private func scaledGraphLocation(_ location: CGPoint) -> CGPoint {
        graphLocation(at: location, zoomScale: currentGraphZoomScale, offset: graphOffset)
    }

    private func scaledGraphSize(_ size: CGSize) -> CGSize {
        let bottomRight = scaledGraphLocation(CGPoint(x: size.width, y: size.height))
        return CGSize(width: max(0, bottomRight.x), height: max(0, bottomRight.y))
    }

    private func updateGraphZoom(magnification: Double, viewportSize: CGSize) {
        let startScale = graphZoomGestureStartScale ?? graphZoomScale
        let startOffset = graphZoomGestureStartOffset ?? graphOffset
        let anchorLocation = graphZoomGestureAnchorLocation ?? clampedGraphCursorLocation(in: viewportSize)
        let anchorGraphLocation = graphZoomGestureAnchorGraphLocation
            ?? graphLocation(at: anchorLocation, zoomScale: startScale, offset: startOffset)
        let nextScale = clampZoomScale(startScale * magnification)

        graphZoomGestureStartScale = startScale
        graphZoomGestureStartOffset = startOffset
        graphZoomGestureAnchorLocation = anchorLocation
        graphZoomGestureAnchorGraphLocation = anchorGraphLocation
        graphZoomScale = nextScale
        graphOffset = CGSize(
            width: anchorLocation.x - anchorGraphLocation.x * nextScale,
            height: anchorLocation.y - anchorGraphLocation.y * nextScale
        )
    }

    private func resetGraphZoomGesture() {
        graphZoomGestureStartScale = nil
        graphZoomGestureStartOffset = nil
        graphZoomGestureAnchorLocation = nil
        graphZoomGestureAnchorGraphLocation = nil
    }

    private func updateSelectionDrag(value: DragGesture.Value) {
        focusedPane = .graph
        graphFocusRequest += 1

        let graphLocation = scaledGraphLocation(value.location)
        guard let lastGraphLocation = selectionDragLastGraphLocation else {
            if bridge.canDragSelection(at: scaledGraphLocation(value.startLocation)) {
                selectionDragLastGraphLocation = graphLocation
            }
            return
        }

        bridge.translateSelectionBy(
            CGSize(
                width: graphLocation.x - lastGraphLocation.x,
                height: graphLocation.y - lastGraphLocation.y
            )
        )
        selectionDragLastGraphLocation = graphLocation
    }

    private func resetSelectionDrag() {
        selectionDragLastGraphLocation = nil
    }

    private func panGraph(by delta: CGSize) {
        graphOffset.width += delta.width
        graphOffset.height += delta.height
        resetGraphZoomGesture()
    }

    private func clampedGraphCursorLocation(in viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(graphCursorLocation.x, 0), viewportSize.width),
            y: min(max(graphCursorLocation.y, 0), viewportSize.height)
        )
    }

    private func graphLocation(at location: CGPoint, zoomScale: Double, offset: CGSize) -> CGPoint {
        CGPoint(
            x: (location.x - offset.width) / zoomScale,
            y: (location.y - offset.height) / zoomScale
        )
    }

}

enum FocusedPane {
    case graph
    case tree
    case operationAxis
}

func focusRing(isFocused: Bool) -> some View {
    RoundedRectangle(cornerRadius: 0)
        .strokeBorder(
            isFocused ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.18),
            lineWidth: isFocused ? 2 : 1
        )
        .allowsHitTesting(false)
}

private func clampZoomScale(_ zoomScale: Double) -> Double {
    min(max(zoomScale, 0.25), 4)
}
