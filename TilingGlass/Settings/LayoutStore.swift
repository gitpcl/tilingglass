// SPDX-License-Identifier: GPL-3.0-only

import Combine
import Foundation
import TilingCore

/// The catalogue of available layouts (built-ins plus user imports) and the
/// per-screen selection. Persists custom layouts through ``SettingsStore`` in
/// Tiling Shell JSON format.
@MainActor
final class LayoutStore: ObservableObject {
    private let settings: SettingsStore

    /// All layouts in display order: built-ins first, then custom imports.
    /// A custom layout whose id matches a built-in replaces it.
    @Published private(set) var layouts: [Layout]

    init(settings: SettingsStore) {
        self.settings = settings
        self.customLayouts = Self.loadCustom(from: settings)
        self.layouts = Self.merge(custom: customLayouts)
    }

    private var customLayouts: [Layout] {
        didSet { layouts = Self.merge(custom: customLayouts) }
    }

    // MARK: - Lookup

    func layout(withID id: String) -> Layout? {
        layouts.first { $0.id == id }
    }

    /// The layout that should be applied to a screen: its explicit selection if
    /// still valid, otherwise the global default (first built-in).
    func layout(forScreen uuid: String) -> Layout {
        if let id = settings.selectedLayoutID(forScreen: uuid), let match = layout(withID: id) {
            return match
        }
        return layout(withID: BuiltinLayouts.defaultID) ?? layouts[0]
    }

    func selectLayout(id: String, forScreen uuid: String) {
        settings.setSelectedLayoutID(id, forScreen: uuid)
        objectWillChange.send()
    }

    // MARK: - Editing

    /// True when `id` names one of the built-in layouts (which can be
    /// overridden by a custom layout of the same id, but never deleted).
    func isBuiltin(id: String) -> Bool {
        BuiltinLayouts.all.contains { $0.id == id }
    }

    /// True when a custom layout with this id exists (including one that
    /// overrides a builtin).
    func hasCustomLayout(id: String) -> Bool {
        customLayouts.contains { $0.id == id }
    }

    /// Inserts or replaces (by id) a custom layout and persists the set.
    /// The layout should already have its `groups` recomputed and validate.
    func saveCustomLayout(_ layout: Layout) {
        var merged = customLayouts
        if let index = merged.firstIndex(where: { $0.id == layout.id }) {
            merged[index] = layout
        } else {
            merged.append(layout)
        }
        customLayouts = merged
        persist()
    }

    /// Deletes a custom layout by id. Builtins can't be deleted — deleting a
    /// custom layout that overrode a builtin makes the builtin reappear.
    func deleteCustomLayout(id: String) {
        customLayouts.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Import / export

    /// Imports layouts from Tiling Shell JSON, adding them to the custom set.
    /// Imported ids replace any existing custom layout with the same id.
    func importLayouts(from data: Data) throws {
        let imported = try LayoutCodec.decode(data)
        var merged = customLayouts
        for layout in imported {
            if let index = merged.firstIndex(where: { $0.id == layout.id }) {
                merged[index] = layout
            } else {
                merged.append(layout)
            }
        }
        customLayouts = merged
        persist()
    }

    /// Exports every layout (built-ins + custom) as Tiling Shell JSON.
    func exportAllLayouts() throws -> Data {
        try LayoutCodec.encode(layouts)
    }

    // MARK: - Persistence

    private func persist() {
        settings.customLayoutsJSON = try? LayoutCodec.encode(customLayouts)
    }

    private static func loadCustom(from settings: SettingsStore) -> [Layout] {
        guard let data = settings.customLayoutsJSON,
              let decoded = try? LayoutCodec.decode(data) else {
            return []
        }
        return decoded
    }

    private static func merge(custom: [Layout]) -> [Layout] {
        var result = BuiltinLayouts.all
        for layout in custom {
            if let index = result.firstIndex(where: { $0.id == layout.id }) {
                result[index] = layout
            } else {
                result.append(layout)
            }
        }
        return result
    }
}
