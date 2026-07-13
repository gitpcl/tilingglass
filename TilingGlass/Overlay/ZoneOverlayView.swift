import SwiftUI

/// Draws a screen's zones as Liquid Glass tiles. Zone rects are absolute,
/// panel-local, top-left coordinates (matching SwiftUI's origin), so each tile
/// is placed by its center.
struct ZoneOverlayView: View {
    @ObservedObject var state: OverlayState

    private let cornerRadius: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(state.zones.enumerated()), id: \.offset) { index, rect in
                ZoneTile(highlighted: state.highlighted.contains(index), cornerRadius: cornerRadius)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }
}

/// A single zone. Uses a real Liquid Glass fill; a persistent stroke keeps the
/// zone legible even where glass renders faintly (e.g. in an inactive,
/// non-activating panel).
private struct ZoneTile: View {
    let highlighted: Bool
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.clear)
            .glassEffect(glass, in: shape)
            .overlay(
                shape.strokeBorder(
                    highlighted ? Color.accentColor : Color.white.opacity(0.45),
                    lineWidth: highlighted ? 3 : 1.5
                )
            )
            .padding(2)
            .animation(.easeOut(duration: 0.12), value: highlighted)
    }

    private var glass: Glass {
        highlighted ? Glass.regular.tint(.accentColor.opacity(0.55)) : Glass.regular
    }
}
