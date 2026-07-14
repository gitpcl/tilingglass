// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import TilingCore

final class LayoutEditingTests: XCTestCase {
    private let fullScreen = Layout(id: "One", tiles: [Tile(x: 0, y: 0, width: 1, height: 1)])

    // MARK: - Splitting

    func testHorizontalSplitProducesLeftAndRightHalves() {
        let result = LayoutEditing.splitting(fullScreen, tileAt: 0, .horizontal)
        XCTAssertEqual(result.tiles.count, 2)
        XCTAssertEqual(result.tiles[0], Tile(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(result.tiles[1], Tile(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testVerticalSplitProducesTopAndBottomHalves() {
        let result = LayoutEditing.splitting(fullScreen, tileAt: 0, .vertical)
        XCTAssertEqual(result.tiles.count, 2)
        XCTAssertEqual(result.tiles[0], Tile(x: 0, y: 0, width: 1, height: 0.5))
        XCTAssertEqual(result.tiles[1], Tile(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    func testSplitPreservesOtherTiles() {
        let base = BuiltinLayouts.equalSplit
        let result = LayoutEditing.splitting(base, tileAt: 1, .vertical)
        XCTAssertEqual(result.tiles.count, 3)
        // Tile 0 untouched.
        XCTAssertEqual(result.tiles[0].x, base.tiles[0].x)
        XCTAssertEqual(result.tiles[0].width, base.tiles[0].width)
        // Right half split into top/bottom quarters.
        XCTAssertEqual(result.tiles[1], Tile(x: 0.5, y: 0, width: 0.5, height: 0.5))
        XCTAssertEqual(result.tiles[2], Tile(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    func testSplitInvalidIndexReturnsLayoutUnchanged() {
        let result = LayoutEditing.splitting(fullScreen, tileAt: 5, .horizontal)
        XCTAssertEqual(result, fullScreen)
    }

    func testSplitResultValidates() throws {
        var layout = fullScreen
        // A few rounds of splitting always yields a valid layout.
        layout = LayoutEditing.splitting(layout, tileAt: 0, .horizontal)
        layout = LayoutEditing.splitting(layout, tileAt: 1, .vertical)
        layout = LayoutEditing.splitting(layout, tileAt: 0, .vertical)
        XCTAssertNoThrow(try layout.validate())
        XCTAssertEqual(layout.tiles.count, 4)
    }

    // MARK: - Removing

    func testRemoveMergesIntoFullEdgeNeighbor() {
        let base = BuiltinLayouts.equalSplit
        let result = LayoutEditing.removing(base, tileAt: 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tiles.count, 1)
        XCTAssertEqual(result?.tiles[0], Tile(x: 0, y: 0, width: 1, height: 1, groups: base.tiles[0].groups))
    }

    func testRemoveVerticalNeighborAbsorbs() {
        let stacked = Layout(id: "V", tiles: [
            Tile(x: 0, y: 0, width: 1, height: 0.5),
            Tile(x: 0, y: 0.5, width: 1, height: 0.5),
        ])
        let result = LayoutEditing.removing(stacked, tileAt: 0)
        XCTAssertEqual(result?.tiles.count, 1)
        XCTAssertEqual(result?.tiles[0].y ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(result?.tiles[0].height ?? -1, 1, accuracy: 1e-9)
    }

    func testRemoveLastTileReturnsNil() {
        XCTAssertNil(LayoutEditing.removing(fullScreen, tileAt: 0))
    }

    func testRemoveWithoutFullEdgeNeighborReturnsNil() {
        // The "Focus" side columns each fully border the center, but in a 2x2
        // grid, no single neighbor shares a *full* edge with a quadrant twice
        // its size... Construct explicitly: an L-shaped arrangement where the
        // candidate neighbors only partially overlap the removed tile's edge.
        let awkward = Layout(id: "L", tiles: [
            Tile(x: 0, y: 0, width: 0.5, height: 1),        // tall left column
            Tile(x: 0.5, y: 0, width: 0.5, height: 0.5),    // top-right
            Tile(x: 0.5, y: 0.5, width: 0.5, height: 0.5),  // bottom-right
        ])
        // Removing the tall left column: neither right tile spans its full
        // edge alone — merge must fail rather than corrupt the layout.
        XCTAssertNil(LayoutEditing.removing(awkward, tileAt: 0))
    }

    func testRemoveFromGridMergesWithRowNeighbor() {
        let result = LayoutEditing.removing(BuiltinLayouts.grid2x2, tileAt: 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tiles.count, 3)
        // Top-left absorbed the top-right; now spans the full top row.
        let absorbed = result?.tiles.first { $0.y == 0 && $0.height == 0.5 && $0.width == 1 }
        XCTAssertNotNil(absorbed)
    }

    func testRemoveInvalidIndexReturnsNil() {
        XCTAssertNil(LayoutEditing.removing(BuiltinLayouts.equalSplit, tileAt: 9))
    }

    // MARK: - Boundary hit-testing

    func testFindsVerticalBoundaryBetweenHalves() {
        let boundary = LayoutEditing.boundary(
            near: CGPoint(x: 0.49, y: 0.5), in: BuiltinLayouts.equalSplit, tolerance: 0.02
        )
        XCTAssertNotNil(boundary)
        XCTAssertEqual(boundary?.orientation, .vertical)
        XCTAssertEqual(boundary?.position ?? -1, 0.5, accuracy: 1e-9)
    }

    func testNoBoundaryFarFromEdges() {
        XCTAssertNil(LayoutEditing.boundary(
            near: CGPoint(x: 0.25, y: 0.5), in: BuiltinLayouts.equalSplit, tolerance: 0.02
        ))
    }

    func testScreenEdgeIsNotABoundary() {
        // x=0 is the screen edge, not an internal boundary.
        XCTAssertNil(LayoutEditing.boundary(
            near: CGPoint(x: 0.005, y: 0.5), in: BuiltinLayouts.equalSplit, tolerance: 0.02
        ))
    }

    func testGridBoundaryOnlyCoversLocalSegment() {
        // In a 2x2 grid at the vertical mid-line, grabbing in the top half
        // should affect only the two top tiles.
        let boundary = LayoutEditing.boundary(
            near: CGPoint(x: 0.5, y: 0.25), in: BuiltinLayouts.grid2x2, tolerance: 0.02
        )
        XCTAssertEqual(boundary?.leadingTiles, [0])
        XCTAssertEqual(boundary?.trailingTiles, [1])
    }

    // MARK: - Boundary dragging

    func testMoveVerticalBoundaryResizesBothSides() {
        let layout = BuiltinLayouts.equalSplit
        guard let boundary = LayoutEditing.boundary(near: CGPoint(x: 0.5, y: 0.5), in: layout, tolerance: 0.02) else {
            return XCTFail("boundary not found")
        }
        let moved = LayoutEditing.movingBoundary(layout, boundary: boundary, to: 0.6, minTileSize: 0.05)
        XCTAssertEqual(moved.tiles[0].width, 0.6, accuracy: 1e-9)
        XCTAssertEqual(moved.tiles[1].x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(moved.tiles[1].width, 0.4, accuracy: 1e-9)
        XCTAssertNoThrow(try moved.validate())
    }

    func testMoveBoundaryClampsToMinimumTileSize() {
        let layout = BuiltinLayouts.equalSplit
        guard let boundary = LayoutEditing.boundary(near: CGPoint(x: 0.5, y: 0.5), in: layout, tolerance: 0.02) else {
            return XCTFail("boundary not found")
        }
        // Try to crush the left tile to nothing; it must clamp at minTileSize.
        let moved = LayoutEditing.movingBoundary(layout, boundary: boundary, to: 0.0, minTileSize: 0.05)
        XCTAssertEqual(moved.tiles[0].width, 0.05, accuracy: 1e-9)
        XCTAssertNoThrow(try moved.validate())
    }

    func testMoveGridSegmentLeavesOtherRowUntouched() {
        let layout = BuiltinLayouts.grid2x2
        guard let boundary = LayoutEditing.boundary(near: CGPoint(x: 0.5, y: 0.25), in: layout, tolerance: 0.02) else {
            return XCTFail("boundary not found")
        }
        let moved = LayoutEditing.movingBoundary(layout, boundary: boundary, to: 0.7, minTileSize: 0.05)
        // Top row moved.
        XCTAssertEqual(moved.tiles[0].width, 0.7, accuracy: 1e-9)
        XCTAssertEqual(moved.tiles[1].x, 0.7, accuracy: 1e-9)
        // Bottom row untouched.
        XCTAssertEqual(moved.tiles[2].width, 0.5, accuracy: 1e-9)
        XCTAssertEqual(moved.tiles[3].x, 0.5, accuracy: 1e-9)
        XCTAssertNoThrow(try moved.validate())
    }

    // MARK: - Groups recomputation

    func testGroupsForEqualSplitMatchTilingShellShape() {
        let raw = Layout(id: "E", tiles: [
            Tile(x: 0, y: 0, width: 0.5, height: 1),
            Tile(x: 0.5, y: 0, width: 0.5, height: 1),
        ])
        let grouped = LayoutEditing.recomputingGroups(raw)
        // One shared edge → both tiles carry the same single group id.
        XCTAssertEqual(grouped.tiles[0].groups.count, 1)
        XCTAssertEqual(grouped.tiles[0].groups, grouped.tiles[1].groups)
    }

    func testGroupsForGridGiveEachTileTwoEdges() {
        let raw = Layout(id: "G", tiles: BuiltinLayouts.grid2x2.tiles.map {
            Tile(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
        })
        let grouped = LayoutEditing.recomputingGroups(raw)
        // Every quadrant touches exactly two internal edge segments (like the
        // Tiling Shell builtin: [1,3],[1,4],[2,3],[2,4]).
        for tile in grouped.tiles {
            XCTAssertEqual(tile.groups.count, 2, "each quadrant borders two segments")
        }
        // Four distinct segments in total.
        let allIDs = Set(grouped.tiles.flatMap(\.groups))
        XCTAssertEqual(allIDs.count, 4)
        // Horizontally adjacent pairs share an id; diagonal pairs share none.
        let tl = Set(grouped.tiles[0].groups), tr = Set(grouped.tiles[1].groups)
        let bl = Set(grouped.tiles[2].groups), br = Set(grouped.tiles[3].groups)
        XCTAssertEqual(tl.intersection(tr).count, 1)
        XCTAssertEqual(tl.intersection(bl).count, 1)
        XCTAssertEqual(tl.intersection(br).count, 0)
    }

    func testGroupsSingleTileIsEmpty() {
        let grouped = LayoutEditing.recomputingGroups(fullScreen)
        XCTAssertEqual(grouped.tiles[0].groups, [])
    }
}
