// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import TilingCore

/// Turns tiling intent into window moves. Two entry points: dropping a dragged
/// window into a zone selection, and moving the focused window one zone in a
/// direction (crossing monitors as needed).
///
/// All zone math is done in AppKit space for drops (matching the overlay and
/// cursor) or AX space for keyboard moves (matching the focused-window frame),
/// with a single flip to AX coordinates just before the move.
@MainActor
final class TilingEngine {
    private let screenService: ScreenService
    private let settings: SettingsStore
    private let layoutStore: LayoutStore

    init(screenService: ScreenService, settings: SettingsStore, layoutStore: LayoutStore) {
        self.screenService = screenService
        self.settings = settings
        self.layoutStore = layoutStore
    }

    // MARK: - Drag drop

    /// Moves `window` to fill the `selection` of `layout` on `screen`.
    /// `screen`/`layout` describe what the user saw in the overlay.
    @discardableResult
    func tile(
        _ window: AccessibilityElement, selection: Set<Int>,
        screen: ScreenInfo, layout: Layout
    ) -> WindowMover.Result {
        guard let normalized = ZoneHitTesting.targetNormalizedRect(for: selection, layout: layout) else {
            return .failed
        }
        // Resolve directly in the screen's AX (top-left) frame: ZoneGeometry and
        // AX window positions share that origin, so no flip is needed. Resolving
        // in AppKit space would mirror vertical layouts.
        let axRect = ZoneGeometry.resolve(
            normalizedRect: normalized, in: screen.axVisibleFrame, gaps: settings.gaps
        )
        return WindowMover.move(window, to: axRect)
    }

    // MARK: - Keyboard moves

    /// Moves the focused window one zone in `direction`, crossing to an adjacent
    /// monitor when there is no further zone on the current one.
    @discardableResult
    func moveFocused(_ direction: TileDirection) -> WindowMover.Result {
        guard AccessibilityElement.isTrusted,
              let window = AccessibilityElement.focusedWindow(),
              let axFrame = window.frame else {
            return .failed
        }

        let screens = screenService.screens
        guard !screens.isEmpty else { return .failed }

        // Build navigation slots in AX space (top-left), one per screen.
        let slots = screens.enumerated().map { index, screen in
            ScreenSlot(
                id: index,
                frame: screen.axVisibleFrame,
                layout: layoutStore.layout(forScreen: screen.uuid)
            )
        }

        let center = CGPoint(x: axFrame.midX, y: axFrame.midY)
        let currentIndex = screens.firstIndex { $0.axVisibleFrame.contains(center) } ?? 0
        let currentTile = ZoneHitTesting.tileIndex(
            at: center, layout: slots[currentIndex].layout, screenRect: screens[currentIndex].axVisibleFrame
        )

        guard let destination = DirectionalNavigation.destination(
            windowFrame: axFrame,
            currentTileIndex: currentTile,
            direction: direction,
            screens: slots,
            currentScreenID: currentIndex
        ) else {
            return .failed
        }

        let destScreen = screens[destination.screenID]
        let destLayout = slots[destination.screenID].layout
        return tile(window, selection: [destination.tileIndex], screen: destScreen, layout: destLayout)
    }
}
