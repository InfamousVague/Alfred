import SwiftUI
import WidgetKit
import AlfredShared

/// Compact layout for `.systemSmall`. Big reclaimable number on
/// top, a subline summarising the last clean, and one primary
/// action button (Scan) — Clean lives on the medium tile where
/// there's room to also show what would be cleaned.
struct SmallView: View {
    let entry: AlfredEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ALFRED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Text(fmtBytes(entry.stats.totalBytes))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
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

            Button(intent: ScanIntent()) {
                Label("Scan", systemImage: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.accentColor)
        }
        .padding(12)
    }

    private var headline: String {
        if entry.stats.itemCount == 0 { return "tidy machine" }
        return "across \(entry.stats.itemCount) item" +
            (entry.stats.itemCount == 1 ? "" : "s")
    }
}
