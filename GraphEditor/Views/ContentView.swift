import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var bridge = GraphEditorBridge()

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

            Slider(value: $bridge.lineWidth, in: 1...16, step: 1) {
                Text("線幅")
            }
            .frame(width: 140)
            .help("線幅")

            Text("\(Int(bridge.lineWidth)) px")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Toggle("Fill", isOn: $bridge.fillCircles)
                .toggleStyle(.switch)
                .help("円を塗りつぶす")

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

                for primitive in bridge.drawingPrimitives(in: size) {
                    draw(primitive, in: &context, size: size)
                }
            }
            .background(KeyEventHandlingView(onKeyDown: bridge.handleKeyDown))
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
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        bridge.appendShape(at: value.location, in: geometry.size)
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

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(bridge.groupTreeRows) { row in
                        groupTreeRow(row)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func groupTreeRow(_ row: GroupTreeRow) -> some View {
        HStack(spacing: 6) {
            Image(systemName: row.isGroup ? "folder" : "circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(row.isGroup ? Color.accentColor : Color.secondary)
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
        .foregroundStyle(row.isSelected ? Color.accentColor : Color.primary)
        .background {
            if row.isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.12))
            }
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard row.isSelectable else {
                return
            }

            bridge.toggleTreeSelection(id: row.id)
        }
        .opacity(row.isSelectable ? 1 : 0.72)
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

    private func drawCircle(_ circle: CirclePrimitive, in context: inout GraphicsContext) {
        let path = Path(ellipseIn: circle.rect)
        let color = circle.color

        if circle.fill {
            context.fill(path, with: .color(color.opacity(0.18)))
        }
        context.stroke(path, with: .color(color), lineWidth: circle.lineWidth)

        if circle.isSelected {
            let selectionRect = circle.rect.insetBy(dx: -5, dy: -5)
            context.stroke(
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
