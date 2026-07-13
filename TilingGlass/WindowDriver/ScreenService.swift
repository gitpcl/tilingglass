import AppKit
import TilingCore

/// A snapshot of one display: its stable identity and its usable area in both
/// coordinate spaces.
struct ScreenInfo: Identifiable, Sendable {
    /// CoreGraphics display id (not stable across reconnects; use `uuid` to persist).
    let id: CGDirectDisplayID
    /// Stable UUID string, suitable for persisting per-screen layout choices.
    let uuid: String
    let localizedName: String
    /// Usable area (excludes menu bar and Dock) in AppKit space (bottom-left origin).
    let appKitVisibleFrame: CGRect
    /// The same usable area in Accessibility/CG space (top-left origin).
    let axVisibleFrame: CGRect
}

/// Enumerates displays and bridges the two coordinate spaces. Enumeration is
/// pull-based (no polling) — callers ask for `screens` when they need a fresh
/// snapshot, e.g. when opening the menu or starting a drag.
@MainActor
final class ScreenService {
    /// The height of the primary display (the one at the AppKit origin), used as
    /// the reference for every Y-flip. See ``CoordinateConversion``.
    var primaryHeight: CGFloat {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero }
        return primary?.frame.height ?? NSScreen.main?.frame.height ?? 0
    }

    /// A fresh snapshot of all connected displays.
    var screens: [ScreenInfo] {
        let height = primaryHeight
        return NSScreen.screens.map { screen in
            let visible = screen.visibleFrame
            return ScreenInfo(
                id: Self.displayID(of: screen),
                uuid: Self.uuid(of: screen),
                localizedName: screen.localizedName,
                appKitVisibleFrame: visible,
                axVisibleFrame: CoordinateConversion.axRect(fromAppKit: visible, primaryScreenHeight: height)
            )
        }
    }

    /// The screen whose AppKit visible area contains `appKitPoint` (e.g. the
    /// cursor). Falls back to the full display frame (so points in the menu-bar
    /// strip still resolve), then to the primary screen.
    func screen(atAppKitPoint appKitPoint: CGPoint) -> ScreenInfo? {
        let all = screens
        if let hit = all.first(where: { $0.appKitVisibleFrame.contains(appKitPoint) }) {
            return hit
        }
        if let nsScreen = NSScreen.screens.first(where: { $0.frame.contains(appKitPoint) }) {
            let uuid = Self.uuid(of: nsScreen)
            if let match = all.first(where: { $0.uuid == uuid }) { return match }
        }
        return all.first
    }

    // MARK: - Identity helpers

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    private static func uuid(of screen: NSScreen) -> String {
        let displayID = displayID(of: screen)
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, cfUUID) as String? else {
            // Fall back to a frame-derived key so multi-monitor still works even
            // if the UUID lookup fails.
            return "screen-\(displayID)"
        }
        return string as String
    }
}
