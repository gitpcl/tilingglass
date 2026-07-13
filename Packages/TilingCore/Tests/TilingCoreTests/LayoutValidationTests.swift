import XCTest
@testable import TilingCore

final class LayoutValidationTests: XCTestCase {
    func testBuiltinsAreValid() throws {
        for layout in BuiltinLayouts.all {
            XCTAssertNoThrow(try layout.validate(), "\(layout.id) should be valid")
        }
    }

    func testEmptyIDRejected() {
        let layout = Layout(id: "", tiles: [Tile(x: 0, y: 0, width: 1, height: 1)])
        XCTAssertThrowsError(try layout.validate()) { error in
            XCTAssertEqual(error as? LayoutValidationError, .emptyID)
        }
    }

    func testNoTilesRejected() {
        XCTAssertThrowsError(try Layout(id: "X", tiles: []).validate()) { error in
            XCTAssertEqual(error as? LayoutValidationError, .noTiles)
        }
    }

    func testNegativeCoordinateRejected() {
        let layout = Layout(id: "X", tiles: [Tile(x: -0.1, y: 0, width: 0.5, height: 1)])
        XCTAssertThrowsError(try layout.validate())
    }

    func testZeroWidthRejected() {
        let layout = Layout(id: "X", tiles: [Tile(x: 0, y: 0, width: 0, height: 1)])
        XCTAssertThrowsError(try layout.validate()) { error in
            XCTAssertEqual(error as? LayoutValidationError, .nonPositiveSize(tileIndex: 0, field: "width", value: 0))
        }
    }

    func testOverflowingTileRejected() {
        // x + width exceeds 1.
        let layout = Layout(id: "X", tiles: [Tile(x: 0.8, y: 0, width: 0.5, height: 1)])
        XCTAssertThrowsError(try layout.validate())
    }

    func testThirdsToleratesFloatingPointDrift() throws {
        // 2/3 + 1/3 can land a hair above 1.0; validation tolerance must accept it.
        XCTAssertNoThrow(try BuiltinLayouts.thirds.validate())
    }
}
