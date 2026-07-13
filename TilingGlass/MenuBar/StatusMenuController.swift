import AppKit
import TilingCore

/// Owns the menu-bar status item and its menu. The menu is rebuilt on demand so
/// it always reflects the current screens and layout selection.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let layoutStore: LayoutStore
    private let screenService: ScreenService

    /// Called when the user wants to open Settings.
    var onOpenSettings: (() -> Void)?
    /// Called with a debug action identifier (temporary, for phase validation).
    var onDebugAction: ((DebugAction) -> Void)?

    enum DebugAction {
        case moveFocusedLeftHalf
        case toggleOverlayPreview
    }

    init(layoutStore: LayoutStore, screenService: ScreenService) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.layoutStore = layoutStore
        self.screenService = screenService
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.2x2",
                accessibilityDescription: "TilingGlass"
            )
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for screen in screenService.screens {
            addLayoutSection(to: menu, for: screen)
        }

        menu.addItem(.separator())
        addDebugItems(to: menu)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit TilingGlass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Sections

    private func addLayoutSection(to menu: NSMenu, for screen: ScreenInfo) {
        let selected = layoutStore.layout(forScreen: screen.uuid)

        if screenService.screens.count > 1 {
            let title = NSMenuItem(title: screen.localizedName, action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
        }

        for layout in layoutStore.layouts {
            let item = NSMenuItem(title: layout.id, action: #selector(selectLayout(_:)), keyEquivalent: "")
            item.target = self
            item.state = (layout.id == selected.id) ? .on : .off
            item.representedObject = LayoutSelection(screenUUID: screen.uuid, layoutID: layout.id)
            menu.addItem(item)
        }
    }

    private func addDebugItems(to menu: NSMenu) {
        let debugHeader = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugHeader.isEnabled = false
        menu.addItem(debugHeader)

        let moveLeft = NSMenuItem(title: "Move Focused Window → Left Half", action: #selector(debugMoveLeft), keyEquivalent: "")
        moveLeft.target = self
        menu.addItem(moveLeft)

        let overlay = NSMenuItem(title: "Toggle Overlay Preview", action: #selector(debugToggleOverlay), keyEquivalent: "")
        overlay.target = self
        menu.addItem(overlay)
    }

    // MARK: - Actions

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? LayoutSelection else { return }
        layoutStore.selectLayout(id: selection.layoutID, forScreen: selection.screenUUID)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func debugMoveLeft() {
        onDebugAction?(.moveFocusedLeftHalf)
    }

    @objc private func debugToggleOverlay() {
        onDebugAction?(.toggleOverlayPreview)
    }

    private struct LayoutSelection {
        let screenUUID: String
        let layoutID: String
    }
}
