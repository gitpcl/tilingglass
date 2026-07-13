import XCTest
@testable import TilingCore

final class ZoneHitTestingTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testHitsCorrectTileInGrid() {
        let layout = BuiltinLayouts.grid2x2
        // Top-left quadrant center.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 250, y: 200), layout: layout, screenRect: screen), 0)
        // Top-right.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 750, y: 200), layout: layout, screenRect: screen), 1)
        // Bottom-left.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 250, y: 600), layout: layout, screenRect: screen), 2)
        // Bottom-right.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 750, y: 600), layout: layout, screenRect: screen), 3)
    }

    func testBoundaryResolvesToEarlierTile() {
        let layout = BuiltinLayouts.equalSplit
        // Exactly on the middle boundary → earlier (left) tile wins.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 500, y: 400), layout: layout, screenRect: screen), 0)
    }

    func testFarEdgeIsInside() {
        let layout = BuiltinLayouts.equalSplit
        // The extreme right/bottom edge belongs to the last tile.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 1000, y: 800), layout: layout, screenRect: screen), 1)
    }

    func testPointOutsideScreenReturnsNil() {
        XCTAssertNil(ZoneHitTesting.tileIndex(at: CGPoint(x: -5, y: 400), layout: BuiltinLayouts.equalSplit, screenRect: screen))
    }

    func testRespectsScreenOrigin() {
        let offset = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        // A point in the right half of the offset screen.
        XCTAssertEqual(ZoneHitTesting.tileIndex(at: CGPoint(x: 1750, y: 400), layout: BuiltinLayouts.equalSplit, screenRect: offset), 1)
    }

    func testSpanSelectionTopRow() {
        let layout = BuiltinLayouts.grid2x2
        // Anchor top-left (0), hover top-right (1) → both top tiles, not bottom.
        let selection = ZoneHitTesting.spanSelection(anchor: 0, hovered: 1, layout: layout)
        XCTAssertEqual(selection, [0, 1])
    }

    func testSpanSelectionLeftColumn() {
        let layout = BuiltinLayouts.grid2x2
        // Anchor top-left (0), hover bottom-left (2) → left column.
        let selection = ZoneHitTesting.spanSelection(anchor: 0, hovered: 2, layout: layout)
        XCTAssertEqual(selection, [0, 2])
    }

    func testSpanSelectionWholeGrid() {
        let layout = BuiltinLayouts.grid2x2
        // Opposite corners → all four tiles.
        let selection = ZoneHitTesting.spanSelection(anchor: 0, hovered: 3, layout: layout)
        XCTAssertEqual(selection, [0, 1, 2, 3])
    }

    func testSpanSelectionSameTile() {
        let selection = ZoneHitTesting.spanSelection(anchor: 2, hovered: 2, layout: BuiltinLayouts.grid2x2)
        XCTAssertEqual(selection, [2])
    }

    func testTargetRectForFullGridIsWhole() {
        let layout = BuiltinLayouts.grid2x2
        let rect = ZoneHitTesting.targetNormalizedRect(for: [0, 1, 2, 3], layout: layout)
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testTargetRectForTopRow() {
        let layout = BuiltinLayouts.grid2x2
        let rect = ZoneHitTesting.targetNormalizedRect(for: [0, 1], layout: layout)
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1, height: 0.5))
    }

    func testTargetRectEmptySelection() {
        XCTAssertNil(ZoneHitTesting.targetNormalizedRect(for: [], layout: BuiltinLayouts.grid2x2))
    }

    /// Locks the top-left/y-down contract shared by resolve and hit-test: the
    /// center of every resolved tile must hit-test back to that same tile. A
    /// regression here would mean geometry and hit-testing disagree on
    /// orientation (the Y-inversion class of bug).
    func testResolveAndHitTestRoundTripForVerticalLayout() {
        // A vertical split with an asymmetric top/bottom so a y-flip would be
        // detectable (not masked by symmetry).
        let vertical = Layout(id: "V", tiles: [
            Tile(x: 0, y: 0, width: 1, height: 0.3),   // top band
            Tile(x: 0, y: 0.3, width: 1, height: 0.7),  // bottom band
        ])
        for layout in [BuiltinLayouts.grid2x2, BuiltinLayouts.thirds, vertical] {
            for index in layout.tiles.indices {
                let rect = ZoneGeometry.resolve(layout.tiles[index], in: screen, gaps: .zero)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                XCTAssertEqual(
                    ZoneHitTesting.tileIndex(at: center, layout: layout, screenRect: screen), index,
                    "\(layout.id) tile \(index) center should hit-test back to itself"
                )
            }
        }
    }

    /// The top tile must resolve to the top (smaller y) of the screen rect — pins
    /// the y-down orientation explicitly.
    func testTopTileResolvesToTop() {
        let vertical = Layout(id: "V", tiles: [
            Tile(x: 0, y: 0, width: 1, height: 0.5),
            Tile(x: 0, y: 0.5, width: 1, height: 0.5),
        ])
        let top = ZoneGeometry.resolve(vertical.tiles[0], in: screen, gaps: .zero)
        let bottom = ZoneGeometry.resolve(vertical.tiles[1], in: screen, gaps: .zero)
        XCTAssertLessThan(top.minY, bottom.minY)
        XCTAssertEqual(top.minY, screen.minY, accuracy: 0.001)
    }
}
