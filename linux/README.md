# Alfred (Linux)

Linux-native sibling of the macOS Swift build at the repo root. Same
product name and version as the Mac build, **separate native
binary**. Alfred is the most "portable" app in the suite — its
core (finding deletable dev cruft and Trashing it) is essentially
the same algorithm everywhere; only the UI and Trash plumbing
change.

## Status

**Scaffold only.** macOS is the current shipping artifact; Linux
work lands here incrementally.

## Stack

| Layer        | Choice                                                            |
| ------------ | ----------------------------------------------------------------- |
| Language     | Rust (2021)                                                       |
| Walker       | [`ignore`](https://docs.rs/ignore) (parallel, respects `.gitignore`-style rules; same crate ripgrep uses) |
| Sizing       | `std::fs::metadata` + atomic accumulator                          |
| Trash        | [`trash`](https://docs.rs/trash) crate (XDG `~/.local/share/Trash`) — same crate works on Wayland & X11 |
| Tray         | [`ksni`](https://docs.rs/ksni)                                    |
| Panel UI     | GTK4 with `gtk4-rs`                                               |
| Packaging    | `.deb` · `.rpm` · Flatpak (`org.mattssoftware.Alfred`)            |

## What translates 1:1

- **Project catalog** (sibling-manifest detection, e.g. "kill `node_modules` only when there's a `package.json` next to it") — pure logic, ports as-is from `Categories.swift`.
- **Sibling-gated `isCleanable`** safety check — pure logic.
- **System / Library / VCS pruning** — same rules; just different absolute paths (Linux has no `/Library`, but we already prune by name).

## What's different

| Concern              | Mac (current)                                 | Linux                                                  |
| -------------------- | --------------------------------------------- | ------------------------------------------------------ |
| Dev roots default    | `~/Development`                               | `~/Development` + `$XDG_DATA_HOME/repos` if present   |
| Per-language caches  | `~/Library/Developer/Xcode/DerivedData`, etc. | `~/.cargo/registry/cache`, `~/.cache/pip`, `~/.npm/_cacache`, `~/go/pkg/mod`, `~/.gradle/caches`, `~/.m2/repository`, `~/.cache/yarn`, `~/.cache/pnpm/store`, `~/.local/share/JetBrains/IntelliJIdea*/caches`, etc. |
| Xcode DerivedData    | exists                                        | n/a — drop from the Linux catalog                      |
| Trash                | `FileManager.trashItem`                       | XDG Trash spec via `trash` crate (`gio trash`-compatible) |
| Tray                 | `NSStatusItem`                                | `ksni`                                                 |

## Honest ceilings

- **Trash quirks**: removable volumes use per-volume `.Trash-1000` dirs. The `trash` crate handles this, but verify on USB drives.
- **Wayland tray**: GNOME needs AppIndicator extension; KDE / Sway / XFCE / Cinnamon work out of the box.
- **Symlink discipline**: same as Mac — never follow symlinks during the walk.

## Roadmap

1. Core walker + project catalog port (no UI). CLI: `alfred scan`, `alfred clean --dry-run`.
2. `ksni` tray with the same "reclaimable" hero as Mac.
3. GTK4 panel: grouped result list, per-row reveal, in-panel confirm.
4. Trash plumbing + a real-life regression-test pass on /tmp fixtures.
5. Packaging in CI alongside the Mac `.dmg`.
