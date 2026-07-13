// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import TilingCore

/// Manages the per-screen overlay panels: creating them on show, updating the
/// highlighted zone as the cursor moves, and tearing them all down on hide.
///
/// Panels exist only while the overlay is shown — there are no persistent
/// windows or timers, so the idle app costs nothing.
@MainActor
final class OverlayController {
    private var panels: [String: OverlayPanel] = [:]
    private var states: [String: OverlayState] = [:]

    /// The layout shown on each screen (by UUID) while visible, so callers can
    /// hit-test against exactly what the user sees.
    private(set) var shownLayouts: [String: Layout] = [:]

    var isShown: Bool { !panels.isEmpty }

    /// Shows the overlay on every screen, drawing each screen's resolved layout.
    func show(screens: [ScreenInfo], gaps: Gaps, layoutForScreen: (ScreenInfo) -> Layout) {
        hide()
        for screen in screens {
            let layout = layoutForScreen(screen)
            let localRect = CGRect(origin: .zero, size: screen.appKitVisibleFrame.size)
            let zones = layout.tiles.map { ZoneGeometry.resolve($0, in: localRect, gaps: gaps) }

            let state = OverlayState()
            state.zones = zones

            let panel = OverlayPanel(frame: screen.appKitVisibleFrame, state: state)
            panel.orderFrontRegardless()

            panels[screen.uuid] = panel
            states[screen.uuid] = state
            shownLayouts[screen.uuid] = layout
        }
    }

    /// Highlights `tiles` on the given screen and clears highlights elsewhere.
    func highlight(screenUUID: String?, tiles: Set<Int>) {
        for (uuid, state) in states {
            state.setHighlight(uuid == screenUUID ? tiles : [])
        }
    }

    func clearHighlights() {
        for state in states.values { state.setHighlight([]) }
    }

    func hide() {
        for panel in panels.values {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        states.removeAll()
        shownLayouts.removeAll()
    }
}
