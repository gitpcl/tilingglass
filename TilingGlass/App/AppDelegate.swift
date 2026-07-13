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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; ensure accessory policy.
        NSApp.setActivationPolicy(.accessory)

        let menu = StatusMenuController(layoutStore: layoutStore, screenService: screenService)
        menu.onOpenSettings = { Self.openSettingsWindow() }
        menu.onDebugAction = { [weak self] action in self?.handleDebugAction(action) }
        statusMenu = menu

        dragMonitor.onEvent = { [weak self] event in self?.dragCoordinator.handle(event) }
        startMonitoringIfTrusted()

        onboarding.onGranted = { [weak self] in
            NSLog("[TilingGlass] Accessibility access granted")
            self?.startMonitoringIfTrusted()
        }
        onboarding.showIfNeeded()

        // Smoke-test hook: TILINGGLASS_DEBUG_OVERLAY=1 shows the glass overlay on
        // launch so it can be verified without clicking the menu.
        if ProcessInfo.processInfo.environment["TILINGGLASS_DEBUG_OVERLAY"] == "1" {
            toggleOverlayPreview()
            NSLog("[TilingGlass] debug overlay shown: \(overlay.isShown)")
        }
    }

    /// Starts observing drags once Accessibility access is available. Global
    /// event monitors require that access, so this is gated and re-invoked after
    /// the user grants it.
    private func startMonitoringIfTrusted() {
        guard AccessibilityElement.isTrusted, !dragMonitor.isRunning else { return }
        dragMonitor.start()
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

    // MARK: - Settings window

    private static func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // The standard Settings scene selector differs across SDKs; try both.
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
