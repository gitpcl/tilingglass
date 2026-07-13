# TilingGlass

A macOS port of the GNOME [Tiling Shell](https://github.com/domferr/tilingshell)
extension: FancyZones-style custom tiling layouts with a Liquid Glass overlay.

Drag a window while holding a modifier key to reveal your layout's zones, then
drop the window into one. Hold a second modifier to span several zones. Move
windows between zones and across monitors with the keyboard. Layouts are
compatible with Tiling Shell's JSON import/export format.

> **Status:** early development (v0.1). macOS 26 Tahoe or later.

## Features (v0.1 target)

- Menu-bar app with a per-screen layout picker
- Custom tiling layouts, compatible with Tiling Shell's JSON format
- Four built-in layouts (Equal split, Thirds, 2×2 Grid, Focus)
- Tiling system: hold a modifier while dragging to show zones and snap into them
- Span multiple adjacent zones with a second modifier
- Keyboard tiling: move the focused window between zones and across monitors
- Multi-monitor support with configurable gaps
- Liquid Glass zone overlay

## Architecture

Layered so the tiling logic is pure and unit-testable, with a thin AppKit/SwiftUI
shell over the Accessibility API for the parts that touch live windows.

| Layer | Location | Notes |
|-------|----------|-------|
| `TilingCore` | `Packages/TilingCore` | Pure Swift: layout model, JSON codec, zone geometry, hit-testing, directional navigation, coordinate conversion. No AppKit. 100% unit-tested. |
| App shell | `TilingGlass/` | Menu bar, onboarding, Accessibility window driver, drag input, glass overlay, tiling engine, settings. |

## Building

Requires macOS 26+, Xcode 26+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project TilingGlass.xcodeproj -scheme TilingGlass \
  -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/TilingGlass.app
```

Run the core unit tests:

```sh
swift test --package-path Packages/TilingCore
```

### Code signing (local dev)

`project.yml` pins a code-signing identity by SHA-1 so the Accessibility
permission survives rebuilds (an ad-hoc signature changes each build and resets
the grant). Replace the hash with one of your own:

```sh
security find-identity -v -p codesigning
```

If the Accessibility grant ever gets wedged during development:

```sh
tccutil reset Accessibility com.pedrolopes.tilingglass
```

## Permissions

TilingGlass needs **Accessibility** access (System Settings → Privacy &
Security → Accessibility) to move and resize windows. It cannot be sandboxed or
distributed via the App Store — this is inherent to the Accessibility API and is
the same model Rectangle and other window managers use.

## License

GPL-3.0. See [LICENSE](LICENSE). Ports concepts and layout-format compatibility
from Tiling Shell (GPL-3.0); low-level Accessibility patterns are informed by
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT).
