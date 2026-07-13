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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; ensure accessory policy.
        NSApp.setActivationPolicy(.accessory)

        let menu = StatusMenuController(layoutStore: layoutStore, screenService: screenService)
        menu.onOpenSettings = { Self.openSettingsWindow() }
        menu.onDebugAction = { [weak self] action in self?.handleDebugAction(action) }
        statusMenu = menu

        onboarding.onGranted = { NSLog("[TilingGlass] Accessibility access granted") }
        onboarding.showIfNeeded()
    }

    // MARK: - Debug actions (temporary, replaced as phases land)

    private func handleDebugAction(_ action: StatusMenuController.DebugAction) {
        switch action {
        case .moveFocusedLeftHalf:
            moveFocusedToLeftHalf()
        case .toggleOverlayPreview:
            NSLog("[TilingGlass] toggleOverlayPreview not yet wired")
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
