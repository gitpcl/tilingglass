// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Combine

/// Observable backing for one screen's overlay: the zone rects to draw (in
/// panel-local, top-left coordinates) and which of them are currently
/// highlighted. Updated only when values actually change to avoid needless
/// SwiftUI invalidations during a drag.
@MainActor
final class OverlayState: ObservableObject {
    @Published var zones: [CGRect] = []
    @Published var highlighted: Set<Int> = []

    func setHighlight(_ tiles: Set<Int>) {
        if highlighted != tiles { highlighted = tiles }
    }
}
