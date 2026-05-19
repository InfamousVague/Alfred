import SwiftUI
import AppKit
import AlfredPane
import SuiteKit

// Standalone Alfred. Post-split this is just a host shim — the
// scanner, catalog, store and UI live in `AlfredPane` so the
// MattsSoftware launcher can load the same code out of an installed
// Alfred.app. Behaviour unchanged.
@main
struct AlfredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate,
    NSPopoverDelegate
{
    private let pane = AlfredPaneProvider()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SuiteGuard.exitIfDeferring("alfred")

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = pane.paneMenuBarImage()
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "Alfred — reclaim dev disk space"
        }

        let vc = NSViewController()
        vc.view = pane.paneMakeView()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = vc

        pane.paneStart()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender) }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button,
                     preferredEdge: .minY)
        if let win = popover.contentViewController?.view.window {
            clampOnScreen(win, anchoredTo: button)
            win.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in self?.popover.performClose(nil) }
        pane.paneDidOpen()  // first open kicks the initial scan
    }

    private func clampOnScreen(_ win: NSWindow, anchoredTo anchor: NSView) {
        guard let screen = anchor.window?.screen ?? NSScreen.main
        else { return }
        let vis = screen.visibleFrame
        let pad: CGFloat = 8
        var f = win.frame
        if f.maxX > vis.maxX - pad { f.origin.x = vis.maxX - pad - f.width }
        if f.minX < vis.minX + pad { f.origin.x = vis.minX + pad }
        if f.minY < vis.minY + pad { f.origin.y = vis.minY + pad }
        if f != win.frame { win.setFrame(f, display: true) }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m); clickMonitor = nil
        }
    }

    /// `alfred://` deep link (e.g. opened from Stats' disk panel).
    func application(_ application: NSApplication, open urls: [URL]) {
        showPopover()
    }
}
