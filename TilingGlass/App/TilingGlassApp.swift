import SwiftUI

/// Menu-bar-only agent app. All lifecycle and UI wiring lives in
/// ``AppDelegate``; SwiftUI only owns the Settings scene.
@main
struct TilingGlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.layoutStore)
        }
    }
}
