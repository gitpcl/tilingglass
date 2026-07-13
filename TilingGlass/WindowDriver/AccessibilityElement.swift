// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ApplicationServices

/// A thin, value-typed wrapper over `AXUIElement`. Provides typed access to the
/// window attributes TilingGlass needs (position, size, role) and the helpers
/// for locating a window under the cursor or the focused window.
///
/// All coordinates are in Accessibility/CG global space (top-left origin).
/// Everything here runs on the main actor; `AXUIElement` is never sent across
/// actor boundaries.
@MainActor
struct AccessibilityElement {
    let raw: AXUIElement

    init(_ raw: AXUIElement) { self.raw = raw }

    static var systemWide: AccessibilityElement {
        let element = AccessibilityElement(AXUIElementCreateSystemWide())
        // Hit-testing under the cursor must stay snappy during a drag.
        element.setMessagingTimeout(0.5)
        return element
    }

    static func application(pid: pid_t) -> AccessibilityElement {
        let element = AccessibilityElement(AXUIElementCreateApplication(pid))
        // Bound how long a call to an app can block us — an unresponsive app
        // must not freeze window moves. Applies to all messages to this element.
        element.setMessagingTimeout(1.0)
        return element
    }

    /// Sets the per-element messaging timeout (seconds) so calls to a hung app
    /// return an error instead of blocking indefinitely.
    func setMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(raw, seconds)
    }

    // MARK: - Permission

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts for Accessibility access, opening System Settings if needed.
    @discardableResult
    static func requestTrust() -> Bool {
        // Value of `kAXTrustedCheckOptionPrompt`, inlined because the global is
        // flagged as non-concurrency-safe under strict concurrency checking.
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    // MARK: - Focused / hit-test lookup

    /// The frontmost application's focused window, if any.
    static func focusedWindow() -> AccessibilityElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = application(pid: app.processIdentifier)
        return appElement.child(forAttribute: kAXFocusedWindowAttribute as String)
    }

    /// The window under a screen point (top-left/AX coordinates), ascending from
    /// whatever element is hit to its enclosing window.
    func windowElement(at point: CGPoint) -> AccessibilityElement? {
        var hit: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(raw, Float(point.x), Float(point.y), &hit)
        guard result == .success, let hit else { return nil }
        return AccessibilityElement(hit).ascendToWindow()
    }

    /// Walks up the AX tree until it reaches an `AXWindow`, trying the direct
    /// `kAXWindowAttribute` shortcut first.
    func ascendToWindow() -> AccessibilityElement? {
        if role == kAXWindowRole as String { return self }
        if let window = child(forAttribute: kAXWindowAttribute as String) { return window }

        var current: AccessibilityElement? = self
        var depth = 0
        while let element = current, depth < 12 {
            if element.role == kAXWindowRole as String { return element }
            current = element.child(forAttribute: kAXParentAttribute as String)
            depth += 1
        }
        return nil
    }

    // MARK: - Attributes

    var role: String? { stringAttribute(kAXRoleAttribute as String) }
    var title: String? { stringAttribute(kAXTitleAttribute as String) }
    var subrole: String? { stringAttribute(kAXSubroleAttribute as String) }

    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(raw, &pid) == .success ? pid : nil
    }

    /// Window position in AX global coordinates (top-left origin).
    var position: CGPoint? {
        guard let value = axValue(kAXPositionAttribute as String) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    var size: CGSize? {
        guard let value = axValue(kAXSizeAttribute as String) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    /// Full window frame in AX global coordinates.
    var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size)
    }

    var isPositionSettable: Bool { isSettable(kAXPositionAttribute as String) }
    var isSizeSettable: Bool { isSettable(kAXSizeAttribute as String) }

    @discardableResult
    func setPosition(_ point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(raw, kAXPositionAttribute as CFString, value) == .success
    }

    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(raw, kAXSizeAttribute as CFString, value) == .success
    }

    // MARK: - Enhanced UI (set on the application element)

    /// Reads `AXEnhancedUserInterface`. When enabled (e.g. by Chromium/Electron
    /// apps and VoiceOver), setting window position is ignored, so ``WindowMover``
    /// clears it around a move.
    var isEnhancedUserInterfaceEnabled: Bool {
        boolAttribute("AXEnhancedUserInterface") ?? false
    }

    func setEnhancedUserInterface(_ enabled: Bool) {
        AXUIElementSetAttributeValue(
            raw, "AXEnhancedUserInterface" as CFString, enabled as CFBoolean
        )
    }

    /// The application element that owns this element (via its pid).
    func owningApplication() -> AccessibilityElement? {
        guard let pid else { return nil }
        return .application(pid: pid)
    }

    // MARK: - Primitive accessors

    private func rawValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private func stringAttribute(_ attribute: String) -> String? {
        rawValue(attribute) as? String
    }

    private func boolAttribute(_ attribute: String) -> Bool? {
        guard let value = rawValue(attribute) else { return nil }
        guard CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return (value as! CFBoolean) == kCFBooleanTrue
    }

    private func axValue(_ attribute: String) -> AXValue? {
        guard let value = rawValue(attribute), CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    private func child(forAttribute attribute: String) -> AccessibilityElement? {
        guard let value = rawValue(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return AccessibilityElement(value as! AXUIElement)
    }

    private func isSettable(_ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(raw, attribute as CFString, &settable)
        return result == .success && settable.boolValue
    }
}
