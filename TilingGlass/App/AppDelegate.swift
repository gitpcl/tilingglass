// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI
import TilingCore

/// Composition root. Constructs the object graph and wires the menu bar to the
/// rest of the app. Components are added phase by phase.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    private(set) lazy var layoutStore = LayoutStore(settings: settings)
    let screenService = ScreenService()

    private var statusMenu: StatusMenuController?
    private let onboarding = OnboardingWindowController()
    private let overlay = OverlayController()
    private lazy var engine = TilingEngine(screenService: screenService, settings: settings, layoutStore: layoutStore)
    private lazy var dragCoordinator = DragCoordinator(
        settings: settings, screenService: screenService,
        overlay: overlay, engine: engine, layoutStore: layoutStore
    )
    private let dragMonitor = DragMonitor()
    private lazy var hotkeys = HotkeyManager(engine: engine)
    private lazy var layoutEditor = LayoutEditorWindowController(layoutStore: layoutStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; ensure accessory policy.
        NSApp.setActivationPolicy(.accessory)

        let menu = StatusMenuController(layoutStore: layoutStore, screenService: screenService)
        menu.onDebugAction = { [weak self] action in self?.handleDebugAction(action) }
        menu.onNewLayout = { [weak self] in
            // A new layout starts from a single full-screen zone with no name.
            // (TilingCore.Layout spelled out: SwiftUI also exports `Layout`.)
            self?.layoutEditor.present(editing: TilingCore.Layout(id: "", tiles: [
                Tile(x: 0, y: 0, width: 1, height: 1),
            ]))
        }
        menu.onEditLayout = { [weak self] id in
            guard let self, let layout = self.layoutStore.layout(withID: id) else { return }
            self.layoutEditor.present(editing: layout)
        }
        statusMenu = menu

        dragMonitor.onEvent = { [weak self] event in self?.dragCoordinator.handle(event) }
        hotkeys.register()
        startMonitoringIfTrusted()

        onboarding.onGranted = { [weak self] in
            NSLog("[TilingGlass] Accessibility access granted")
            self?.startMonitoringIfTrusted()
        }
        onboarding.showIfNeeded()

        // Displays changing (resolution, arrangement, connect/disconnect) can
        // invalidate overlay panel frames — tear them down so the next drag
        // rebuilds against the current arrangement.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dragCoordinator.handleDisplaysChanged() }
        }

        // Smoke-test hook: TILINGGLASS_DEBUG_OVERLAY=1 shows the glass overlay on
        // launch so it can be verified without clicking the menu.
        if ProcessInfo.processInfo.environment["TILINGGLASS_DEBUG_OVERLAY"] == "1" {
            toggleOverlayPreview()
            NSLog("[TilingGlass] debug overlay shown: \(overlay.isShown)")
        }

        // Smoke-test hook: TILINGGLASS_DEBUG_EDITOR=1 opens the layout editor on
        // launch, proving the window and canvas construct without a menu click.
        if ProcessInfo.processInfo.environment["TILINGGLASS_DEBUG_EDITOR"] == "1" {
            layoutEditor.present(editing: BuiltinLayouts.grid2x2)
            NSLog("[TilingGlass] debug editor opened")
        }
    }

    /// Starts observing drags once Accessibility access is available. Global
    /// event monitors require that access, so this is gated and re-invoked after
    /// the user grants it.
    private func startMonitoringIfTrusted() {
        guard AccessibilityElement.isTrusted, !dragMonitor.isRunning else { return }
        dragMonitor.start()
        // `flagsChanged` only fires on transitions — if the activation modifier
        // is already held when monitoring starts (resting on it at launch, or
        // restarting monitoring right after granting AX access mid-gesture),
        // there's no prior "release" to produce a future "press," so the
        // overlay would never appear until the key is released and re-pressed.
        // Seed the tracked state from reality so that case still works.
        dragCoordinator.seedModifierFlags(NSEvent.modifierFlags)
        NSLog("[TilingGlass] drag monitoring started")
    }

    // MARK: - Debug actions (temporary, replaced as phases land)

    private func handleDebugAction(_ action: StatusMenuController.DebugAction) {
        switch action {
        case .moveFocusedLeftHalf:
            moveFocusedToLeftHalf()
        case .toggleOverlayPreview:
            toggleOverlayPreview()
        }
    }

    /// Phase 4 validation: shows/hides the glass zone overlay on every screen
    /// with the current per-screen layout, highlighting the first zone so the
    /// glass rendering is visible.
    private func toggleOverlayPreview() {
        if overlay.isShown {
            overlay.hide()
            return
        }
        let screens = screenService.screens
        overlay.show(screens: screens, gaps: settings.gaps) { [layoutStore] screen in
            layoutStore.layout(forScreen: screen.uuid)
        }
        // Highlight one zone so both the plain and accent-tinted glass are visible.
        if let first = screens.first {
            overlay.highlight(screenUUID: first.uuid, tiles: [0])
        }
    }

    /// Phase 2 validation: exercises the full pipeline — focused window lookup,
    /// screen resolution, zone geometry, coordinate flip, and the AX move.
    private func moveFocusedToLeftHalf() {
        guard AccessibilityElement.isTrusted else {
            onboarding.present()
            return
        }
        guard let window = AccessibilityElement.focusedWindow(), let frame = window.frame else {
            NSLog("[TilingGlass] no focused window")
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screens = screenService.screens
        guard let screen = screens.first(where: { $0.axVisibleFrame.contains(center) }) ?? screens.first else {
            return
        }
        let leftHalf = BuiltinLayouts.equalSplit.tiles[0]
        let target = ZoneGeometry.resolve(leftHalf, in: screen.axVisibleFrame, gaps: settings.gaps)
        let result = WindowMover.move(window, to: target)
        NSLog("[TilingGlass] moveFocusedToLeftHalf on \(screen.localizedName) → \(String(describing: result))")
    }
}
