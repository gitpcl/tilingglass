import AppKit
import SwiftUI

/// Composition root. Constructs the object graph and wires the menu bar to the
/// rest of the app. Components are added phase by phase; Phase 1 wires the menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    private(set) lazy var layoutStore = LayoutStore(settings: settings)
    let screenService = ScreenService()

    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; ensure accessory policy.
        NSApp.setActivationPolicy(.accessory)

        let menu = StatusMenuController(layoutStore: layoutStore, screenService: screenService)
        menu.onOpenSettings = { Self.openSettingsWindow() }
        menu.onDebugAction = { [weak self] action in self?.handleDebugAction(action) }
        statusMenu = menu
    }

    // MARK: - Debug actions (temporary, replaced as phases land)

    private func handleDebugAction(_ action: StatusMenuController.DebugAction) {
        switch action {
        case .moveFocusedLeftHalf:
            NSLog("[TilingGlass] moveFocusedLeftHalf not yet wired")
        case .toggleOverlayPreview:
            NSLog("[TilingGlass] toggleOverlayPreview not yet wired")
        }
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
