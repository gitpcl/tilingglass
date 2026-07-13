// SPDX-License-Identifier: GPL-3.0-only

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

    // MARK: - Asymmetric layout (same-row/column alignment must dominate raw distance)

    /// Regression: an unweighted primary+perpendicular score could pick a tile
    /// far off-axis (e.g. straight above) over one in the same row simply
    /// because the off-axis tile happened to be geometrically closer overall.
    /// A full-width top band plus two bottom columns is exactly this trap:
    /// moving "left" from the bottom-right column must land in the bottom-left
    /// column (same row), never the top band.
    func testMoveLeftPrefersSameRowOverCloserDiagonalTile() {
        let asym = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: Layout(id: "Asym", tiles: [
            Tile(x: 0, y: 0, width: 1.0, height: 0.3),   // 0: top band (full width)
            Tile(x: 0, y: 0.3, width: 0.2, height: 0.7), // 1: bottom-left column
            Tile(x: 0.2, y: 0.3, width: 0.8, height: 0.7), // 2: bottom-right column (current)
        ]))
        let d = destination(tile: 2, direction: .left, screens: [asym])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 1))
    }

    func testMoveUpPrefersSameColumnOverCloserDiagonalTile() {
        // Mirror layout: full-height left band plus two right rows.
        let asym = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 800, height: 1000), layout: Layout(id: "AsymV", tiles: [
            Tile(x: 0, y: 0, width: 0.3, height: 1.0),     // 0: left band (full height)
            Tile(x: 0.3, y: 0, width: 0.7, height: 0.2),   // 1: top-right row
            Tile(x: 0.3, y: 0.2, width: 0.7, height: 0.8), // 2: bottom-right row (current)
        ]))
        let d = destination(tile: 2, direction: .up, screens: [asym])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 1))
    }

    /// Regression: ranking adjacent-screen candidates by axis-distance alone
    /// (ignoring cross-axis overlap) could prefer a small monitor positioned
    /// far to the side over the monitor genuinely adjacent in that direction,
    /// in an irregular (non-grid) arrangement.
    func testAdjacentScreenPrefersTrueNeighborOverCloserOffAxisMonitor() {
        let current = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), layout: BuiltinLayouts.equalSplit)
        // Directly below `current` — the true neighbor, farther in raw distance.
        let below = ScreenSlot(id: 1, frame: CGRect(x: 0, y: 750, width: 1000, height: 800), layout: BuiltinLayouts.equalSplit)
        // Far to the side and tiny — numerically closer by center distance, but
        // not actually in the same column as `current`.
        let offToSide = ScreenSlot(id: 2, frame: CGRect(x: 5000, y: 850, width: 100, height: 100), layout: BuiltinLayouts.equalSplit)

        let d = destination(tile: 1, direction: .down, screens: [current, below, offToSide], current: 0)
        XCTAssertEqual(d?.screenID, 1)
    }

    func testFallsBackToClosestTileWhenNothingAligns() {
        // Two tiles, neither sharing a row with the reference: navigation must
        // still land somewhere rather than returning nil.
        let staggered = ScreenSlot(id: 0, frame: CGRect(x: 0, y: 0, width: 900, height: 900), layout: Layout(id: "Staggered", tiles: [
            Tile(x: 0, y: 0, width: 1.0 / 3.0, height: 1.0 / 3.0),         // 0: current, top-left small
            Tile(x: 2.0 / 3.0, y: 2.0 / 3.0, width: 1.0 / 3.0, height: 1.0 / 3.0), // 1: bottom-right small, no overlap
        ]))
        let d = destination(tile: 0, direction: .right, screens: [staggered])
        XCTAssertEqual(d, .init(screenID: 0, tileIndex: 1))
    }
}
