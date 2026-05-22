import SwiftUI
import WidgetKit
import AlfredShared

/// Compact layout for `.systemSmall`. Centred vertically + horizontally:
/// brand tag → reclaimable headline → subline. Single primary action
/// button (Scan) pinned to the bottom edge. Medium tile keeps the same
/// hero and adds a category breakdown + a Clean button.
struct SmallView: View {
    let entry: AlfredEntry

    var body: some View {
        VStack(spacing: 6) {
            // Top spacer pushes the content block to the vertical
            // centre — the original .leading VStack was top-aligning
            // everything and leaving a dead band above the button.
            Spacer(minLength: 0)

            Text("ALFRED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Text(fmtBytes(entry.stats.totalBytes))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
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

            // Hand-rolled pill. Don't rely on Color.accentColor here
            // — in the widget render pass it's resolving to white,
            // producing a solid-white capsule with white text (= no
            // visible button). Hardcode Alfred's brand green (the
            // same #2f8b48 the app icon uses) so the contrast is
            // guaranteed regardless of system / widget tint state.
            Button(intent: ScanIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Color(red: 0.184, green: 0.545, blue: 0.282),
                    in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(12)
    }

    private var headline: String {
        if entry.stats.itemCount == 0 { return "tidy machine" }
        return "across \(entry.stats.itemCount) item" +
            (entry.stats.itemCount == 1 ? "" : "s")
    }
}
