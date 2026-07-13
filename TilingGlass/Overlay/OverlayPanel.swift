import AppKit
import SwiftUI

/// A borderless, click-through overlay window covering one screen's usable area.
/// It floats above normal windows, joins all Spaces, and never steals focus, so
/// it can be shown while the user drags another app's window.
final class OverlayPanel: NSPanel {
    init(frame: CGRect, state: OverlayState) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: ZoneOverlayView(state: state))
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    // Never take key/main so the underlying dragged window keeps focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
