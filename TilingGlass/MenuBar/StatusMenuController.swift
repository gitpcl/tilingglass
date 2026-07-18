// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI
import TilingCore
import UniformTypeIdentifiers

/// Owns the menu-bar status item and its menu. The menu is rebuilt on demand so
/// it always reflects the current screens and layout selection.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let layoutStore: LayoutStore
    private let screenService: ScreenService

    /// Called with a debug action identifier (temporary, for phase validation).
    var onDebugAction: ((DebugAction) -> Void)?
    /// Called when the user wants to create a new layout in the editor.
    var onNewLayout: (() -> Void)?
    /// Called when the user wants to edit an existing layout (by id).
    var onEditLayout: ((String) -> Void)?

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
        addLayoutFileItems(to: menu)

        #if DEBUG
        menu.addItem(.separator())
        addDebugItems(to: menu)
        #endif

        menu.addItem(.separator())
        addSettingsItem(to: menu)

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
            item.image = Self.thumbnail(for: layout)
            item.representedObject = LayoutSelection(screenUUID: screen.uuid, layoutID: layout.id)
            menu.addItem(item)
        }
    }

    private func addLayoutFileItems(to menu: NSMenu) {
        let newItem = NSMenuItem(title: "New Layout…", action: #selector(newLayout), keyEquivalent: "")
        newItem.target = self
        menu.addItem(newItem)

        let editItem = NSMenuItem(title: "Edit Layout", action: nil, keyEquivalent: "")
        let editSubmenu = NSMenu()
        for layout in layoutStore.layouts {
            let item = NSMenuItem(title: layout.id, action: #selector(editLayout(_:)), keyEquivalent: "")
            item.target = self
            item.image = Self.thumbnail(for: layout)
            item.representedObject = layout.id
            editSubmenu.addItem(item)
        }
        editItem.submenu = editSubmenu
        menu.addItem(editItem)

        menu.addItem(.separator())

        let importItem = NSMenuItem(title: "Import Layouts…", action: #selector(importLayouts), keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)

        let exportItem = NSMenuItem(title: "Export Layouts…", action: #selector(exportLayouts), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)
    }

    /// Hosts a `SettingsLink` as the menu item's view, rather than an
    /// `NSMenuItem` action that opens Settings via
    /// `Selector(("showSettingsWindow:"))`. That selector resolves through the
    /// key-window responder chain, which an accessory (menu-bar-only) app
    /// typically doesn't have — `SettingsLink` uses SwiftUI's own Settings-scene
    /// action instead, which doesn't depend on responder-chain lookup.
    private func addSettingsItem(to menu: NSMenu) {
        let item = NSMenuItem()
        let hosting = NSHostingView(rootView: SettingsMenuItemView())
        hosting.frame = NSRect(x: 0, y: 0, width: 220, height: 22)
        item.view = hosting
        menu.addItem(item)
    }

    #if DEBUG
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
    #endif

    /// A small monochrome wireframe of a layout's zones, shown beside its name so
    /// layouts read as geometry rather than just text. Template-rendered, so it
    /// adopts the menu's label color and highlight state automatically.
    private static func thumbnail(for layout: TilingCore.Layout) -> NSImage {
        let size = NSSize(width: 30, height: 19)
        let inset: CGFloat = 0.75
        let image = NSImage(size: size, flipped: false) { bounds in
            for tile in layout.tiles {
                let rect = NSRect(
                    x: CGFloat(tile.x) * bounds.width + inset,
                    // Tile coordinates are top-left; NSImage draws bottom-left.
                    y: CGFloat(1 - tile.y - tile.height) * bounds.height + inset,
                    width: CGFloat(tile.width) * bounds.width - inset * 2,
                    height: CGFloat(tile.height) * bounds.height - inset * 2
                )
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Actions

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? LayoutSelection else { return }
        layoutStore.selectLayout(id: selection.layoutID, forScreen: selection.screenUUID)
    }

    @objc private func newLayout() {
        onNewLayout?()
    }

    @objc private func editLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onEditLayout?(id)
    }

    @objc private func importLayouts() {
        let panel = NSOpenPanel()
        panel.title = "Import Layouts"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try layoutStore.importLayouts(from: data)
        } catch {
            presentError("Could not import layouts", error)
        }
    }

    @objc private func exportLayouts() {
        let panel = NSSavePanel()
        panel.title = "Export Layouts"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "TilingGlass Layouts.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try layoutStore.exportAllLayouts()
            try data.write(to: url)
        } catch {
            presentError("Could not export layouts", error)
        }
    }

    private func presentError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = String(describing: error)
        alert.alertStyle = .warning
        alert.runModal()
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

/// A `NSMenuItem.view` row that opens the app's Settings scene. `SettingsLink`
/// is the SwiftUI-native, responder-chain-independent way to do this — see
/// ``StatusMenuController/addSettingsItem(to:)``.
private struct SettingsMenuItemView: View {
    var body: some View {
        SettingsLink {
            Text("Settings…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }
}
