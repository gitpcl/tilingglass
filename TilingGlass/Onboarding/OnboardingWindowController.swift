import AppKit
import SwiftUI

/// Presents the first-run onboarding: requests Accessibility access and offers
/// to disable macOS's native edge tiling so it doesn't fight TilingGlass.
///
/// While the window is open it polls `AXIsProcessTrusted()` once a second — this
/// is the *only* timer in the app and it stops the moment access is granted or
/// the window closes, so the idle app never polls.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var pollTimer: Timer?

    /// Called once Accessibility access becomes available.
    var onGranted: (() -> Void)?

    /// Shows onboarding only if access hasn't been granted yet.
    func showIfNeeded() {
        if AccessibilityElement.isTrusted { return }
        present()
    }

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(
            requestAccess: { AccessibilityElement.requestTrust() },
            openTilingSettings: { Self.openDesktopAndDockSettings() },
            finish: { [weak self] in self?.close() }
        )

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to TilingGlass"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if AccessibilityElement.isTrusted {
                    self.stopPolling()
                    self.onGranted?()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func close() {
        stopPolling()
        window?.close()
    }

    private static func openDesktopAndDockSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
