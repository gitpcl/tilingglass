// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI
import TilingCore

/// The visual layout editor: a scaled canvas of the layout's zones.
///
/// Interactions mirror Tiling Shell's editor:
/// - **Click** a zone → split it into left/right halves
/// - **Option-click** → split into top/bottom halves
/// - **Right-click** → context menu (split either way, delete)
/// - **Drag** a shared edge between zones → move that boundary segment
///
/// `groups` are recomputed from geometry on save, so edited layouts round-trip
/// into Tiling Shell with working shared-edge resize metadata.
struct LayoutEditorView: View {
    @ObservedObject var layoutStore: LayoutStore
    let onClose: () -> Void

    @State private var name: String
    @State private var tiles: [Tile]
    @State private var activeBoundary: LayoutBoundary?
    @State private var errorMessage: String?

    /// Minimum zone extent while dragging boundaries (5% of the screen).
    private let minTileSize = 0.05
    /// How close (in points) a drag must start to an edge to grab it.
    private let grabDistance: CGFloat = 8

    // `TilingCore.Layout` is spelled out because SwiftUI also exports a
    // `Layout` protocol and this file imports both.
    init(layoutStore: LayoutStore, editing layout: TilingCore.Layout, onClose: @escaping () -> Void) {
        self.layoutStore = layoutStore
        self.onClose = onClose
        _name = State(initialValue: layout.id)
        _tiles = State(initialValue: layout.tiles)
    }

    /// The working layout; the id only matters at save time.
    private var workingLayout: TilingCore.Layout {
        TilingCore.Layout(id: name.isEmpty ? "Untitled" : name, tiles: tiles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Click a zone to split it in two. Option-click splits top/bottom. Right-click for more, including delete. Drag shared edges to resize.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            editorCanvas
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .frame(minWidth: 480, minHeight: 300)

            HStack(spacing: 8) {
                TextField("Layout name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                Spacer()

                if layoutStore.hasCustomLayout(id: name) {
                    Button(role: .destructive) {
                        layoutStore.deleteCustomLayout(id: name)
                        onClose()
                    } label: {
                        Text(layoutStore.isBuiltin(id: name) ? "Restore Built-in" : "Delete Layout")
                    }
                }

                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    // MARK: - Canvas

    private var editorCanvas: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    let rect = pixelRect(for: tile, in: size)
                    ZoneEditorTile(index: index)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture {
                            let vertical = NSEvent.modifierFlags.contains(.option)
                            split(tileAt: index, vertical ? .vertical : .horizontal)
                        }
                        .contextMenu {
                            Button("Split Horizontally") { split(tileAt: index, .horizontal) }
                            Button("Split Vertically") { split(tileAt: index, .vertical) }
                            Divider()
                            Button("Delete Zone", role: .destructive) { remove(tileAt: index) }
                        }
                }
            }
            .contentShape(Rectangle())
            .gesture(boundaryDrag(in: size))
        }
    }

    private func boundaryDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if activeBoundary == nil {
                    let start = normalizedPoint(value.startLocation, in: size)
                    let tolerance = Double(grabDistance / max(size.width, 1))
                    activeBoundary = LayoutEditing.boundary(near: start, in: workingLayout, tolerance: tolerance)
                }
                guard let boundary = activeBoundary else { return }
                let point = normalizedPoint(value.location, in: size)
                let target = boundary.orientation == .vertical ? Double(point.x) : Double(point.y)
                tiles = LayoutEditing.movingBoundary(
                    workingLayout, boundary: boundary, to: target, minTileSize: minTileSize
                ).tiles
            }
            .onEnded { _ in activeBoundary = nil }
    }

    // MARK: - Actions

    private func split(tileAt index: Int, _ orientation: SplitOrientation) {
        tiles = LayoutEditing.splitting(workingLayout, tileAt: index, orientation).tiles
        errorMessage = nil
    }

    private func remove(tileAt index: Int) {
        guard let result = LayoutEditing.removing(workingLayout, tileAt: index) else {
            errorMessage = "That zone has no neighbor spanning its full edge to absorb it."
            return
        }
        tiles = result.tiles
        errorMessage = nil
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let candidate = LayoutEditing.recomputingGroups(TilingCore.Layout(id: trimmed, tiles: tiles))
        do {
            try candidate.validate()
        } catch {
            errorMessage = String(describing: error)
            return
        }
        layoutStore.saveCustomLayout(candidate)
        onClose()
    }

    // MARK: - Coordinate helpers (normalized top-left ⇄ view points)

    private func pixelRect(for tile: Tile, in size: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(tile.x) * size.width,
            y: CGFloat(tile.y) * size.height,
            width: CGFloat(tile.width) * size.width,
            height: CGFloat(tile.height) * size.height
        )
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / max(size.width, 1), y: point.y / max(size.height, 1))
    }
}

/// One zone in the editor canvas.
private struct ZoneEditorTile: View {
    let index: Int
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        shape
            .fill(hovered ? Color.accentColor.opacity(0.25) : Color.accentColor.opacity(0.12))
            .overlay(shape.strokeBorder(Color.accentColor.opacity(hovered ? 0.9 : 0.5), lineWidth: 1.5))
            .overlay(
                Text("\(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            )
            .padding(1.5)
            .onHover { hovered = $0 }
    }
}
