# Alfred

A native macOS **menu-bar valet** that reclaims disk space from
safe-to-delete developer cruft.

Click the menu-bar icon and a native popover drops down with
everything Alfred found — `node_modules`, Cargo `target/`, Next/
Vite/Turbo/Parcel caches, Python & test caches, Xcode DerivedData,
npm/Go/Gradle/Cargo package caches — grouped, sized, biggest wins
first. Select what you want gone and Alfred moves it to the Trash
(recoverable) or deletes it. No Dock icon, no windows: it lives in
the menu bar, like Port and the rest of the suite.

Swift + SwiftUI, `NSStatusItem` + transient `NSPopover`,
`.accessory` activation. Zero third-party dependencies.

## Why it's safe

This tool deletes things, so it's conservative by construction:

- **Sibling-gated** — `target/` only counts next to `Cargo.toml`,
  `node_modules/` next to `package.json`, etc. It only ever flags
  genuinely regenerable artifacts.
- **Confidence tiers** — pure caches are on by default; heavier or
  occasionally-kept dirs (virtualenvs, `Pods/`, bare `dist/`,
  Xcode Archives) are opt-in.
- **Trash, not `rm`** — recoverable by default (toggleable).
- **Re-validated at delete time** — every path is checked against
  the catalog before removal, so a stale selection can't turn
  Alfred into an arbitrary `rm`.
- Symlinks are never followed; system / `Library` / VCS dirs are
  pruned from the walk.

## Build & run

```
swift build
swift run                 # menu-bar item appears; no Dock icon
bash scripts/make-app.sh  # assembles + signs Alfred.app
open Alfred.app
```

See `CLAUDE.md` for architecture.
