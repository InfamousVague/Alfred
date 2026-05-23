import WidgetKit
import SwiftUI
import AlfredShared

/// The one widget Alfred ships: "Cleanup", available in small + medium.
/// Small = reclaimable headline + last-freed line. Medium = adds top-3
/// category breakdown + total item count. Both carry interactive
/// Scan / Clean buttons backed by the AppIntents in `AlfredShared`.
struct AlfredCleanupWidget: Widget {
    let kind: String = "AlfredCleanupWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlfredProvider()) { entry in
            AlfredWidgetView(entry: entry)
                // Force `.accented` in our SwiftUI subtree so any
                // adaptive code (button style switches, image
                // rendering, etc.) reads the same mode whether the
                // widget is focused or dimmed. The system still owns
                // the actual compositor-level dim plate (controlled
                // by System Settings → Desktop & Dock → Widgets →
                // "Dim widgets on Desktop"), but this keeps our
                // *view layer* visually consistent across states —
                // the user prefers the dimmed glass look everywhere.
                .environment(\.widgetRenderingMode, .accented)
                // `Color("WidgetBackground")` from the asset catalog,
                // not `.fill.tertiary` or a Material. This is the
                // documented Apple-blessed pattern: the named opaque
                // colour is what the widget gallery picker shows, and
                // it's the surface the macOS Tahoe WindowServer
                // *replaces* with its Liquid Glass plate when the
                // widget sits on the desktop — the glass effect lives
                // in the compositor, not in the widget's view tree.
                //
                // Earlier attempts that all failed to produce glass:
                //   • `.fill.tertiary`     → opaque dark ShapeStyle
                //                            (just a fill, no plate)
                //   • `Color.clear`        → plate IS there, but very
                //                            subtle; reads as black
                //                            on dark wallpapers
                //   • `.regularMaterial`   → Material has nothing to
                //                            blur (widgets render off-
                //                            screen, composited)
                //   • omitted entirely     → falls back to legacy
                //                            opaque chrome, no plate
                //
                // The named colour gives the system something concrete
                // to swap for the Liquid Glass plate, and works in the
                // Clear/Tinted appearance modes too.
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .configurationDisplayName("Alfred Cleanup")
        .description("Reclaimable disk space and one-click cleanup.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// View dispatch — the body switches on the widget family so each
/// size gets its own purpose-built layout rather than a stretched
/// one-size-fits-all design.
struct AlfredWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlfredEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            default:            SmallView(entry: entry)
            }
        }
        // Desktop-widget tap target. Without this URL hook the
        // tap launches Alfred's standalone bundle id, SuiteGuard
        // detects merged-mode + exits, and the user sees nothing.
        // The MattsSoftware launcher owns the `mattssoftware://`
        // scheme and routes the host segment to the right pane.
        .widgetURL(URL(string: "mattssoftware://alfred"))
    }
}
