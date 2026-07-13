// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// Reads and writes layouts in the Tiling Shell JSON format so files can be
/// exchanged between TilingGlass and the GNOME extension.
///
/// Tiling Shell exports a JSON *array* of layout objects. For convenience we
/// also accept a single bare layout object on import.
public enum LayoutCodec {
    public enum DecodingError: Error, Equatable, CustomStringConvertible {
        case notJSON
        case wrongShape
        /// The top-level shape (object or array) was correct, but decoding it
        /// into `Layout`/`Tile` failed — e.g. a missing key or wrong-typed field
        /// on one element. Carries the underlying decoder's own description.
        case malformed(reason: String)
        case empty
        case duplicateID(String)
        case invalidLayout(id: String, reason: String)

        public var description: String {
            switch self {
            case .notJSON:
                return "The file is not valid JSON."
            case .wrongShape:
                return "Expected a layout object or an array of layout objects."
            case let .malformed(reason):
                return "Could not read the layout data: \(reason)"
            case .empty:
                return "The file contained no layouts."
            case let .duplicateID(id):
                return "Duplicate layout id \"\(id)\"."
            case let .invalidLayout(id, reason):
                return "Layout \"\(id)\" is invalid: \(reason)"
            }
        }
    }

    /// Decodes one or more layouts from Tiling Shell-format JSON data.
    ///
    /// Accepts either a top-level array of layouts or a single layout object.
    /// Every decoded layout is validated; duplicate ids are rejected.
    public static func decode(_ data: Data) throws -> [Layout] {
        // Determine the top-level shape first (object vs array vs neither) via
        // JSONSerialization, then decode with the matching decoder and surface
        // *its* real error. Trying `[Layout].self` then `Layout.self` with
        // `try?` (the previous approach) discarded the actual decoding failure
        // whenever the shape was right but a field inside it was wrong — e.g. an
        // array with one malformed element reported the misleading "expected an
        // object or array" instead of the real problem.
        let topLevel: Any
        do {
            topLevel = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw DecodingError.notJSON
        }

        let decoder = JSONDecoder()
        let layouts: [Layout]
        do {
            if topLevel is [Any] {
                layouts = try decoder.decode([Layout].self, from: data)
            } else if topLevel is [String: Any] {
                layouts = [try decoder.decode(Layout.self, from: data)]
            } else {
                throw DecodingError.wrongShape
            }
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.malformed(reason: String(describing: error))
        }

        if layouts.isEmpty { throw DecodingError.empty }

        var seen = Set<String>()
        for layout in layouts {
            do {
                try layout.validate()
            } catch {
                throw DecodingError.invalidLayout(id: layout.id, reason: String(describing: error))
            }
            guard seen.insert(layout.id).inserted else {
                throw DecodingError.duplicateID(layout.id)
            }
        }
        return layouts
    }

    /// Encodes layouts as a pretty-printed JSON array, matching the shape
    /// Tiling Shell produces on export.
    public static func encode(_ layouts: [Layout]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(layouts)
    }
}
