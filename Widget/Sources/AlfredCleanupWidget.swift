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
                // Required for the desktop widget background on
                // macOS 14+ — without this the widget paints over
                // the wallpaper with no card, looking broken.
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Alfred Cleanup")
        .description("Reclaimable disk space and one-click cleanup.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

/// View dispatch — the body switches on the widget family so each
/// size gets its own purpose-built layout rather than a stretched
/// one-size-fits-all design.
struct AlfredWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlfredEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}
