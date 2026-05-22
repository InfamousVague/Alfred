import SwiftUI
import WidgetKit
import AlfredShared

/// `.systemMedium` layout — wider, so the headline number sits on
/// the left and the top-3 category breakdown stacks on the right.
/// Two buttons at the bottom (Scan + Clean safe) since there's
/// room to also surface what would be cleaned.
struct MediumView: View {
    let entry: AlfredEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: brand + hero + last-freed line.
            VStack(alignment: .leading, spacing: 4) {
                Text("ALFRED")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Text(fmtBytes(entry.stats.totalBytes))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(headline)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let freed = entry.stats.lastFreedBytes, freed > 0 {
                    Text("freed \(fmtBytes(freed)) · \(fmtAgo(entry.stats.lastFreedAt))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Hand-rolled pills with HARDCODED Alfred green
                // (#2f8b48). Color.accentColor was resolving to white
                // on the widget surface, producing invisible buttons;
                // semantic colors like .primary / .secondary were
                // similarly washing out. Explicit RGB values guarantee
                // the capsule + label contrast.
                let alfredGreen = Color(
                    red: 0.184, green: 0.545, blue: 0.282)
                HStack(spacing: 6) {
                    Button(intent: ScanIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Scan")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Color.black.opacity(0.35),
                            in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(intent: CleanAllSafeIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clean")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            entry.stats.itemCount == 0
                                ? alfredGreen.opacity(0.35)
                                : alfredGreen,
                            in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.stats.itemCount == 0)
                }
            }

            // Right: top-3 category rollup. Sized to ~half the
            // tile; rows truncate gracefully on narrower medium
            // layouts (some themes squeeze the medium tile).
            VStack(alignment: .leading, spacing: 4) {
                Text("TOP")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                if entry.stats.topCategories.isEmpty {
                    Text("no scan yet")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(entry.stats.topCategories.prefix(3)) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(row.label)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(fmtBytes(row.bytes))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var headline: String {
        if entry.stats.itemCount == 0 { return "tidy machine" }
        return "across \(entry.stats.itemCount) item" +
            (entry.stats.itemCount == 1 ? "" : "s")
    }
}
