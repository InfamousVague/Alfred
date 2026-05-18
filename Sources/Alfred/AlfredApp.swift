import SwiftUI
import AppKit

@main
struct AlfredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Accessory app: the real UI is the NSStatusItem/NSPopover the
        // delegate manages. This scene stays empty/never shown — same
        // shape as Port and the rest of the menu-bar apps.
        Settings { EmptyView() }
    }

    /// Resolve a bundled resource: Bundle.main (signed .app, flattened
    /// into Contents/Resources) first, then Bundle.module (dev
    /// `swift run`).
    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    /// White broom glyph, set as a template so macOS tints it for the
    /// active menu-bar appearance (dark on light bars, light on dark).
    static let menuBarIcon: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(
                systemSymbolName: "sparkles",
                accessibilityDescription: "Alfred"
            ) ?? NSImage()
        }
        let height: CGFloat = 15
        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: height * aspect, height: height)
        image.isTemplate = true
        return image
    }()

    /// The same glyph at full resolution, kept as a template so
    /// SwiftUI `.foregroundStyle(...)` can tint it cleanly in the
    /// panel header — the way Espresso renders its cup glyph in the
    /// crema accent. (Distinct from `menuBarIcon`, which is
    /// downscaled to ~15pt for the status bar.)
    static let trayGlyph: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(
                systemSymbolName: "sparkles",
                accessibilityDescription: "Alfred"
            ) ?? NSImage()
        }
        image.isTemplate = true
        return image
    }()

    /// Full-color app icon, for in-app branding.
    static let appIcon: NSImage = {
        if let url = resourceURL("AppIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            return loaded
        }
        return NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Alfred"
        ) ?? NSImage()
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AlfredStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        if let button = statusItem.button {
            button.image = AlfredApp.menuBarIcon
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "Alfred — reclaim dev disk space"
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environment(store)
        )

        store.bootstrap()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        NSApp.activate(ignoringOtherApps: true)
        // First open kicks the initial scan — opening a menu-bar
        // cleaner should immediately start showing what it found.
        store.scanIfNeeded()
    }
}
