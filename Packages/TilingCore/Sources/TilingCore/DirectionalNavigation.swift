import CoreGraphics

/// The four directions a window can be moved by keyboard.
public enum TileDirection: Sendable {
    case left, right, up, down
}

/// One screen's usable area plus the layout assigned to it, as seen by the
/// navigation logic. All frames are in a single top-left-origin space (y grows
/// downward), matching the layout coordinate convention; the app layer converts
/// from `NSScreen` before calling in.
public struct ScreenSlot: Sendable {
    public let id: Int
    public let frame: CGRect
    public let layout: Layout

    public init(id: Int, frame: CGRect, layout: Layout) {
        self.id = id
        self.frame = frame
        self.layout = layout
    }
}

/// Resolves keyboard tiling moves: "move the focused window one tile in a
/// direction," crossing to an adjacent monitor when there is no further tile on
/// the current one. Pure and fully unit-testable.
public enum DirectionalNavigation {
    public struct Destination: Equatable, Sendable {
        public let screenID: Int
        public let tileIndex: Int
        public init(screenID: Int, tileIndex: Int) {
            self.screenID = screenID
            self.tileIndex = tileIndex
        }
    }

    private static let epsilon: CGFloat = 0.5

    /// Computes the destination tile for a directional move.
    ///
    /// - Parameters:
    ///   - windowFrame: The window's current frame in top-left space (used when
    ///     `currentTileIndex` is unknown, and to choose an entry row/column when
    ///     crossing monitors).
    ///   - currentTileIndex: The tile the window is believed to occupy on the
    ///     current screen, if the engine tracked it; otherwise `nil` and the
    ///     current tile is inferred from `windowFrame`.
    ///   - direction: Which way to move.
    ///   - screens: All screens with their frames and layouts.
    ///   - currentScreenID: The screen the window is currently on.
    /// - Returns: The destination screen + tile, or `nil` if there is nowhere to go.
    public static func destination(
        windowFrame: CGRect,
        currentTileIndex: Int?,
        direction: TileDirection,
        screens: [ScreenSlot],
        currentScreenID: Int
    ) -> Destination? {
        guard let current = screens.first(where: { $0.id == currentScreenID }) else {
            return nil
        }

        let reference = referencePoint(
            windowFrame: windowFrame, currentTileIndex: currentTileIndex, screen: current
        )

        if let tile = nearestTile(in: current, from: reference, direction: direction, excluding: currentTileIndex) {
            return Destination(screenID: current.id, tileIndex: tile)
        }

        // No further tile on this screen — hop to the adjacent monitor.
        guard let neighbor = adjacentScreen(to: current, direction: direction, screens: screens) else {
            return nil
        }
        let entryPoint = entryPoint(into: neighbor, from: reference, direction: direction)
        guard let tile = enteringTile(in: neighbor, entryPoint: entryPoint, direction: direction) else {
            return nil
        }
        return Destination(screenID: neighbor.id, tileIndex: tile)
    }

    // MARK: - Reference & candidate resolution

    private static func referencePoint(
        windowFrame: CGRect, currentTileIndex: Int?, screen: ScreenSlot
    ) -> CGPoint {
        if let index = currentTileIndex, screen.layout.tiles.indices.contains(index) {
            return centerPixel(of: screen.layout.tiles[index], in: screen.frame)
        }
        return CGPoint(x: windowFrame.midX, y: windowFrame.midY)
    }

    private static func nearestTile(
        in screen: ScreenSlot, from reference: CGPoint, direction: TileDirection, excluding: Int?
    ) -> Int? {
        var best: (index: Int, score: CGFloat)?
        for (index, tile) in screen.layout.tiles.enumerated() {
            if index == excluding { continue }
            let center = centerPixel(of: tile, in: screen.frame)
            let (primary, perpendicular) = components(from: reference, to: center, direction: direction)
            guard primary > epsilon else { continue }
            let score = primary + perpendicular
            if best == nil || score < best!.score {
                best = (index, score)
            }
        }
        return best?.index
    }

