import SwiftUI
import WidgetKit
import AlfredShared

/// `.systemMedium` Alfred layout. Same chrome vocabulary as
/// `SmallView` (tracked "ALFRED" caps brand, no SF Symbol) but in a
/// two-column split: left = hero number + headline + Scan + Clean,
/// right = top-3 category rollup. Matches Stats' / Port's medium
/// proportions.
struct MediumView: View {
    let entry: AlfredEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // ── Left column: brand → hero → freed line → buttons.
            VStack(alignment: .leading, spacing: 4) {
                Text("ALFRED")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()

                Spacer(minLength: 0)

                Text(fmtBytes(entry.stats.totalBytes))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let freed = entry.stats.lastFreedBytes, freed > 0 {
                    Text("Freed \(fmtBytes(freed)) · \(fmtAgo(entry.stats.lastFreedAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                // Two-button row: Clean (text-only, meaningful
                // action) + Scan (icon-only refresh glyph, secondary
                // "just re-measure"). Same pattern Quarantine adopted
                // for Defang + Rescan — keeps the family consistent.
                // Both `.bordered` so the dimmed widget state on
                // macOS Tahoe stays legible (cf. `.borderedProminent`
                // desaturating to white-on-white).
                HStack(spacing: 6) {
                    Button(intent: CleanAllSafeIntent()) {
                        Text("Clean")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(entry.stats.itemCount == 0)

                    Button(intent: ScanIntent()) {
                        Label("Scan", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Scan")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Right column: category rollup. Header matches the
            // tracked-caps brand vocabulary on the left, just dimmer.
            VStack(alignment: .leading, spacing: 4) {
                Text("TOP")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .widgetAccentable()

                if entry.stats.topCategories.isEmpty {
                    Text("No scan yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(entry.stats.topCategories.prefix(3)) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(row.label)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(fmtBytes(row.bytes))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Bumped from 12 to 16 — same breathing-room fix as Small.
        // Medium has a TOP-categories column on the right that sat
        // hard against the edge at 12pt.
        .padding(16)
    }

    private var headline: String {
        if entry.stats.itemCount == 0 { return "Tidy machine" }
        return "Across \(entry.stats.itemCount) item" +
            (entry.stats.itemCount == 1 ? "" : "s")
    }
}
