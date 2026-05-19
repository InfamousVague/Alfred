import AppKit
import SwiftUI
import SuiteKit

/// Alfred as a SuiteKit pane. Owns the store, vends the cleaner UI +
/// glyph. No notifications; scanning is bootstrap + on-demand.
@MainActor
public final class AlfredPaneProvider: NSObject, SuitePane {
    private let store = AlfredStore()

    public var suiteABIVersion: Int { SuiteKitABI.current }
    public var paneID: String { "alfred" }
    public var paneTitle: String { "ALFRED" }
    public var paneTintHex: String { "#758FDB" }

    public func paneMenuBarImage() -> NSImage { AlfredBrand.menuBarIcon }

    public func paneMakeView() -> NSView {
        NSHostingView(rootView: ContentView().environment(store))
    }

    public func paneStart() {
        store.bootstrap()
        // Merged mode has no "popover open" hook to kick the first
        // scan, so do it once on load (mirrors standalone's
        // open-the-popover behaviour).
        store.scanIfNeeded()
    }

    public func paneStop() {}

    /// Standalone parity: the shim calls this when its popover opens
    /// so reopening re-checks for new cruft.
    public func paneDidOpen() { store.scanIfNeeded() }
}

@_cdecl("suitePaneCreate")
public func suitePaneCreate() -> Unmanaged<AnyObject> {
    MainActor.assumeIsolated {
        Unmanaged.passRetained(AlfredPaneProvider())
    }
}
