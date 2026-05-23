import SwiftUI
import WidgetKit
import AlfredShared

/// `.systemSmall` Alfred layout. Mirrors the Stats / Port / Quarantine
/// chrome: tracked "ALFRED" caps brand row at the top, hero
/// reclaimable-bytes number centred in the tile, a one-line headline,
/// optional "freed N · Mm ago" subline, and a primary Scan button
/// pinned to the bottom edge. No SF Symbol next to the brand — the
/// family convention is text-only caps brand.
struct SmallView: View {
    let entry: AlfredEntry

    var body: some View {
        VStack(spacing: 4) {
            // `widgetAccentable()` opts this row into the accent
            // group when the user picks the "Tinted" or "Clear"
            // Icon & widget style — the system tints these texts
            // and leaves the hero number in the primary group. The
            // hero gets the white "primary" rendering; the brand
            // row + sublines get the user's accent.
            Text("ALFRED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Spacer(minLength: 0)

            Text(fmtBytes(entry.stats.totalBytes))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(headline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .widgetAccentable()

            if let freed = entry.stats.lastFreedBytes, freed > 0 {
                Text("Freed \(fmtBytes(freed)) · \(fmtAgo(entry.stats.lastFreedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .widgetAccentable()
            }

            Spacer(minLength: 6)

            // Two-button row: Clean (text-only, the meaningful
            // action) + Scan (icon-only refresh glyph, the secondary
            // "just re-measure" action). Same pattern as Quarantine's
            // Defang + Rescan combo so the family reads consistently.
            // Both `.bordered` (translucent gray pill, primary text)
            // — survive the dimmed widget state on macOS Tahoe where
            // tinted `.borderedProminent` backgrounds desaturate to
            // illegible near-white.
            HStack(spacing: 6) {
                Button(intent: CleanAllSafeIntent()) {
                    Text("Clean")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(entry.stats.itemCount == 0)

                Button(intent: ScanIntent()) {
                    // Empty title → icon-only bordered glyph button.
                    // `.help` keeps the accessibility label so VO
                    // users still hear "Scan".
                    Label("Scan", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Scan")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        // Bumped from 12 to 14 — gives the rings and the button some
        // breathing room from the widget edge after the user flagged
        // the previous build looked cramped.
        .padding(14)
    }

    private var headline: String {
        if entry.stats.itemCount == 0 { return "Tidy machine" }
        return "Across \(entry.stats.itemCount) item" +
            (entry.stats.itemCount == 1 ? "" : "s")
    }
}
