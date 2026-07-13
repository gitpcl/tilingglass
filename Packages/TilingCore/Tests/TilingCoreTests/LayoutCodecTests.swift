import XCTest
@testable import TilingCore

final class LayoutCodecTests: XCTestCase {
    /// Verbatim from domferr/tilingshell doc/json-internal-documentation.md.
    private let tilingShellExample = """
    {
    	"id": "Equal split",
    	"tiles": [
    		{
    			"x": 0,
    			"y": 0,
    			"width": 0.5,
    			"height": 1,
    			"groups": [ 1 ]
    		},
    		{
    			"x": 0.5,
    			"y": 0,
    			"width": 0.5,
    			"height": 1,
    			"groups": [ 1 ]
    		}
    	]
    }
    """

    func testDecodesSingleTilingShellLayout() throws {
        let layouts = try LayoutCodec.decode(Data(tilingShellExample.utf8))
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        XCTAssertEqual(layout.id, "Equal split")
        XCTAssertEqual(layout.tiles.count, 2)
        XCTAssertEqual(layout.tiles[0], Tile(x: 0, y: 0, width: 0.5, height: 1, groups: [1]))
        XCTAssertEqual(layout.tiles[1], Tile(x: 0.5, y: 0, width: 0.5, height: 1, groups: [1]))
    }

    func testDecodesArrayOfLayouts() throws {
        let data = try LayoutCodec.encode(BuiltinLayouts.all)
        let decoded = try LayoutCodec.decode(data)
        XCTAssertEqual(decoded, BuiltinLayouts.all)
    }

    func testRoundTripPreservesGroups() throws {
        let data = try LayoutCodec.encode([BuiltinLayouts.grid2x2])
        let decoded = try LayoutCodec.decode(data)
        XCTAssertEqual(decoded.first?.tiles.map(\.groups), BuiltinLayouts.grid2x2.tiles.map(\.groups))
    }

    func testExportIsArrayShaped() throws {
        let data = try LayoutCodec.encode([BuiltinLayouts.equalSplit])
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [Any], "Export must be a JSON array to match Tiling Shell")
    }

    func testRejectsNonJSON() {
        XCTAssertThrowsError(try LayoutCodec.decode(Data("not json {".utf8))) { error in
            XCTAssertEqual(error as? LayoutCodec.DecodingError, .notJSON)
        }
    }

    func testRejectsWrongShape() {
        // Valid JSON, but a number rather than a layout/array.
        XCTAssertThrowsError(try LayoutCodec.decode(Data("42".utf8))) { error in
            XCTAssertEqual(error as? LayoutCodec.DecodingError, .wrongShape)
        }
    }

    func testRejectsEmptyArray() {
        XCTAssertThrowsError(try LayoutCodec.decode(Data("[]".utf8))) { error in
            XCTAssertEqual(error as? LayoutCodec.DecodingError, .empty)
        }
    }

    func testRejectsDuplicateIDs() {
        let dup = """
        [ {"id":"A","tiles":[{"x":0,"y":0,"width":1,"height":1,"groups":[]}]},
          {"id":"A","tiles":[{"x":0,"y":0,"width":1,"height":1,"groups":[]}]} ]
        """
        XCTAssertThrowsError(try LayoutCodec.decode(Data(dup.utf8))) { error in
            XCTAssertEqual(error as? LayoutCodec.DecodingError, .duplicateID("A"))
        }
    }

    func testRejectsOutOfRangeTile() {
        let bad = """
        {"id":"Bad","tiles":[{"x":0,"y":0,"width":1.5,"height":1,"groups":[]}]}
        """
        XCTAssertThrowsError(try LayoutCodec.decode(Data(bad.utf8))) { error in
            guard case .invalidLayout(let id, _)? = error as? LayoutCodec.DecodingError else {
                return XCTFail("Expected invalidLayout, got \(error)")
            }
            XCTAssertEqual(id, "Bad")
        }
    }

    func testMissingGroupsDefaultsToEmpty() throws {
        // Hand-authored layouts may omit `groups`; import should tolerate it.
        let noGroups = """
        {"id":"NG","tiles":[{"x":0,"y":0,"width":1,"height":1}]}
        """
        let layouts = try LayoutCodec.decode(Data(noGroups.utf8))
        XCTAssertEqual(layouts.first?.tiles.first?.groups, [])
    }
}
