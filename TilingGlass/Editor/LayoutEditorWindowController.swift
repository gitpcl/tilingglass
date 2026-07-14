// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI
import TilingCore

/// Presents the layout editor in its own window. A fresh editor view (and
/// therefore fresh editing state) is installed on every `present`, so an
/// abandoned session never leaks stale edits into the next one.
@MainActor
final class LayoutEditorWindowController {
    private let layoutStore: LayoutStore
    private var window: NSWindow?

    init(layoutStore: LayoutStore) {
        self.layoutStore = layoutStore
    }

    /// Opens the editor seeded from `layout`. Pass a copy with an empty id to
    /// start a new layout (the canvas starts from the given tiles either way).
    /// (`TilingCore.Layout` is spelled out because SwiftUI also exports a
    /// `Layout` protocol and this file imports both.)
    func present(editing layout: TilingCore.Layout) {
        let editor = LayoutEditorView(layoutStore: layoutStore, editing: layout) { [weak self] in
            self?.close()
        }
        let hosting = NSHostingController(rootView: editor)

        if let window {
            window.contentViewController = hosting
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(contentViewController: hosting)
            window.title = "Layout Editor"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() {
        window?.close()
    }
}
