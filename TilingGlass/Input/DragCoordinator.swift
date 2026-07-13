// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import TilingCore

/// Drives the tiling system state machine from raw drag events:
///
/// `idle → (mouseDown) candidate → (real move) dragging → (activation modifier)
/// overlay shown → (hover) zone highlighted → (mouseUp) drop | (modifier off)
/// back to dragging`.
///
/// The overlay is shown only while the activation modifier is held during a real
/// window drag. Highlight state is updated only when the hovered zone changes,
/// keeping per-event work minimal. Cursor hit-testing is done in AX (top-left)
/// coordinates so it matches how the overlay draws zones and how windows are
/// positioned.
@MainActor
final class DragCoordinator {
    private let settings: SettingsStore
    private let screenService: ScreenService
    private let overlay: OverlayController
    private let engine: TilingEngine
    private let layoutStore: LayoutStore

    private var session: DragSession?
    private var currentFlags: NSEvent.ModifierFlags = []

    private let dragThreshold: CGFloat = 5
    /// How many drag events to keep checking for an actual window move before
    /// giving up and treating the gesture as non-tiling (text selection/resize).
    /// Bounded so a lagging AX response doesn't permanently suppress a real drag.
    private let maxConfirmAttempts = 20

    init(
        settings: SettingsStore, screenService: ScreenService,
        overlay: OverlayController, engine: TilingEngine, layoutStore: LayoutStore
    ) {
        self.settings = settings
        self.screenService = screenService
        self.overlay = overlay
        self.engine = engine
        self.layoutStore = layoutStore
    }

    func handle(_ event: DragInputEvent) {
        switch event {
        case let .mouseDown(point):
            beginCandidate(at: point)
        case let .mouseDragged(point):
            updateDrag(at: point)
        case let .mouseUp(point):
            endDrag(at: point)
        case let .flagsChanged(flags):
            currentFlags = flags.intersection(.deviceIndependentFlagsMask)
            reevaluateOverlay(at: NSEvent.mouseLocation)
        }
    }

    /// Called when the display configuration changes. Tears down any overlay and
    /// abandons the in-progress session so stale screen frames aren't reused.
    func handleDisplaysChanged() {
        overlay.hide()
        session = nil
    }

    /// Seeds the tracked modifier state from the live keyboard state. See the
    /// call site in `AppDelegate.startMonitoringIfTrusted()` for why this is
    /// needed — `flagsChanged` only reports transitions, not the state at the
    /// time monitoring begins.
    func seedModifierFlags(_ flags: NSEvent.ModifierFlags) {
        currentFlags = flags.intersection(.deviceIndependentFlagsMask)
    }

    // MARK: - State transitions

    private func beginCandidate(at appKitPoint: CGPoint) {
        // Defensively clear any overlay left over from a session whose mouse-up
        // was missed, so panels can't get stuck on screen.
        if overlay.isShown { overlay.hide() }
        session = nil

        guard let window = resolveWindow(atAppKitPoint: appKitPoint) else { return }
        // Ignore our own windows (overlay/settings/onboarding).
        if window.pid == ProcessInfo.processInfo.processIdentifier { return }
        // If the window's position can't be read at all, there's no reliable
        // baseline to detect a real drag against — skip tracking this gesture
        // rather than defaulting to a fake `.zero` origin (which could
        // coincidentally look like a valid small movement later).
        guard let initialOrigin = window.position else { return }

        session = DragSession(
            window: window,
            initialMouse: appKitPoint,
            initialAXOrigin: initialOrigin
        )
    }

    private func updateDrag(at appKitPoint: CGPoint) {
        guard var current = session, !current.ignored else { return }

        if !current.isDragging {
            let moved = hypot(appKitPoint.x - current.initialMouse.x, appKitPoint.y - current.initialMouse.y)
            guard moved > dragThreshold else { return }

            // Confirm the window itself moved — otherwise this is likely a text
            // selection or resize starting on the same element. A nil AX read
            // counts against the retry budget the same as "hasn't moved yet"
            // rather than falling through to confirm — a single transient AX
            // hiccup must not bypass this check entirely. Retrying across a few
            // events also covers apps whose AX position lags the OS drag start.
            guard let origin = current.window.position else {
                current.confirmAttempts += 1
                if current.confirmAttempts >= maxConfirmAttempts { current.ignored = true }
                session = current
                return
            }
            let windowMoved = hypot(origin.x - current.initialAXOrigin.x, origin.y - current.initialAXOrigin.y)
            if windowMoved < 1 {
                current.confirmAttempts += 1
                if current.confirmAttempts >= maxConfirmAttempts { current.ignored = true }
                session = current
                return
            }
            current.isDragging = true
            session = current
        }

        reevaluateOverlay(at: appKitPoint)
    }

