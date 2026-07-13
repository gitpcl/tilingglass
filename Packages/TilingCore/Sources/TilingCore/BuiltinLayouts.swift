// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// The layouts shipped with TilingGlass. These mirror common Tiling Shell
/// defaults and are always available even before the user imports anything.
public enum BuiltinLayouts {
    /// Two equal columns (left/right halves). Id matches the Tiling Shell doc example.
    public static let equalSplit = Layout(id: "Equal split", tiles: [
        Tile(x: 0, y: 0, width: 0.5, height: 1, groups: [1]),
        Tile(x: 0.5, y: 0, width: 0.5, height: 1, groups: [1]),
    ])

    /// Three equal columns.
    public static let thirds = Layout(id: "Thirds", tiles: [
        Tile(x: 0, y: 0, width: 1.0 / 3.0, height: 1, groups: [1]),
        Tile(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1, groups: [1, 2]),
        Tile(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1, groups: [2]),
    ])

    /// A 2x2 grid of equal quadrants.
    public static let grid2x2 = Layout(id: "2x2 Grid", tiles: [
        Tile(x: 0, y: 0, width: 0.5, height: 0.5, groups: [1, 3]),
        Tile(x: 0.5, y: 0, width: 0.5, height: 0.5, groups: [1, 4]),
        Tile(x: 0, y: 0.5, width: 0.5, height: 0.5, groups: [2, 3]),
        Tile(x: 0.5, y: 0.5, width: 0.5, height: 0.5, groups: [2, 4]),
    ])

    /// A wide central column flanked by two narrower side columns — good for a
    /// focused primary window with references on either side.
    public static let focus = Layout(id: "Focus", tiles: [
        Tile(x: 0, y: 0, width: 0.25, height: 1, groups: [1]),
        Tile(x: 0.25, y: 0, width: 0.5, height: 1, groups: [1, 2]),
        Tile(x: 0.75, y: 0, width: 0.25, height: 1, groups: [2]),
    ])

    /// All built-in layouts in display order.
    public static let all: [Layout] = [equalSplit, thirds, grid2x2, focus]

    /// The default layout id used when a screen has no explicit selection.
    public static let defaultID = equalSplit.id
}
