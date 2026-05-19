import AppKit
import ObjectiveC

/// Alfred's glyphs + resource resolver, relocated out of the thin
/// `Alfred` shim so the pane (what the launcher loads) and the
/// standalone app share one source. Avoids SwiftPM's `Bundle.module`
/// (it `fatalError`s for a dlopen'd pane); SF Symbol fallback.
enum AlfredBrand {
    private final class BundleToken {}

    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        // 1. Host main bundle: standalone .app (PNGs flattened into
        //    Contents/Resources) or dev `swift run`.
        if let u = Bundle.main.url(forResource: name, withExtension: ext) {
            return u
        }
        // 2. Relative to THIS pane dylib's REAL path. `Bundle(for:)`
        //    is unreliable for a dlopen'd loose dylib (it hands back
        //    the host launcher's main bundle, so merged mode missed
        //    and fell back to the SF glyph). Ask the dynamic linker
        //    where the class's image actually lives.
        if let img = class_getImageName(BundleToken.self) {
            let dylib = URL(fileURLWithPath: String(cString: img))
            let fw = dylib.deletingLastPathComponent()   // …/Frameworks (app) or .build/<cfg> (dev)
            // SwiftPM resource bundle beside the dylib (dev/build).
            if let b = Bundle(url: fw.appendingPathComponent(
                    "Alfred_AlfredPane.bundle")),
               let u = b.url(forResource: name, withExtension: ext) {
                return u
            }
            // Installed app layout: Frameworks/../Resources.
            let res = fw.deletingLastPathComponent()
                .appendingPathComponent("Resources/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: res.path) {
                return res
            }
            // Same dir as the dylib (last resort).
            let same = fw.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: same.path) {
                return same
            }
        }
        // 3. Final fallback.
        return Bundle(for: BundleToken.self)
            .url(forResource: name, withExtension: ext)
    }

    /// Status-bar glyph (white broom), template, ~18pt tall.
    static let menuBarIcon: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(systemSymbolName: "sparkles",
                            accessibilityDescription: "Alfred")
                ?? NSImage()
        }
        let height: CGFloat = 18
        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: height * aspect, height: height)
        image.isTemplate = true
        return image
    }()

    /// Panel-header glyph (tinted by the accent).
    static let trayGlyph: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(systemSymbolName: "sparkles",
                            accessibilityDescription: "Alfred")
                ?? NSImage()
        }
        image.isTemplate = true
        return image
    }()

    /// Full-colour app icon for in-app branding.
    static let appIcon: NSImage = {
        if let url = resourceURL("AppIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            return loaded
        }
        return NSImage(systemSymbolName: "sparkles",
                       accessibilityDescription: "Alfred") ?? NSImage()
    }()
}
