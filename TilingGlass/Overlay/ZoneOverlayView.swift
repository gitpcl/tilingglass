// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

/// Draws a screen's zones as Liquid Glass tiles. Zone rects are absolute,
/// panel-local, top-left coordinates (matching SwiftUI's origin), so each tile
/// is placed by its center.
///
/// The whole overlay materializes on appear and dissolves when `state.visible`
/// is cleared (see ``OverlayController``), and each zone's highlight settles with
/// a spring — both fall back to an opacity-only near-snap under Reduce Motion.
struct ZoneOverlayView: View {
    @ObservedObject var state: OverlayState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer {
            ZStack(alignment: .topLeading) {
                ForEach(Array(state.zones.enumerated()), id: \.offset) { index, rect in
                    ZoneTile(
                        highlighted: state.highlighted.contains(index),
                        spanning: state.isSpanning,
                        id: index,
                        namespace: glassNamespace
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        // Materialize/dissolve: scale is skipped under Reduce Motion, leaving a
        // short opacity fade only.
        .scaleEffect(reduceMotion ? 1 : (state.visible ? 1 : 0.97), anchor: .center)
        .opacity(state.visible ? 1 : 0)
        .animation(reduceMotion ? TGDesign.overlayReducedMotion : TGDesign.overlaySpring, value: state.visible)
        .onAppear { state.visible = true }
    }
}

/// A single zone. Uses a real Liquid Glass fill; a persistent stroke keeps the
/// zone legible even where glass renders faintly (e.g. in an inactive,
/// non-activating panel). Highlighting lifts the tile slightly and strengthens
/// the glass tint — a span selection strengthens it further still.
private struct ZoneTile: View {
    let highlighted: Bool
    let spanning: Bool
    let id: Int
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TGDesign.zoneCorner, style: .continuous)
        shape
            .fill(Color.clear)
            .glassEffect(glass, in: shape)
            .glassEffectID(id, in: namespace)
            .overlay(
                shape.strokeBorder(
                    highlighted ? Color.accentColor : TGDesign.idleStroke,
                    lineWidth: highlighted ? 3 : 1.5
                )
            )
            .scaleEffect(scale, anchor: .center)
            .padding(2)
            .animation(reduceMotion ? nil : TGDesign.highlightSpring, value: highlighted)
            .animation(reduceMotion ? nil : TGDesign.highlightSpring, value: spanning)
    }

    private var scale: CGFloat {
        (highlighted && !reduceMotion) ? TGDesign.highlightScale : 1
    }

    private var glass: Glass {
        guard highlighted else { return Glass.regular }
        let opacity = spanning ? TGDesign.spanTintOpacity : TGDesign.singleTintOpacity
        return Glass.regular.tint(.accentColor.opacity(opacity))
    }
}
