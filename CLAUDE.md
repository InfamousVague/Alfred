# alfred (native)

Native macOS menu-bar valet. Scans your dev roots + known global
tool-cache locations for safe-to-delete cruft (`node_modules`, Cargo
`target/`, build/test caches, Xcode DerivedData, package-manager
caches), sizes it, and reclaims the space — to the Trash by default,
so it's recoverable. Swift + SwiftUI in a transient `NSPopover` off
an `NSStatusItem`, `.accessory` activation (no Dock icon).

Post-split, Alfred is a **SuiteKit pane**: the scanner / catalog /
store / UI live in a dynamic library so the MattsSoftware launcher
can host the same code out of an installed `Alfred.app`. Same shape
as `port-swift`; depends only on `SuiteKit` (`../suitekit-swift`).

## Architecture

`Package.swift` ships two products, both linking `SuiteKit`:

- **`AlfredPane`** — a `.dynamic` library (`libAlfredPane.dylib`).
  ALL the real code lives here:
  - `Sources/AlfredPane/Plugin.swift` — the SuiteKit ABI seam
    (`@_cdecl("suitePaneCreate")`) exposing `AlfredPaneProvider`
    (`paneMenuBarImage` / `paneMakeView` / `paneStart` /
    `paneDidOpen`).
  - `Models.swift` — `AppSettings` (Codable, persisted to
    Application Support) + `AlfredStore` (`@Observable`,
    `@MainActor`) scan/clean state machine; `CancelToken` bridges
    the detached scan task to the main actor.
  - `Categories.swift` — the catalog (project rules: dir name +
    sibling-manifest gate + confidence/scope; global cache rules)
    and the `Catalog.isCleanable` delete guard.
  - `Scanner.swift` — pure `FileManager` walk + sizing + Trash
    (`trashItem`) / permanent (`removeItem`) + reveal-in-Finder.
  - `ContentView.swift` — the panel (header / reclaimable hero /
    grouped result list / footer + in-panel confirm). Brand tint
    via `Color.alfredAccent`.
  - `SettingsView.swift` — settings sheet (roots, category
    toggles, Trash-vs-delete, min size, appearance).
  - `Brand.swift` — `AlfredBrand` (tray-glyph / app-icon
    `NSImage`s). `GlassScroller.swift`, `PaddedCount.swift` — UI
    helpers.
- **`Alfred`** — a thin standalone host shim
  (`Sources/Alfred/AlfredApp.swift`). `@main`; its `AppDelegate`
  builds the `NSStatusItem` + transient `NSPopover` but pulls the
  icon/view/logic from `AlfredPaneProvider`. First line of
  `applicationDidFinishLaunching` is
  `SuiteGuard.exitIfDeferring("alfred")` — see Dev workflow.

## Safety

It deletes things, so every layer fails safe: sibling-gated project
matches (only ever flags regenerable artifacts), opt-in "review"
tier (venvs / Pods / bare dist), Trash by default, a delete-time
re-validation against the catalog (`Catalog.isCleanable`), no
symlink following, system/Library/VCS pruned from the walk.

## Icons

- `art/AppIcon-source.png` — Finder/Dock icon source.
  `scripts/make-app.sh` turns it into `AppIcon.icns` via
  `sips`/`iconutil`.
- `Sources/AlfredPane/Resources/MenuBarIcon.png` — the white
  butler-tuxedo glyph; used as a template `NSStatusItem` image AND
  (tinted in `alfredAccent`) as the panel-header mark. **Keep it
  tightly cropped, aspect-preserved — never squared/padded**, or it
  renders tiny-with-whitespace in the 18pt status bar.
- `Sources/AlfredPane/Resources/AppIcon.png` — full-colour in-app
  icon.

`scripts/gen_icons.py` is a dependency-free (stdlib-only) fallback
generator; current shipped icons are supplied art, not gen output.

## Dev workflow — IMPORTANT

Alfred normally runs **inside the MattsSoftware launcher**, not
standalone. Two facts make the naive "rebuild + open Alfred.app"
loop look broken when it isn't:

1. `SuiteGuard.exitIfDeferring("alfred")` — when the launcher is
   installed/hosting the `alfred` pane, the standalone `Alfred.app`
   **exits 0 immediately, by design** (no double menu-bar icon).
   Exit-0-with-no-output here is expected, not a crash.
2. The launcher (`/Applications/MattsSoftware.app`) `dlopen`s
   `libAlfredPane.dylib` from `/Applications/Alfred.app` and
   **caches it for its process lifetime** — a rebuilt pane is not
   hot-swapped.

So **"relaunch Alfred" = "restart the MattsSoftware launcher"**.
The edit → see loop:

```
# 1. Edit Sources/AlfredPane/*  (Sources/Alfred/ is just the shim)
# 2. Rebuild + bundle + sign + notarize:
bash scripts/make-app.sh            # SKIP_DMG=1 to skip the .dmg
# 3. Reinstall the pane host:
rm -rf /Applications/Alfred.app && ditto Alfred.app /Applications/Alfred.app
# 4. Restart the host so it re-dlopens the fresh pane:
pkill -x MattsSoftwareMenuBar; open /Applications/MattsSoftware.app
```

To iterate on Alfred **truly standalone** (faster, no notarize):
quit the launcher first so deferral is inactive, then
`swift run` / `open Alfred.app` behaves like a normal menu-bar app.

`scripts/make-app.sh`: builds `-c release`, copies `libSuiteKit`
+ `libAlfredPane` into `Contents/Frameworks` (+ `@executable_path/
../Frameworks` rpath), codesigns inside-out, then **notarizes +
staples** the `.app` for Developer-ID builds. Knobs: `SKIP_DMG=1`,
`SIGN_IDENTITY=-` (ad-hoc, skips notarization).
