import AppKit

/// A raw input event relevant to window dragging. Mouse locations are in AppKit
/// global coordinates (bottom-left origin).
enum DragInputEvent {
    case mouseDown(CGPoint)
    case mouseDragged(CGPoint)
    case mouseUp(CGPoint)
    case flagsChanged(NSEvent.ModifierFlags)
}

/// Observes global mouse and modifier events using passive `NSEvent` monitors.
///
/// Monitors are only installed while running (started once Accessibility access
/// is granted) and are purely push-based — there are no timers or polling, so
/// the app is idle between events. Global monitors observe events destined for
/// other apps, which is exactly what we need to watch the user drag another
/// app's window; they cannot consume events, only report them.
@MainActor
final class DragMonitor {
    private var monitors: [Any] = []

    /// Called for each observed event. Set before ``start()``.
    var onEvent: ((DragInputEvent) -> Void)?

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        addMouseMonitor(.leftMouseDown) { .mouseDown($0) }
        addMouseMonitor(.leftMouseDragged) { .mouseDragged($0) }
        addMouseMonitor(.leftMouseUp) { .mouseUp($0) }

        let flags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.onEvent?(.flagsChanged(event.modifierFlags))
            }
        }
        if let flags { monitors.append(flags) }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }

    private func addMouseMonitor(
        _ mask: NSEvent.EventTypeMask,
        _ makeEvent: @escaping (CGPoint) -> DragInputEvent
    ) {
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated {
                // NSEvent.mouseLocation is the current global cursor position,
                // accurate at handler time.
                self?.onEvent?(makeEvent(NSEvent.mouseLocation))
            }
        }
        if let monitor { monitors.append(monitor) }
    }
}
