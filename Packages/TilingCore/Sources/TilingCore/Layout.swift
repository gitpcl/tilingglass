// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// A single zone within a layout, expressed in normalized coordinates where the
/// full screen spans `0...1` on both axes with the origin at the top-left.
///
/// This mirrors the Tiling Shell layout schema exactly so layouts can be
/// imported/exported between the two apps. See
/// `doc/json-internal-documentation.md` in domferr/tilingshell.
public struct Tile: Codable, Equatable, Sendable {
    /// Distance from the left edge as a fraction of screen width (0...1).
    public var x: Double
    /// Distance from the top edge as a fraction of screen height (0...1).
    public var y: Double
    /// Width as a fraction of screen width (0...1].
    public var width: Double
    /// Height as a fraction of screen height (0...1].
    public var height: Double
    /// Numeric identifiers linking tiles for synchronized (shared-edge) resizing.
    /// Round-tripped verbatim; the v0.1 tiling engine does not interpret it.
    public var groups: [Int]

    public init(x: Double, y: Double, width: Double, height: Double, groups: [Int] = []) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.groups = groups
    }

    private enum CodingKeys: String, CodingKey {
        case x, y, width, height, groups
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        // Tiling Shell always writes `groups`, but tolerate its absence on
        // import so hand-authored layouts still load.
        groups = try container.decodeIfPresent([Int].self, forKey: .groups) ?? []
    }
}

extension Tile {
    /// The right edge as a fraction (x + width).
    public var maxX: Double { x + width }
    /// The bottom edge as a fraction (y + height).
    public var maxY: Double { y + height }

    /// The center point of the tile in normalized coordinates.
    public var center: (x: Double, y: Double) { (x + width / 2, y + height / 2) }
}

/// A named collection of tiles describing how a screen should be partitioned.
public struct Layout: Codable, Equatable, Identifiable, Sendable {
    /// Human-readable identifier, unique within a layout set. Doubles as the
    /// display name in the menu.
    public var id: String
    public var tiles: [Tile]

    public init(id: String, tiles: [Tile]) {
        self.id = id
        self.tiles = tiles
    }
}

// MARK: - Validation

public enum LayoutValidationError: Error, Equatable, CustomStringConvertible {
    case emptyID
    case noTiles
    case notFinite(tileIndex: Int, field: String)
    case fractionOutOfRange(tileIndex: Int, field: String, value: Double)
    case nonPositiveSize(tileIndex: Int, field: String, value: Double)

    public var description: String {
        switch self {
        case .emptyID:
            return "Layout id must not be empty."
        case .noTiles:
            return "Layout must contain at least one tile."
        case let .notFinite(index, field):
            return "Tile \(index) has a non-finite \(field) (NaN or infinite)."
        case let .fractionOutOfRange(index, field, value):
            return "Tile \(index) has \(field)=\(value), which is outside the allowed 0...1 range."
        case let .nonPositiveSize(index, field, value):
            return "Tile \(index) has \(field)=\(value), which must be greater than 0."
        }
    }
}

extension Layout {
    /// A small tolerance so values produced by floating-point division (e.g.
    /// 1.0/3.0 * 3) that land just outside `[0, 1]` are still accepted.
    static let fractionTolerance = 1e-6

    /// Validates that the layout is well-formed: non-empty id, at least one
    /// tile, and every tile within the normalized coordinate space (finite,
    /// non-negative size, not extending past the screen).
    ///
    /// Deliberately **not** checked: tile overlap or full-screen coverage.
    /// Tiling Shell layouts aren't required to tile the screen exactly (see the
    /// "Focus" built-in, whose side columns don't need to touch), and rejecting
    /// overlap would break legitimate hand-authored layouts with intentionally
    /// redundant zones. The tradeoff: an overlapping tile can become
    /// unreachable by click/hit-testing (the earlier tile in array order always
    /// wins ties) or by keyboard navigation (identical centers never satisfy
    /// the "primary > epsilon" gate in `DirectionalNavigation`) — a silently
    /// degraded layout, not a crash.
    public func validate() throws {
        if id.isEmpty { throw LayoutValidationError.emptyID }
        if tiles.isEmpty { throw LayoutValidationError.noTiles }

        let lower = -Layout.fractionTolerance
        let upper = 1 + Layout.fractionTolerance
        for (index, tile) in tiles.enumerated() {
            // NaN/infinite values compare false against every bound below, so
            // they must be rejected explicitly before any range check runs —
            // otherwise a NaN tile silently passes validation and poisons every
            // downstream geometry calculation.
            for (field, value) in [("x", tile.x), ("y", tile.y), ("width", tile.width), ("height", tile.height)] {
                if !value.isFinite {
                    throw LayoutValidationError.notFinite(tileIndex: index, field: field)
                }
            }

            for (field, value) in [("x", tile.x), ("y", tile.y)] {
                if value < lower || value > upper {
                    throw LayoutValidationError.fractionOutOfRange(tileIndex: index, field: field, value: value)
                }
            }
            for (field, value) in [("width", tile.width), ("height", tile.height)] {
                if value <= 0 {
                    throw LayoutValidationError.nonPositiveSize(tileIndex: index, field: field, value: value)
                }
                if value > upper {
                    throw LayoutValidationError.fractionOutOfRange(tileIndex: index, field: field, value: value)
                }
            }
            if tile.maxX > upper {
                throw LayoutValidationError.fractionOutOfRange(tileIndex: index, field: "x+width", value: tile.maxX)
            }
            if tile.maxY > upper {
                throw LayoutValidationError.fractionOutOfRange(tileIndex: index, field: "y+height", value: tile.maxY)
            }
        }
    }

    public var isValid: Bool {
        (try? validate()) != nil
    }
}
