# TilingGlass

A macOS port of the GNOME [Tiling Shell](https://github.com/domferr/tilingshell)
extension: FancyZones-style custom tiling layouts, snapped into with a modifier
key and a Liquid Glass overlay, plus full keyboard tiling.

Drag a window while holding a modifier key to reveal your layout's zones, hover
one to highlight it, and release to snap the window in. Hold a second modifier
while dragging to span several adjacent zones with one window. Move the focused
window between zones — and across monitors — entirely from the keyboard.
Layouts are stored in, and interchangeable with, Tiling Shell's own JSON format.

> **Status:** early development (v0.1). Requires macOS 26 (Tahoe) or later.

## Contents

- [What it does](#what-it-does)
- [Features](#features)
- [Requirements](#requirements)
- [Installation / building](#installation--building)
- [First run](#first-run)
- [Using TilingGlass](#using-tilingglass)
  - [The menu bar](#the-menu-bar)
  - [Snapping a window with the mouse](#snapping-a-window-with-the-mouse)
  - [Spanning multiple zones](#spanning-multiple-zones)
  - [Keyboard tiling](#keyboard-tiling)
  - [Layouts](#layouts)
  - [Creating and editing layouts](#creating-and-editing-layouts)
  - [Importing and exporting layouts](#importing-and-exporting-layouts)
- [Settings](#settings)
- [Architecture](#architecture)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Permissions & privacy](#permissions--privacy)
- [License](#license)

## What it does

[Tiling Shell](https://github.com/domferr/tilingshell) is a well-regarded GNOME
Shell extension that brings Windows 11-style FancyZones tiling to Linux: instead
of the OS's built-in half/quarter snapping, you define your own zone layouts and
snap windows into them with a drag-and-modifier gesture. macOS has nothing quite
like it — native tiling (added in macOS 15 Sequoia, refined in Tahoe) only does
halves and quarters, with no custom zones and no per-app layouts.

TilingGlass ports that experience to macOS, natively: a menu-bar app built on
the Accessibility API, with a real Liquid Glass overlay for the zone picker.
Layout files are compatible with Tiling Shell's own JSON format, so a layout
designed in one can be used in the other.

## Features

Implemented in v0.1:

- **Menu-bar app** — no Dock icon, no main window, lives entirely in the status
  bar.
- **Custom tiling layouts**, stored in and interchangeable with Tiling Shell's
  JSON format.
- **Four built-in layouts** — Equal split, Thirds, 2x2 Grid, Focus (see
  [Layouts](#layouts) for what each looks like).
- **Tiling system** — hold a modifier while dragging a window to reveal a
  Liquid Glass zone overlay on every screen; the zone under the cursor
  highlights as you move; release to snap the window into it.
- **Span multiple zones** — hold a second modifier while dragging to select and
  merge several adjacent zones for one window.
- **Keyboard tiling** — move the focused window one zone in any direction, or
  across monitors, entirely from the keyboard.
- **Multi-monitor support** — each screen has its own independent layout
  selection; keyboard and drag tiling both work seamlessly across monitors,
  including mixed-DPI setups.
- **Configurable gaps** — independent inner (between zones) and outer (zone to
  screen edge) spacing.
- **Visual layout editor** — create and edit layouts by clicking zones to
  split them, right-clicking to delete, and dragging shared edges to resize
  (see [Creating and editing layouts](#creating-and-editing-layouts)).
- **Import / export** — round-trip layouts as Tiling Shell-format JSON files.

Not yet implemented (see [Roadmap](#roadmap)):
Windows 11-style snap assistant, screen-edge tiling, post-snap window
suggestions to fill empty zones, smart resize of adjacent tiles, auto-tiling
of new windows, and per-workspace layouts.

## Requirements

- macOS 26 (Tahoe) or later — the app uses real Liquid Glass materials
  (`glassEffect`/`NSGlassEffectView`), which don't exist on earlier macOS
  versions.
- Apple Silicon or Intel (no architecture-specific code; not yet verified on
  Intel).
- **Accessibility** permission (see [Permissions & privacy](#permissions--privacy)).

To build from source you additionally need Xcode 26+ and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Installation / building

There's no signed release yet — build it yourself:

```sh
brew install xcodegen   # once, if you don't have it

git clone <this-repo> tilingglass
cd tilingglass

xcodegen generate
xcodebuild -project TilingGlass.xcodeproj -scheme TilingGlass \
  -configuration Debug -derivedDataPath build build

open build/Build/Products/Debug/TilingGlass.app
```

`xcodegen generate` produces `TilingGlass.xcodeproj` from `project.yml` — the
`.xcodeproj` itself is gitignored and regenerated on demand, so re-run that
command any time `project.yml` changes (new source files, new dependencies,
etc.).

### Code signing (local dev)

`project.yml` pins a code-signing identity by SHA-1 so the Accessibility
permission survives rebuilds — an ad-hoc signature changes on every build and
silently resets the grant, which makes windows just stop moving after a
rebuild with no obvious cause. That identity is machine-specific: on any
machine other than the one it was pinned on, the build will fail signing
outright. Fix it one of two ways:

**Permanent (edit the tracked file):** replace the SHA-1 in `project.yml`
(`CODE_SIGN_IDENTITY[sdk=macosx*]`) with one of your own, found via:

```sh
security find-identity -v -p codesigning
```

**One-off (no file edit, nothing to accidentally commit):** override signing on
the command line. Accessibility permission will need to be re-granted after an
ad-hoc build, and again on every subsequent ad-hoc rebuild:

```sh
xcodebuild -project TilingGlass.xcodeproj -scheme TilingGlass \
  -configuration Debug -derivedDataPath build build \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM=""
```

If the Accessibility grant ever gets wedged during development:

```sh
tccutil reset Accessibility com.pedrolopes.tilingglass
```

## First run

1. Launch the app — a ▦ icon appears in the menu bar. There's no Dock icon and
   no window; the app is a pure menu-bar utility (`LSUIElement`).
2. An onboarding window opens automatically the first time. It walks through
   two steps:
   - **Grant Accessibility access** — click **Open Accessibility Settings**,
     then enable **TilingGlass** under System Settings → Privacy & Security →
     Accessibility. The window polls for the grant and updates automatically;
     click **Done** once it shows "Accessibility access granted."
   - **Turn off native edge tiling (recommended)** — click **Open Desktop &
     Dock** and disable "Drag windows to screen edges to tile," so macOS's own
     drag-to-edge tiling doesn't fight TilingGlass's modifier-gated one.
3. Nothing moves windows until Accessibility access is granted — this is a
   one-time manual step macOS requires for any app that positions other apps'
   windows (see [Permissions & privacy](#permissions--privacy)).

## Using TilingGlass

### The menu bar

Click the ▦ icon for:

- **Layout** — the active layout for each connected screen (screen names are
  shown as section headers when you have more than one display). Click a
  layout to make it active on that screen.
- **Import Layouts… / Export Layouts…** — see
  [Importing and exporting layouts](#importing-and-exporting-layouts).
- **Debug** — two diagnostic actions useful while developing or troubleshooting:
  "Move Focused Window → Left Half" (exercises the full window-move pipeline
  without a drag) and "Toggle Overlay Preview" (shows the zone overlay without
  needing to drag a window).
- **Settings…** — see [Settings](#settings).
- **Quit TilingGlass**.

### Snapping a window with the mouse

1. Start dragging a window by its title bar.
2. **While still dragging**, press and hold the activation modifier (**Control**
   by default). A translucent zone overlay appears on every screen, matching
   that screen's active layout.
3. Move the cursor — the zone under it highlights.
4. Release the mouse to snap the window into the highlighted zone (with your
   configured gaps applied).

Releasing the activation modifier before releasing the mouse cancels the
overlay with no effect — the window keeps moving normally.

> **Important:** hold the modifier *after* you've started dragging, not before
> — Control-clicking a title bar before the drag begins opens the window's
> context menu instead. This matches Tiling Shell's own behavior on Linux.

### Spanning multiple zones

While the overlay is showing, hold the span modifier (**Option** by default) in
addition to the activation modifier. The first zone you hover becomes an
anchor; moving to a different zone selects the rectangular span between the
anchor and the current zone, and releasing the mouse fills that whole area with
the window. Release the span modifier to go back to selecting a single zone.

Activation and span must be bound to different keys — the Settings picker
enforces this, since testing the same key for both would make single-zone
selection impossible.

### Keyboard tiling

With a window focused, the default shortcuts move it one zone at a time:

| Shortcut | Action |
|---|---|
| ⌘⌥← | Move to the zone on the left |
| ⌘⌥→ | Move to the zone on the right |
| ⌘⌥↑ | Move to the zone above |
| ⌘⌥↓ | Move to the zone below |

Reaching the edge of a screen in that direction crosses to the adjacent
monitor's nearest zone, so the same four shortcuts also handle multi-monitor
movement. All four are rebindable in Settings.

### Layouts

Four layouts ship built in:

| Layout | Description |
|---|---|
| **Equal split** | Two equal columns (left/right halves). |
| **Thirds** | Three equal columns. |
| **2x2 Grid** | Four equal quadrants. |
| **Focus** | A wide center column (50%) flanked by two narrower side columns (25% each) — good for a primary window with reference material on either side. |

Each screen has its own independent layout selection, picked from the menu bar.

### Creating and editing layouts

Menu bar → **New Layout…** opens the editor with a single full-screen zone;
**Edit Layout** → *(layout name)* opens an existing one. In the editor canvas:

- **Click** a zone to split it into left/right halves.
- **Option-click** to split it into top/bottom halves.
- **Right-click** for a context menu: split either way, or **Delete Zone**.
  A zone can only be deleted when a neighbor spans its entire shared edge (so
  the space merges back into a clean rectangle); the editor tells you when it
  can't.
- **Drag a shared edge** between zones to resize them against each other.
  Segments are independent — in a 2x2 grid, dragging the vertical mid-line in
  the top half moves only the top pair, so rows can split at different points.
- Name the layout and **Save**. Saving with a built-in layout's name overrides
  that built-in (a **Restore Built-in** button brings the original back);
  custom layouts get a **Delete Layout** button instead.

Zones can't shrink below 5% of the screen while dragging, and every save is
validated before it's persisted. Saved layouts get Tiling Shell-compatible
`groups` metadata recomputed from their geometry, so layouts built here have
working shared-edge resize when imported into Tiling Shell on Linux.

### Importing and exporting layouts

Layouts are stored as JSON, structurally identical to Tiling Shell's own export
format, so files move freely between the two apps:

```json
[
  {
    "id": "Equal split",
    "tiles": [
      { "x": 0, "y": 0, "width": 0.5, "height": 1, "groups": [1] },
      { "x": 0.5, "y": 0, "width": 0.5, "height": 1, "groups": [1] }
    ]
  }
]
```

- `x`, `y`, `width`, `height` are fractions of the screen (`0…1`), with the
  origin at the top-left.
- `groups` links tiles that share a resize edge (each shared edge segment gets
  an id; tiles list the segments they border). Imported values are round-
  tripped verbatim; the TilingGlass editor recomputes them from geometry on
  every save.
- **Import Layouts…** accepts either a JSON array of layouts (Tiling Shell's
  export shape) or a single bare layout object, so hand-written layouts work
  too.
- **Export Layouts…** writes every layout currently available — built-ins and
  imported — as a single array.

A ready-to-import example lives at
[`Examples/tilingshell-layouts.json`](Examples/tilingshell-layouts.json).

## Settings

Open via the menu bar → **Settings…**:

- **Activation** — which modifier reveals the zone overlay while dragging
  (Control, Option, Command, or Shift), and which modifier spans multiple
  zones. The span picker automatically excludes whatever's chosen for
  activation.
- **Gaps** — independent inner (0–48 pt, between adjacent zones) and outer
  (0–48 pt, zone to screen edge) spacing, both default to 8 pt.
- **Keyboard** — a recorder for each of the four directional shortcuts;
  click and type a new combination to rebind.
- **Launch at login** — registers TilingGlass as a login item via
  `SMAppService`.

## Architecture

Layered so the tiling logic is pure and exhaustively unit-tested, with a thin
AppKit/SwiftUI shell over the Accessibility API for the parts that touch live
windows.

| Layer | Location | Responsibility |
|---|---|---|
| `TilingCore` | `Packages/TilingCore` | Pure Swift, no AppKit: the layout model and Tiling Shell-compatible JSON codec, zone geometry (gap math), hit-testing (including multi-zone span selection), directional navigation for keyboard tiling, the layout-editing operations (split, merge, boundary dragging, `groups` recomputation), and the one place that converts between AppKit and Accessibility coordinate spaces. Fully covered by unit tests. |
| App shell | `TilingGlass/` | Menu bar, onboarding, the Accessibility window driver, drag input handling, the Liquid Glass overlay, the tiling engine that ties selection to window moves, hotkeys, and settings. |

Inside `TilingGlass/`:

| Directory | Contents |
|---|---|
| `App/` | App entry point and the composition root (`AppDelegate`) that wires everything together. |
| `MenuBar/` | The status-bar menu and the SwiftUI Settings window. |
| `Onboarding/` | First-run Accessibility permission flow. |
| `WindowDriver/` | The Accessibility API wrapper (`AccessibilityElement`), window move/resize logic (`WindowMover`), and screen enumeration / coordinate bridging (`ScreenService`). |
| `Input/` | Global mouse/modifier event monitoring (`DragMonitor`) and the drag → overlay → snap state machine (`DragCoordinator`). |
| `Editor/` | The visual layout editor window and canvas. |
| `Overlay/` | The per-screen Liquid Glass zone panels. |
| `Tiling/` | `TilingEngine` — turns a zone selection or a keyboard direction into an actual window move. |
| `Hotkeys/` | Global keyboard shortcut registration. |
| `Settings/` | Persisted settings (`SettingsStore`) and the layout catalogue (`LayoutStore`, built-ins + imports). |

### Design notes

- **No idle polling.** Mouse/modifier monitoring is entirely push-based
  (`NSEvent` global monitors); the only timer in the app is the onboarding
  permission poll, which starts when the onboarding window opens and stops the
  moment it closes.
- **A single coordinate-flip choke point.** AppKit (`NSScreen`, `NSWindow`) uses
  a bottom-left, y-up origin; the Accessibility API uses a top-left, y-down
  origin. Every conversion between the two goes through
  `TilingCore.CoordinateConversion`, which is exhaustively unit-tested — this
  is the class of bug (mirrored zone highlighting, windows landing in the
  wrong place) that's easiest to get subtly wrong in a project like this.
- **Layered for testability.** `TilingCore` has zero dependency on AppKit or
  the Accessibility API, so the geometry, hit-testing, JSON compatibility, and
  keyboard-navigation logic are covered by fast, deterministic unit tests. Only
  the thin app-shell layer touches live windows, and that can't be meaningfully
  unit-tested — see [Testing](#testing).

## Testing

```sh
swift test --package-path Packages/TilingCore
```

`TilingCore` is pure logic with no dependency on AppKit or the Accessibility
API, so it's fully covered by fast, deterministic `XCTest` unit tests: layout
JSON round-tripping (including a real Tiling Shell export fixture), gap
geometry, zone hit-testing and span selection, directional keyboard navigation
(including cross-monitor and asymmetric-layout cases), and the coordinate-space
conversion.

Everything that touches a live window — drag detection, the Accessibility API,
the overlay panels — can't be exercised headlessly: it needs a real, granted
Accessibility permission and an actual window to move.
[`docs/MANUAL-VERIFICATION.md`](docs/MANUAL-VERIFICATION.md) is a step-by-step
checklist for verifying that surface by hand after any change to the app
layer.

## Troubleshooting

**Windows stopped snapping / moving after I rebuilt the app.** The
Accessibility grant is tied to the app's code signature. If you're using the
one-off ad-hoc signing override from [Building](#installation--building), this
is expected on every rebuild — re-grant Accessibility. If you're using the
pinned identity in `project.yml` and it's your own, this shouldn't happen; if
it does, reset and re-grant:

```sh
tccutil reset Accessibility com.pedrolopes.tilingglass
```

**The overlay doesn't appear when I hold the activation key.** Make sure you
start dragging the window *first*, then press the modifier — pressing Control
before the drag starts opens a context menu instead (see
[Snapping a window with the mouse](#snapping-a-window-with-the-mouse)). Also
confirm Accessibility access is actually granted (menu bar → Debug → "Move
Focused Window → Left Half" is a quick way to check — if that doesn't move
anything, permission isn't granted).

**TilingGlass and macOS's native edge tiling fight each other.** Disable
"Drag windows to screen edges to tile" in System Settings → Desktop & Dock —
the onboarding flow offers a shortcut to that pane.

**A specific window won't move, or resists resizing.** Some apps (Electron,
Chromium-based apps, apps with an enforced minimum size) behave differently
under the Accessibility API. TilingGlass already works around the most common
case (`AXEnhancedUserInterface`); a window that reports back a different size
than requested still gets positioned at the correct top-left corner even if it
can't fully match the zone's dimensions.

**Build fails on someone else's machine with a signing error.** See
[Code signing (local dev)](#code-signing-local-dev) — the pinned identity is
machine-specific.

## Roadmap

Deferred from v0.1, but the architecture is built to accommodate them:

- Windows 11-style snap assistant (a picker that appears at the top of the
  screen on any drag, no modifier required)
- Screen-edge tiling (drag to an edge/corner without a modifier)
- Window suggestions to fill the remaining empty zones after a snap
- Smart resize — dragging the shared edge between two tiled windows resizes
  both
- Auto-tiling of newly created windows
- Per-workspace/Space layout selection
- A focused-window border

## Contributing

- `swift test --package-path Packages/TilingCore` must pass.
- `xcodebuild … build` must succeed with no new warnings.
- `.swiftformat` / `.swiftlint.yml` configs are checked in; run them if you
  have the tools installed.
- CI (`.github/workflows/tilingcore-tests.yml`) runs the `TilingCore` suite on
  every push/PR that touches it.
- For anything that changes app-layer (Accessibility/drag/overlay) behavior,
  walk through [`docs/MANUAL-VERIFICATION.md`](docs/MANUAL-VERIFICATION.md)
  before considering it done — that layer has no automated coverage.

## Permissions & privacy

TilingGlass needs **Accessibility** access (System Settings → Privacy &
Security → Accessibility) to read and set the position/size of other apps'
windows — there's no other public API for this on macOS. It cannot be
sandboxed or distributed via the App Store: the App Sandbox required for App
Store distribution is fundamentally incompatible with the Accessibility API
(the permission prompt never appears, and `AXIsProcessTrusted()` always returns
false, under sandboxing). This is the same model used by Rectangle, Loop,
AeroSpace, and every other third-party macOS window manager.

TilingGlass makes no network requests, collects no data, and reads no window
*content* — only window frames (position and size) and window/app identity
(for tracking which zone a window occupies), which never leave the machine.

## License

GPL-3.0. See [LICENSE](LICENSE). Ports concepts and layout-format compatibility
from [Tiling Shell](https://github.com/domferr/tilingshell) (GPL-3.0);
low-level Accessibility API patterns are informed by
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT). Global keyboard
shortcuts use [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
(MIT).
