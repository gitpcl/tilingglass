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
    /// Drives the overlay's materialize/dissolve. The controller flips this to
    /// `false` and waits out the dissolve before tearing panels down, so the
    /// glass fades rather than vanishing.
    @Published var visible = false

    /// A highlight covering more than one zone is a span selection — the view
    /// renders it with a stronger tint than a single hovered zone. Single-zone
    /// hovers are always exactly one index, so count is a faithful signal.
    var isSpanning: Bool { highlighted.count > 1 }

    func setHighlight(_ tiles: Set<Int>) {
        if highlighted != tiles { highlighted = tiles }
    }
}
