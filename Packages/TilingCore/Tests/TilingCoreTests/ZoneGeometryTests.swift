// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import TilingCore

final class ZoneGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testResolvesWithoutGaps() {
        let tile = Tile(x: 0.5, y: 0, width: 0.5, height: 1)
        let rect = ZoneGeometry.resolve(tile, in: screen, gaps: .zero)
        XCTAssertEqual(rect, CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    func testOuterGapOnScreenEdges() {
        // Full-screen tile: every edge is a screen boundary → outer gap on all sides.
        let tile = Tile(x: 0, y: 0, width: 1, height: 1)
        let rect = ZoneGeometry.resolve(tile, in: screen, gaps: Gaps(inner: 8, outer: 10))
        XCTAssertEqual(rect, CGRect(x: 10, y: 10, width: 980, height: 780))
    }

    func testInnerGapOnSharedEdge() {
        // Two side-by-side halves with inner 8 / outer 10. The shared middle
        // edge gets inner/2 = 4 from each tile; the visible gap between them is 8.
        let gaps = Gaps(inner: 8, outer: 10)
        let left = ZoneGeometry.resolve(Tile(x: 0, y: 0, width: 0.5, height: 1), in: screen, gaps: gaps)
        let right = ZoneGeometry.resolve(Tile(x: 0.5, y: 0, width: 0.5, height: 1), in: screen, gaps: gaps)

        XCTAssertEqual(left.minX, 10, accuracy: 0.001)   // outer on far left
        XCTAssertEqual(left.maxX, 496, accuracy: 0.001)  // 500 - inner/2
        XCTAssertEqual(right.minX, 504, accuracy: 0.001) // 500 + inner/2
        XCTAssertEqual(right.maxX, 990, accuracy: 0.001) // outer on far right
        XCTAssertEqual(right.minX - left.maxX, 8, accuracy: 0.001) // visible gap == inner
    }

    func testResolveNormalizedRectAppliesEdgeRules() {
        // A union rect spanning the whole top half: left/top/right edges are
        // screen boundaries (outer), bottom edge is interior (inner/2).
        let gaps = Gaps(inner: 8, outer: 10)
        let rect = ZoneGeometry.resolve(
            normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 0.5),
            in: screen, gaps: gaps
        )
        XCTAssertEqual(rect.minX, 10, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, 990, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 396, accuracy: 0.001) // 400 - inner/2
    }

    func testRespectsScreenOrigin() {
        // Secondary screen offset from the origin.
        let offset = CGRect(x: 1000, y: 200, width: 800, height: 600)
        let rect = ZoneGeometry.resolve(Tile(x: 0, y: 0, width: 1, height: 1), in: offset, gaps: .zero)
        XCTAssertEqual(rect, offset)
    }

    func testSingleTileLayout() {
        let rect = ZoneGeometry.resolve(Tile(x: 0, y: 0, width: 1, height: 1), in: screen, gaps: .zero)
        XCTAssertEqual(rect, screen)
    }

    /// Regression for a bug where `CGRect.width`/`.height` (which return the
    /// *absolute value* of a negative computed size) defeated the `max(1, ...)`
    /// floor, letting a tile whose gaps exceed its own pixel size resolve to a
    /// large rect positioned outside the tile's own footprint.
    func testGapsExceedingTileSizeCollapseNearTileFootprint() {
        // A tiny 10x8pt tile (1% of a 1000x800 screen) with a 100pt inner gap:
        // each edge would be inset by 50pt, far exceeding the tile itself.
        let tile = Tile(x: 0.5, y: 0.5, width: 0.01, height: 0.01)
        let rect = ZoneGeometry.resolve(tile, in: screen, gaps: Gaps(inner: 100, outer: 10))

        // Must not silently invert into a large, mispositioned rect.
        XCTAssertLessThanOrEqual(rect.width, 10)
        XCTAssertLessThanOrEqual(rect.height, 8)
        XCTAssertGreaterThanOrEqual(rect.width, 1)
        XCTAssertGreaterThanOrEqual(rect.height, 1)

        // The fallback rect must stay within (or immediately at) the tile's own
        // pixel footprint: x in [500, 510], y in [400, 408].
        XCTAssertGreaterThanOrEqual(rect.minX, 500 - 0.001)
        XCTAssertLessThanOrEqual(rect.maxX, 510 + 0.001)
        XCTAssertGreaterThanOrEqual(rect.minY, 400 - 0.001)
        XCTAssertLessThanOrEqual(rect.maxY, 408 + 0.001)
    }

    func testNegativeGapsAreClampedToZero() {
        // Gaps is a public boundary type; negative values (e.g. from a
        // corrupted defaults value) must not reach the geometry math.
        let gaps = Gaps(inner: -40, outer: -20)
        XCTAssertEqual(gaps.inner, 0)
        XCTAssertEqual(gaps.outer, 0)

        let rect = ZoneGeometry.resolve(Tile(x: 0, y: 0, width: 1, height: 1), in: screen, gaps: gaps)
        XCTAssertEqual(rect, screen)
    }
}
