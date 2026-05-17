import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var bridge = GraphEditorBridge()
    @State private var graphFocusRequest = 0
    @State private var graphZoomScale = 1.0
    @State private var graphGestureZoomScale = 1.0
    @State private var focusedPane = FocusedPane.graph

    private var currentGraphZoomScale: Double {
        clampZoomScale(graphZoomScale * graphGestureZoomScale)
    }

    private var treeSelection: Binding<Set<UUID>> {
        Binding(
            get: {
                bridge.selectedTreeNodeIDs
            },
            set: { newValue in
                focusedPane = .tree
                bridge.selectedTreeNodeIDs = newValue
            }
        )
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

    private var groupTreePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Group Tree")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            HStack(spacing: 8) {
                Button {
                    bridge.groupSelection()
                } label: {
                    Label("Group", systemImage: "folder.badge.plus")
                }
                .disabled(!bridge.canGroupSelection)

                Button {
                    bridge.ungroupSelection()
                } label: {
                    Label("Ungroup", systemImage: "folder.badge.minus")
                }
                .disabled(!bridge.canUngroupSelection)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: treeSelection) {
                ForEach(bridge.groupTreeRows) { row in
                    groupTreeRow(row)
                        .tag(row.id)
                        .selectionDisabled(!row.isSelectable)
                }
            }
            .listStyle(.sidebar)
            .background(
                TreeReturnKeyHandlingView {
                    focusedPane = .graph
                    graphFocusRequest += 1
                }
            )
            .overlay {
                focusRing(isFocused: focusedPane == .tree)
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func groupTreeRow(_ row: GroupTreeRow) -> some View {
        HStack(spacing: 6) {
            Image(systemName: row.isGroup ? "folder" : "circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(row.isGroup ? Color.primary : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                Text(row.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(row.depth * 14) + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background {
            if row.isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(focusedPane == .tree ? 0.18 : 0.10))
            }
        }
        .overlay {
            if row.isSelected, focusedPane != .tree {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                    .padding(.horizontal, 6)
            }
        }
        .opacity(row.isSelectable ? 1 : 0.72)
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

private enum FocusedPane {
    case graph
    case tree
}

private func focusRing(isFocused: Bool) -> some View {
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
