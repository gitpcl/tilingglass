import XCTest
@testable import TilingCore

final class DirectionalNavigationTests: XCTestCase {
    private let gridScreen = ScreenSlot(
        id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.grid2x2
    )

    private func destination(
        tile: Int?, direction: TileDirection, screens: [ScreenSlot], current: Int = 0,
        windowFrame: CGRect = CGRect(x: 0, y: 0, width: 500, height: 400)
    ) -> DirectionalNavigation.Destination? {
        DirectionalNavigation.destination(
            windowFrame: windowFrame, currentTileIndex: tile, direction: direction,
            screens: screens, currentScreenID: current
        )
    }

    // MARK: - Same screen

    func testMoveRightWithinGrid() {
        // Tile 0 (top-left) → tile 1 (top-right).
        let d = destination(tile: 0, direction: .right, screens: [gridScreen])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 1))
    }

    func testMoveDownWithinGrid() {
        // Tile 0 (top-left) → tile 2 (bottom-left), not the diagonal.
        let d = destination(tile: 0, direction: .down, screens: [gridScreen])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 2))
    }

    func testMoveLeftWithinGrid() {
        let d = destination(tile: 1, direction: .left, screens: [gridScreen])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 0))
    }

    func testMoveUpWithinGrid() {
        let d = destination(tile: 2, direction: .up, screens: [gridScreen])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 0))
    }

    func testNoDestinationAtEdgeSingleScreen() {
        // Tile 1 (top-right) moving right with only one screen → nowhere.
        XCTAssertNil(destination(tile: 1, direction: .right, screens: [gridScreen]))
    }

    func testInfersCurrentTileFromWindowFrameWhenUnknown() {
        // No tile hint; window occupies the top-left quadrant → move right = tile 1.
        let d = destination(
            tile: nil, direction: .right, screens: [gridScreen],
            windowFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 1))
    }

    // MARK: - Cross monitor

    func testCrossesToRightMonitor() {
        let left = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.equalSplit)
        let right = ScreenSlot(id: 1, frame: CGRect(x: 1000, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.equalSplit)
        // On the left screen's right tile, moving right → left tile of the right screen.
        let d = destination(tile: 1, direction: .right, screens: [left, right], current: 0)
        XCTAssertEqual(d, .init(screenID: 1, tileIndex: 0))
    }

    func testCrossesToBottomMonitorVerticalStack() {
        let top = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.grid2x2)
        let bottom = ScreenSlot(id: 1, frame: CGRect(x: 0, y: 800, width: 1000, height: 800), layout: BuiltinLayouts.grid2x2)
        // Bottom-left tile of the top screen, moving down, entering near x=250 →
        // top-left tile of the bottom screen.
        let d = destination(tile: 2, direction: .down, screens: [top, bottom], current: 0)
        XCTAssertEqual(d, .init(screenID: 1, tileIndex: 0))
    }

    func testEnteringTilePicksNearestColumn() {
        // Enter the right monitor (grid) from a high entry point → top-left tile.
        let left = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.equalSplit)
        let right = ScreenSlot(id: 1, frame: CGRect(x: 1000, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.grid2x2)
        // Window in the upper region so the entry point is near the top.
        let d = destination(
            tile: nil, direction: .right, screens: [left, right], current: 0,
            windowFrame: CGRect(x: 500, y: 0, width: 500, height: 200) // center y = 100
        )
        XCTAssertEqual(d, .init(screenID: 1, tileIndex: 0)) // top-left of right screen
    }

    func testUnknownCurrentScreenReturnsNil() {
        XCTAssertNil(destination(tile: 0, direction: .right, screens: [gridScreen], current: 99))
    }
}
