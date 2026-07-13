import KeyboardShortcuts
import SwiftUI
import TilingCore

/// The Settings window: activation modifiers, gaps, keyboard shortcuts, and
/// launch-at-login.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var layoutStore: LayoutStore

    var body: some View {
        Form {
            Section("Activation") {
                Picker("Show zones while dragging with", selection: $settings.activationModifier) {
                    ForEach(ModifierChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Picker("Span multiple zones with", selection: $settings.spanModifier) {
                    ForEach(ModifierChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Text("Tip: start dragging a window first, then hold the activation key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Gaps") {
                Stepper(value: $settings.innerGap, in: 0...48, step: 1) {
                    Text("Inner gap: \(Int(settings.innerGap)) pt")
                }
                Stepper(value: $settings.outerGap, in: 0...48, step: 1) {
                    Text("Outer gap: \(Int(settings.outerGap)) pt")
                }
            }

            Section("Keyboard") {
                KeyboardShortcuts.Recorder("Move window left", name: .moveTileLeft)
                KeyboardShortcuts.Recorder("Move window right", name: .moveTileRight)
                KeyboardShortcuts.Recorder("Move window up", name: .moveTileUp)
                KeyboardShortcuts.Recorder("Move window down", name: .moveTileDown)
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
    }
}
