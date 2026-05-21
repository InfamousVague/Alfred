//! Linux build of Alfred. Scaffold only — see ../README.md for the
//! per-language cache map and the implementation plan.
//!
//! Real version: port `Categories.swift` (project rules +
//! `isCleanable` safety check) as pure Rust, walk with `ignore`,
//! Trash via the `trash` crate, surface in a `ksni` tray + GTK4
//! panel matching the macOS layout.

fn main() {
    eprintln!(
        "alfred (linux): scaffold only — see linux/README.md for \
         the implementation plan."
    );
    std::process::exit(0);
}
