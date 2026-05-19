import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject var bridge = GraphEditorBridge()
    @State var graphFocusRequest = 0
    @State var graphZoomScale = 1.0
    @State var graphGestureZoomScale = 1.0
    @State var focusedPane = FocusedPane.graph

    private var currentGraphZoomScale: Double {
        clampZoomScale(graphZoomScale * graphGestureZoomScale)
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
                let scaledSize = CGSize(width: size.width / zoomScale, height: size.height / zoomScale)

                context.scaleBy(x: zoomScale, y: zoomScale)
                for primitive in bridge.drawingPrimitives(in: scaledSize) {
                    draw(primitive, in: &context, size: scaledSize)
                }
            }
            .background(
                KeyEventHandlingView(
                    focusRequest: graphFocusRequest,
                    onKeyDown: bridge.handleKeyDown
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
                MagnificationGesture()
                    .onChanged { value in
                        graphGestureZoomScale = value
                    }
                    .onEnded { value in
                        graphZoomScale = clampZoomScale(graphZoomScale * value)
                        graphGestureZoomScale = 1
                    }
            )
        }
    }

    private func scaledGraphLocation(_ location: CGPoint) -> CGPoint {
        let zoomScale = currentGraphZoomScale
        return CGPoint(x: location.x / zoomScale, y: location.y / zoomScale)
    }

    private func scaledGraphSize(_ size: CGSize) -> CGSize {
        let zoomScale = currentGraphZoomScale
        return CGSize(width: size.width / zoomScale, height: size.height / zoomScale)
    }

}

enum FocusedPane {
    case graph
    case tree
    case operationAxis
}

func focusRing(isFocused: Bool) -> some View {
    RoundedRectangle(cornerRadius: 0)
        .stroke(
            isFocused ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.18),
            lineWidth: isFocused ? 2 : 1
        )
        .allowsHitTesting(false)
}

private func clampZoomScale(_ zoomScale: Double) -> Double {
    min(max(zoomScale, 0.25), 4)
}