    /// Splits the vector from `a` to `b` into its component along `direction`
    /// (must be positive to count as "in that direction") and the perpendicular
    /// component. Remember y grows downward.
    private static func components(
        from a: CGPoint, to b: CGPoint, direction: TileDirection
    ) -> (primary: CGFloat, perpendicular: CGFloat) {
        switch direction {
        case .left:  return (a.x - b.x, abs(b.y - a.y))
        case .right: return (b.x - a.x, abs(b.y - a.y))
        case .up:    return (a.y - b.y, abs(b.x - a.x))
        case .down:  return (b.y - a.y, abs(b.x - a.x))
        }
    }

    // MARK: - Cross-monitor

    private static func adjacentScreen(
        to current: ScreenSlot, direction: TileDirection, screens: [ScreenSlot]
    ) -> ScreenSlot? {
        var best: (screen: ScreenSlot, distance: CGFloat)?
        for screen in screens where screen.id != current.id {
            guard isInDirection(screen.frame, from: current.frame, direction: direction) else { continue }
            let distance = centerDistanceAlongAxis(screen.frame, current.frame, direction: direction)
            if best == nil || distance < best!.distance {
                best = (screen, distance)
            }
        }
        return best?.screen
    }

    private static func isInDirection(_ frame: CGRect, from origin: CGRect, direction: TileDirection) -> Bool {
        switch direction {
        case .left:  return frame.midX < origin.midX - epsilon
        case .right: return frame.midX > origin.midX + epsilon
        case .up:    return frame.midY < origin.midY - epsilon
        case .down:  return frame.midY > origin.midY + epsilon
        }
    }

    private static func centerDistanceAlongAxis(_ a: CGRect, _ b: CGRect, direction: TileDirection) -> CGFloat {
        switch direction {
        case .left, .right: return abs(a.midX - b.midX)
        case .up, .down:    return abs(a.midY - b.midY)
        }
    }

    /// The point at which the window "enters" the neighbouring screen, used to
    /// choose which row/column of tiles to land in. The cross-axis position is
    /// carried over from the reference and clamped into the new screen.
    private static func entryPoint(
        into screen: ScreenSlot, from reference: CGPoint, direction: TileDirection
    ) -> CGPoint {
        let f = screen.frame
        switch direction {
        case .left:
            return CGPoint(x: f.maxX, y: clamp(reference.y, f.minY, f.maxY))
        case .right:
            return CGPoint(x: f.minX, y: clamp(reference.y, f.minY, f.maxY))
        case .up:
            return CGPoint(x: clamp(reference.x, f.minX, f.maxX), y: f.maxY)
        case .down:
            return CGPoint(x: clamp(reference.x, f.minX, f.maxX), y: f.minY)
        }
    }

    /// Picks the tile on the entering edge of a screen nearest the entry point.
    private static func enteringTile(
        in screen: ScreenSlot, entryPoint: CGPoint, direction: TileDirection
    ) -> Int? {
        var best: (index: Int, score: CGFloat)?
        for (index, tile) in screen.layout.tiles.enumerated() {
            let rect = pixelRect(of: tile, in: screen.frame)
            // Distance from the entering edge (how far "in" the tile is).
            let edgeDistance: CGFloat
            switch direction {
            case .left:  edgeDistance = screen.frame.maxX - rect.maxX
            case .right: edgeDistance = rect.minX - screen.frame.minX
            case .up:    edgeDistance = screen.frame.maxY - rect.maxY
            case .down:  edgeDistance = rect.minY - screen.frame.minY
            }
            // Distance along the cross axis from the entry point.
            let crossDistance: CGFloat
            switch direction {
            case .left, .right: crossDistance = abs(rect.midY - entryPoint.y)
            case .up, .down:    crossDistance = abs(rect.midX - entryPoint.x)
            }
            let score = edgeDistance + crossDistance
            if best == nil || score < best!.score {
                best = (index, score)
            }
        }
        return best?.index
    }

    // MARK: - Helpers

    private static func pixelRect(of tile: Tile, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + CGFloat(tile.x) * frame.width,
            y: frame.minY + CGFloat(tile.y) * frame.height,
            width: CGFloat(tile.width) * frame.width,
            height: CGFloat(tile.height) * frame.height
        )
    }

    private static func centerPixel(of tile: Tile, in frame: CGRect) -> CGPoint {
        let rect = pixelRect(of: tile, in: frame)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private static func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}
