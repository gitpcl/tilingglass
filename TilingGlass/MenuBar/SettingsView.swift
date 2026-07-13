import SwiftUI
import TilingCore

/// The Settings window. Phase 1 shows gaps and modifier choices; keyboard
/// shortcut recorders and launch-at-login arrive in Phase 6.
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
            }

            Section("Gaps") {
                Stepper(value: $settings.innerGap, in: 0...48, step: 1) {
                    Text("Inner gap: \(Int(settings.innerGap)) pt")
                }
                Stepper(value: $settings.outerGap, in: 0...48, step: 1) {
                    Text("Outer gap: \(Int(settings.outerGap)) pt")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }
}
