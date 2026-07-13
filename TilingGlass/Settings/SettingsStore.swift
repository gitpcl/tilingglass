import AppKit
import Combine
import TilingCore

/// A modifier key the user can pick for activation or span selection.
enum ModifierChoice: String, CaseIterable, Identifiable, Sendable {
    case control, option, command, shift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .control: return "Control (⌃)"
        case .option: return "Option (⌥)"
        case .command: return "Command (⌘)"
        case .shift: return "Shift (⇧)"
        }
    }

    /// The `NSEvent.ModifierFlags` bit this choice corresponds to.
    var flag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .command: return .command
        case .shift: return .shift
        }
    }
}

/// User-facing settings, persisted in `UserDefaults` and observable by the UI
/// and the tiling engine. Writes go straight to defaults via `didSet`.
@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activationModifier = Self.readModifier(defaults, Keys.activationModifier) ?? .control
        self.spanModifier = Self.readModifier(defaults, Keys.spanModifier) ?? .option
        self.innerGap = defaults.object(forKey: Keys.innerGap) as? Double ?? 8
        self.outerGap = defaults.object(forKey: Keys.outerGap) as? Double ?? 8
        self.onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
    }

    // MARK: - Published settings

    @Published var activationModifier: ModifierChoice {
        didSet { defaults.set(activationModifier.rawValue, forKey: Keys.activationModifier) }
    }

    @Published var spanModifier: ModifierChoice {
        didSet { defaults.set(spanModifier.rawValue, forKey: Keys.spanModifier) }
    }

    @Published var innerGap: Double {
        didSet { defaults.set(innerGap, forKey: Keys.innerGap) }
    }

    @Published var outerGap: Double {
        didSet { defaults.set(outerGap, forKey: Keys.outerGap) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    // MARK: - Derived values

    var gaps: Gaps {
        Gaps(inner: CGFloat(innerGap), outer: CGFloat(outerGap))
    }

    // MARK: - Per-screen layout selection

    /// Returns the layout id selected for a screen (by stable UUID), if any.
    func selectedLayoutID(forScreen uuid: String) -> String? {
        selectedLayoutByScreen[uuid]
    }

    func setSelectedLayoutID(_ id: String, forScreen uuid: String) {
        var map = selectedLayoutByScreen
        map[uuid] = id
        selectedLayoutByScreen = map
    }

    private var selectedLayoutByScreen: [String: String] {
        get { defaults.dictionary(forKey: Keys.selectedLayoutByScreen) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Keys.selectedLayoutByScreen) }
    }

    /// Persisted custom layouts (Tiling Shell JSON). Nil when the user has none.
    var customLayoutsJSON: Data? {
        get { defaults.data(forKey: Keys.customLayoutsJSON) }
        set { defaults.set(newValue, forKey: Keys.customLayoutsJSON) }
    }

    // MARK: - Helpers

    private static func readModifier(_ defaults: UserDefaults, _ key: String) -> ModifierChoice? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return ModifierChoice(rawValue: raw)
    }

    private enum Keys {
        static let activationModifier = "activationModifier"
        static let spanModifier = "spanModifier"
        static let innerGap = "innerGap"
        static let outerGap = "outerGap"
        static let selectedLayoutByScreen = "selectedLayoutByScreen"
        static let customLayoutsJSON = "customLayoutsJSON"
        static let onboardingCompleted = "onboardingCompleted"
    }
}
