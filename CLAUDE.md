# alfred (native)

Native macOS menu-bar valet. Scans your dev roots + known global
tool-cache locations for safe-to-delete cruft (`node_modules`, Cargo
`target/`, build/test caches, Xcode DerivedData, package-manager
caches), sizes it, and reclaims the space — to the Trash by default,
so it's recoverable. Swift + SwiftUI in a transient `NSPopover` off
an `NSStatusItem`, `.accessory` activation (no Dock icon). No
third-party dependencies. Same shape as `port-swift`.

## Architecture

- `Sources/Alfred/AlfredApp.swift` — `@main` SwiftUI app with an
  `NSApplicationDelegateAdaptor`; the real UI is the `NSStatusItem`
  + transient `NSPopover` the `AppDelegate` manages. `.accessory`
  activation; template menu-bar icon.
- `Sources/Alfred/Models.swift` — `AppSettings` (Codable, persisted
  to Application Support) + `AlfredStore` (`@Observable`,
  `@MainActor`): scan/clean state machine. `CancelToken` bridges the
  detached scan task and the main-actor store.
- `Sources/Alfred/Categories.swift` — the catalog: project rules
  (dir name + sibling-manifest gate + confidence/scope) and global
  cache rules. Also the `isCleanable` delete guard.
- `Sources/Alfred/Scanner.swift` — pure `FileManager` walk + sizing
  + Trash (`trashItem`) / permanent (`removeItem`) deletion +
  reveal-in-Finder. No subprocess.
- `Sources/Alfred/ContentView.swift` — the menu-bar panel
  (header / reclaimable hero / grouped result list / footer +
  in-panel confirm).
- `Sources/Alfred/SettingsView.swift` — the settings sheet (roots,
  category toggles, Trash-vs-delete, min size, appearance).

## Safety

It deletes things, so every layer fails safe: sibling-gated project
matches (only ever flags regenerable artifacts), opt-in "review"
tier (venvs / Pods / bare dist), Trash by default, a delete-time
re-validation against the catalog (`Catalog.isCleanable`), no
symlink following, system/Library/VCS pruned from the walk.

## Icons

- `art/AppIcon-source.png` — app icon source. `scripts/make-app.sh`
  turns it into `AppIcon.icns` via `sips`/`iconutil`.
- `Sources/Alfred/Resources/MenuBarIcon.png` — white broom+sparkle
  glyph, used as a template `NSStatusItem` image (macOS tints it).
- `Sources/Alfred/Resources/AppIcon.png` — full-colour in-app icon.

Regenerate all three (dependency-free, stdlib only — no PIL):

```
python3 scripts/gen_icons.py
```

## Running

```
swift build
swift run                 # menu-bar item appears; no Dock icon
bash scripts/make-app.sh  # assembles Alfred.app (LSUIElement), signed
open Alfred.app           # run the bundled menu-bar agent
```

`SKIP_DMG=1` skips the .dmg; `SIGN_IDENTITY=-` forces ad-hoc signing.
