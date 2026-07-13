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
        case empty
        case duplicateID(String)
        case invalidLayout(id: String, reason: String)

        public var description: String {
            switch self {
            case .notJSON:
                return "The file is not valid JSON."
            case .wrongShape:
                return "Expected a layout object or an array of layout objects."
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
        let decoder = JSONDecoder()

        let layouts: [Layout]
        if let array = try? decoder.decode([Layout].self, from: data) {
            layouts = array
        } else if let single = try? decoder.decode(Layout.self, from: data) {
            layouts = [single]
        } else {
            // Distinguish "not JSON at all" from "JSON of the wrong shape" for a
            // clearer error message. `.fragmentsAllowed` lets a bare value like
            // `42` parse as valid-but-wrong-shape rather than not-JSON.
            if (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) == nil {
                throw DecodingError.notJSON
            }
            throw DecodingError.wrongShape
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
