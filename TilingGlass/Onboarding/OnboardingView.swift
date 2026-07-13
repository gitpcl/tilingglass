// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

/// First-run onboarding content. Kept dependency-free so it can be hosted in a
/// plain `NSWindow`.
struct OnboardingView: View {
    let requestAccess: () -> Void
    let openTilingSettings: () -> Void
    let finish: () -> Void

    @State private var trusted = AccessibilityElement.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Welcome to TilingGlass").font(.title2).bold()
                    Text("Snap windows into custom zones.").foregroundStyle(.secondary)
                }
            }

            step(
                number: 1,
                title: "Grant Accessibility access",
                detail: "TilingGlass moves and resizes windows through macOS Accessibility. Enable TilingGlass in System Settings › Privacy & Security › Accessibility.",
                actionLabel: trusted ? "Granted" : "Open Accessibility Settings",
                actionDisabled: trusted,
                action: requestAccess
            )

            step(
                number: 2,
                title: "Turn off native edge tiling (recommended)",
                detail: "macOS's own drag-to-edge tiling can conflict with TilingGlass. Turn off “Drag windows to screen edges to tile” in Desktop & Dock.",
                actionLabel: "Open Desktop & Dock",
                actionDisabled: false,
                action: openTilingSettings
            )

            HStack {
                if trusted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Waiting for access…", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!trusted)
            }
        }
        .padding(28)
        .frame(width: 460)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = AccessibilityElement.isTrusted
        }
    }

    private func step(
        number: Int, title: String, detail: String,
        actionLabel: String, actionDisabled: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.tint.opacity(0.15)))
                .overlay(Circle().stroke(.tint.opacity(0.4)))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(actionLabel, action: action).disabled(actionDisabled)
            }
        }
    }
}