    private func endDrag(at appKitPoint: CGPoint) {
        defer {
            overlay.hide()
            session = nil
        }
        guard let current = session, current.isDragging, current.overlayShown,
              !current.currentSelection.isEmpty,
              let uuid = current.currentScreenUUID,
              let screen = current.screens.first(where: { $0.uuid == uuid }),
              let layout = overlay.shownLayouts[uuid] else {
            return
        }
        engine.tile(current.window, selection: current.currentSelection, screen: screen, layout: layout)
    }

    // MARK: - Overlay management

    private func reevaluateOverlay(at appKitPoint: CGPoint) {
        guard session?.isDragging == true else {
            if overlay.isShown { overlay.hide(); session?.overlayShown = false }
            return
        }

        let activationHeld = currentFlags.contains(settings.activationModifier.flag)

        if activationHeld {
            if session?.overlayShown != true {
                // Snapshot the screen arrangement once for the whole overlay
                // session so per-mouse-move hit-testing doesn't re-enumerate
                // displays.
                let screens = screenService.screens
                overlay.show(screens: screens, gaps: settings.gaps) { [layoutStore] screen in
                    layoutStore.layout(forScreen: screen.uuid)
                }
                session?.overlayShown = true
                session?.screens = screens
            }
            // Always refresh the highlight while shown — not just on the
            // shown-transition — so toggling the span modifier while the cursor
            // is stationary (no new mouseDragged event) still updates the
            // selection instead of leaving a stale highlight.
            updateHighlight(at: appKitPoint)
        } else if session?.overlayShown == true {
            overlay.hide()
            session?.overlayShown = false
            session?.currentSelection = []
            session?.spanAnchor = nil
            session?.currentScreenUUID = nil
        }
    }

    private func updateHighlight(at appKitPoint: CGPoint) {
        guard session?.overlayShown == true, let screens = session?.screens else { return }
        // Inclusive bounds: `CGRect.contains` is half-open on the max edges, so
        // a cursor sitting exactly on a display's top/right pixel would
        // otherwise match no screen and clear the highlight at the physical
        // screen edge — the same class of edge-inclusivity issue ZoneHitTesting
        // already accounts for at the tile level.
        guard let screen = screens.first(where: { $0.appKitVisibleFrame.containsInclusive(appKitPoint) }),
              let layout = overlay.shownLayouts[screen.uuid] else {
            overlay.clearHighlights()
            session?.currentSelection = []
            return
        }

        // Crossing screens resets the span anchor (spans don't cross monitors).
        if session?.currentScreenUUID != screen.uuid {
            session?.spanAnchor = nil
        }

        // Hit-test in AX space: flip the AppKit cursor and use the screen's AX
        // frame so the highlighted zone matches both the drawn overlay and the
        // eventual drop position.
        let axPoint = CoordinateConversion.flipY(appKitPoint, primaryScreenHeight: screenService.primaryHeight)
        let hovered = ZoneHitTesting.tileIndex(at: axPoint, layout: layout, screenRect: screen.axVisibleFrame)
        let selection = computeSelection(hovered: hovered, layout: layout)

        session?.currentSelection = selection
        session?.currentScreenUUID = screen.uuid
        overlay.highlight(screenUUID: screen.uuid, tiles: selection)
    }

    private func computeSelection(hovered: Int?, layout: Layout) -> Set<Int> {
        guard let hovered else {
            session?.spanAnchor = nil
            return []
        }
        // If activation and span are bound to the same key, testing the span
        // flag would trivially always be true for as long as the overlay is
        // visible (they're the same bit), making single-tile selection
        // impossible. Settings prevents picking the same key for both, but
        // guard here too in case that invariant is ever violated.
        let spanHeld = settings.spanModifier != settings.activationModifier
            && currentFlags.contains(settings.spanModifier.flag)
        guard spanHeld else {
            session?.spanAnchor = nil
            return [hovered]
        }
        if session?.spanAnchor == nil { session?.spanAnchor = hovered }
        let anchor = session?.spanAnchor ?? hovered
        return ZoneHitTesting.spanSelection(anchor: anchor, hovered: hovered, layout: layout)
    }

    // MARK: - Helpers

    /// Resolves the window under a cursor point. AX hit-testing expects a point
    /// in AX (top-left) coordinates, so the AppKit cursor is flipped first.
    private func resolveWindow(atAppKitPoint appKitPoint: CGPoint) -> AccessibilityElement? {
        let axPoint = CoordinateConversion.flipY(appKitPoint, primaryScreenHeight: screenService.primaryHeight)
        return AccessibilityElement.systemWide.windowElement(at: axPoint)
    }
}

/// The session state for one in-progress drag.
private struct DragSession {
    let window: AccessibilityElement
    let initialMouse: CGPoint
    let initialAXOrigin: CGPoint
    var isDragging = false
    var ignored = false
    var confirmAttempts = 0
    var overlayShown = false
    var spanAnchor: Int?
    var currentScreenUUID: String?
    var currentSelection: Set<Int> = []
    /// Screen arrangement snapshot captured when the overlay is shown.
    var screens: [ScreenInfo] = []
}
