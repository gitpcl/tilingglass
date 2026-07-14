# Manual verification checklist

Most of TilingGlass's logic is covered by the `TilingCore` unit tests
(`swift test --package-path Packages/TilingCore`). The parts that touch live
windows go through the macOS Accessibility API, which **cannot** run without a
user-granted permission and a real window to move — so they must be verified by
hand. This checklist walks through it.

## First run

1. Build and launch:
   ```sh
   xcodegen generate
   xcodebuild -project TilingGlass.xcodeproj -scheme TilingGlass \
     -configuration Debug -derivedDataPath build build
   open build/Build/Products/Debug/TilingGlass.app
   ```
2. The onboarding window appears. Click **Open Accessibility Settings** and
   enable **TilingGlass** under System Settings › Privacy & Security ›
   Accessibility.
3. The onboarding checkmark should flip to “Accessibility access granted” within
   a second. Click **Done**.
4. Optional: click **Open Desktop & Dock** and turn off “Drag windows to screen
   edges to tile” so macOS's native tiling doesn't fight TilingGlass.

The menu-bar icon (▦) should be present. Its menu lists the layout picker per
screen, Import/Export, a Debug section, Settings, and Quit.

## Core AX pipeline (the Phase 2 gate)

5. Focus any normal window (Finder, Safari, Terminal).
6. Menu-bar icon › **Debug › Move Focused Window → Left Half**.
   - ✅ The window snaps to the left half of its screen, below the menu bar,
     with the configured outer gap.
   - Check `Console.app` (filter “TilingGlass”) for a line like
     `moveFocusedToLeftHalf on <screen> → full`.

If this works, the Accessibility + coordinate-flip foundation is correct.

## Glass overlay (Phase 4)

7. Menu-bar icon › **Debug › Toggle Overlay Preview**.
   - ✅ Translucent Liquid Glass zones appear over each screen's usable area,
     matching the selected layout, with the first zone accent-tinted.
   - Toggle again to dismiss.
   - Note: if the glass looks like a flat blur rather than true Liquid Glass,
     that's the known “inactive non-activating panel” degradation — the zone
     borders still make zones legible. Flag it if it looks wrong.

## Tiling system (Phase 5)

8. Start dragging a window's title bar. **While still dragging**, press and hold
   **Control** (the activation modifier).
   - ✅ Zone overlay appears on all screens.
9. Move the cursor over different zones.
   - ✅ The zone under the cursor highlights (accent tint), following across
     monitors. Only one zone highlights at a time.
10. Release the mouse over a zone.
    - ✅ The window resizes/moves to fill that zone (with gaps).
11. Repeat, and this time also hold **Option** (span modifier) while hovering.
    - ✅ Dragging from one zone to another selects the rectangular span of zones
      between them; releasing fills the combined area.
12. Release Control mid-drag.
    - ✅ The overlay disappears; no window move happens if you then release the
      mouse.

## Keyboard tiling (Phase 6)

13. Focus a window. Press **⌘⌥←**, **⌘⌥→**, **⌘⌥↑**, **⌘⌥↓**.
    - ✅ The window moves to the neighbouring zone in that direction.
    - ✅ At a screen edge, it crosses to the adjacent monitor's entering zone.
14. Settings › Keyboard: rebind a shortcut with the recorder, confirm the new
    binding works.
15. Settings › Launch at login: toggle on, confirm it appears in System
    Settings › General › Login Items.

## Layout editor

The editing math (splits, merges, boundary clamping, groups) is unit-tested in
TilingCore; this checklist covers the interactive canvas.

E1. Menu-bar icon › **New Layout…** — the editor opens with one full-screen
    zone and an empty name field; Save is disabled until a name is entered.
E2. Click the zone — it splits into left/right halves. Option-click one half —
    it splits into top/bottom. Right-click a zone — the context menu offers
    Split Horizontally / Split Vertically / Delete Zone.
E3. Delete a zone that has a clean neighbor — the neighbor absorbs the space.
    Build an arrangement where no neighbor spans the zone's full edge (e.g.
    split one side twice) and delete the large zone — an inline error appears
    and the layout is unchanged.
E4. Drag the shared edge between two zones — both resize live and stop at the
    5% minimum. In a 2x2 arrangement, drag the vertical mid-line in the top
    half — only the top pair moves.
E5. Name it and Save — it appears in the menu's layout list and in the
    **Edit Layout** submenu; select it on a screen and ⌃-drag a window —
    the overlay shows the new zones.
E6. Menu › **Edit Layout › Equal split** (a built-in), change something, Save —
    the built-in is overridden. Re-open it — a **Restore Built-in** button
    appears; clicking it restores the original.
E7. Export layouts — the saved custom layout is in the JSON with non-empty
    `groups`; re-import the file — no errors, layout unchanged.
E8. Quit and relaunch — custom layouts and per-screen selections persist.

## Multi-monitor & robustness (Phase 7)

16. With two displays, assign different layouts per screen (menu shows a section
    per screen). Confirm overlays and drops respect each screen's own layout and
    gaps, including on a display with a different scale factor.
17. Change display arrangement/resolution while the app runs — the next drag
    should rebuild overlays against the new arrangement (no stale panels).
18. Idle CPU: with no drag in progress, TilingGlass should sit at ~0% CPU in
    Activity Monitor (it uses push-based event monitors, no polling).
19. Try a minimum-size app (e.g. Activity Monitor) — it should still move; if it
    can't shrink to the zone it keeps its top-left corner and logs `→ partial`.
20. Try an Electron app (VS Code) — it should move (the app clears
    `AXEnhancedUserInterface` around the move to allow it).

## If Accessibility stops working after a rebuild

The dev signing identity is pinned in `project.yml` to keep the grant sticky. If
it still resets:

```sh
tccutil reset Accessibility com.pedrolopes.tilingglass
```

then re-grant.
