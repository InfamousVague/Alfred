import WidgetKit
import AlfredShared
import Foundation

/// One timeline entry — what gets handed to the SwiftUI view at
/// each refresh. We don't model multiple future entries because
/// nothing in the data changes on a schedule; the host calls
/// `WidgetCenter.reloadAllTimelines()` whenever it actually has
/// new stats, and the policy below is just a heartbeat fallback.
struct AlfredEntry: TimelineEntry {
    let date: Date
    let stats: SharedStats
}

struct AlfredProvider: TimelineProvider {
    /// Shown in the widget gallery preview. Synthetic — no I/O.
    func placeholder(in context: Context) -> AlfredEntry {
        AlfredEntry(date: Date(), stats: .placeholder)
    }

    /// Snapshot for transient previews (e.g., gallery while the user
    /// scrolls families). Read the real on-disk stats if we can; fall
    /// back to the placeholder otherwise.
    func getSnapshot(in context: Context, completion: @escaping (AlfredEntry) -> Void) {
        let s = StatsStore.read() ?? .placeholder
        completion(AlfredEntry(date: Date(), stats: s))
    }

    /// Timeline. One current entry, refreshed every 15 minutes as a
    /// safety net — the host reloads us immediately whenever scan or
    /// clean finishes, so the heartbeat almost never matters.
    func getTimeline(in context: Context, completion: @escaping (Timeline<AlfredEntry>) -> Void) {
        let s = StatsStore.read() ?? .placeholder
        let entry = AlfredEntry(date: Date(), stats: s)
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
