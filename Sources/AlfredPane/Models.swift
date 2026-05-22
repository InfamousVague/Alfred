import Foundation
import Observation
import AppKit
import WidgetKit
import AlfredShared

/// Persisted user settings — a small JSON file in Application
/// Support. Mirrors the field set of the original design.
// Named `AppSettings` (not `Settings`) so it doesn't shadow
// SwiftUI's `Settings` scene used in AlfredApp.swift.
struct AppSettings: Codable {
    var roots: [String] = []          // empty = detected defaults
    var enabled: [String] = []        // empty = every default-on cat
    var useTrash: Bool = true         // recoverable vs permanent
    var minSizeMB: Int = 1            // ignore finds smaller than this
    var theme: String = "system"      // "system" | "dark" | "light"
}

enum Phase {
    case idle, scanning, results, cleaning
}

/// Thread-safe cancel flag shared between the @MainActor store and
/// the detached scan task.
final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    func reset() { lock.lock(); flag = false; lock.unlock() }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
}

@MainActor
@Observable
final class AlfredStore {
    var phase: Phase = .idle
    var finds: [Find] = []
    var totalBytes: Int64 = 0
    var selected: Set<String> = []
    var progress: ScanProgress?
    var settings = AppSettings()
    var lastFreedBytes: Int64?
    var errorMessage: String?

    let categories: [Category] = Catalog.all

    @ObservationIgnored private var didFirstScan = false
    @ObservationIgnored private let cancelToken = CancelToken()

    // MARK: Lifecycle

    func bootstrap() {
        settings = Self.loadSettings()
    }

    /// Called when the popover first opens — kick the initial scan
    /// exactly once. Reopening the panel doesn't re-scan (use the
    /// Rescan button); a menu-bar cleaner shouldn't churn the disk
    /// every time you glance at it.
    func scanIfNeeded() {
        guard !didFirstScan else { return }
        didFirstScan = true
        rescan()
    }

    // MARK: Scan

    func rescan() {
        if phase == .scanning { return }
        errorMessage = nil
        lastFreedBytes = nil
        phase = .scanning
        progress = nil
        cancelToken.reset()

        let s = settings
        let token = cancelToken
        let roots: [URL] = s.roots.isEmpty
            ? Scanner.defaultRoots()
            : s.roots.map { URL(fileURLWithPath: $0) }
        let enabled = Set(s.enabled)
        let minBytes = Int64(max(0, s.minSizeMB)) * 1024 * 1024

        Task.detached(priority: .userInitiated) {
            let result = Scanner.scan(
                roots: roots,
                enabled: enabled,
                minBytes: minBytes,
                cancelled: { token.isCancelled }
            ) { p in
                Task { @MainActor [weak self] in self?.progress = p }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.finds = result
                self.totalBytes = result.reduce(0) { $0 + $1.sizeBytes }
                self.selected = Set(result.map(\.id))
                self.phase = .results
                self.publishWidgetSnapshot(event: .scanFinished)
            }
        }
    }

    func cancelScan() {
        cancelToken.cancel()
    }

    // MARK: Selection

    var selectedFinds: [Find] { finds.filter { selected.contains($0.id) } }
    var selectedBytes: Int64 {
        selectedFinds.reduce(0) { $0 + $1.sizeBytes }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }

    func toggleCategory(_ categoryID: String, on: Bool) {
        for f in finds where f.categoryID == categoryID {
            if on { selected.insert(f.id) } else { selected.remove(f.id) }
        }
    }

    func selectAll(_ all: Bool) {
        selected = all ? Set(finds.map(\.id)) : []
    }

    /// Re-select just the safe-confidence finds (skipping every
    /// review-tier item) and run a clean. Used by the widget's
    /// `CleanAllSafeIntent` so a single click can never trash a
    /// venv / Pods / bare dist/ without the panel.
    func cleanAllSafe() {
        let safeIDs: Set<String> = Set(
            finds
                .filter { Catalog.category($0.categoryID)?.confidence == .safe }
                .map(\.id)
        )
        guard !safeIDs.isEmpty else { return }
        selected = safeIDs
        cleanSelected()
    }

    // MARK: Clean

    func cleanSelected() {
        let targets = selectedFinds
        guard !targets.isEmpty else { return }
        phase = .cleaning
        let useTrash = settings.useTrash
        let urls = targets.map(\.url)

        Task.detached(priority: .userInitiated) {
            let out = Scanner.clean(urls, useTrash: useTrash)
            await MainActor.run { [weak self] in
                guard let self else { return }
                let gone = Set(out.trashed.map(\.path))
                self.finds.removeAll { gone.contains($0.url.path) }
                for p in gone { self.selected.remove(p) }
                self.totalBytes = self.finds.reduce(0) {
                    $0 + $1.sizeBytes
                }
                self.lastFreedBytes = out.freedBytes
                if let first = out.failures.first {
                    self.errorMessage =
                        "\(out.failures.count) item(s) couldn't be removed: \(first.error)"
                }
                self.phase = .results
                self.publishWidgetSnapshot(event: .cleanFinished(
                    freed: out.freedBytes
                ))
            }
        }
    }

    // MARK: Widget snapshot

    /// Reasons the snapshot is being published. Affects whether
    /// `lastFreed*` fields update (clean) vs. just rolling the
    /// totals + categories (scan).
    enum SnapshotEvent {
        case scanFinished
        case cleanFinished(freed: Int64)
    }

    /// Persist a fresh `SharedStats` payload into the App Group
    /// container and tell every Alfred widget timeline to refresh.
    /// Called from the main actor after each scan/clean completes.
    private func publishWidgetSnapshot(event: SnapshotEvent) {
        // Roll up the top 3 categories by total bytes — the medium
        // widget shows these as rows. Items count is the total
        // number of finds (matches the hero's "across N items").
        var byCat: [String: (label: String, bytes: Int64, count: Int)] = [:]
        for f in finds {
            let label = Catalog.category(f.categoryID)?.label ?? f.categoryID
            var e = byCat[f.categoryID] ?? (label, 0, 0)
            e.bytes += f.sizeBytes
            e.count += 1
            byCat[f.categoryID] = e
        }
        let top = byCat
            .map { CategoryBreakdown(
                id: $0.key,
                label: $0.value.label,
                bytes: $0.value.bytes,
                count: $0.value.count
            ) }
            .sorted { $0.bytes > $1.bytes }
            .prefix(3)

        // Preserve the previous `lastFreed*` on a scan-only event
        // (clean updates them; a fresh scan shouldn't clobber the
        // "you reclaimed X yesterday" line on the widget).
        let prev = StatsStore.read()
        var lastFreedBytes = prev?.lastFreedBytes
        var lastFreedAt = prev?.lastFreedAt
        if case .cleanFinished(let freed) = event {
            lastFreedBytes = freed
            lastFreedAt = Date()
        }

        let snapshot = SharedStats(
            totalBytes: totalBytes,
            itemCount: finds.count,
            lastFreedBytes: lastFreedBytes,
            lastFreedAt: lastFreedAt,
            lastScanAt: Date(),
            topCategories: Array(top)
        )
        StatsStore.write(snapshot)
        // Wake every Alfred widget on the desktop so the new totals
        // appear right away rather than waiting on the timeline
        // policy's ~15-minute interval.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Settings

    func apply(_ next: AppSettings) {
        settings = next
        Self.saveSettings(next)
        rescan()
    }

    private static func settingsURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("com.mattssoftware.alfred")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("settings.json")
    }

    static func loadSettings() -> AppSettings {
        guard
            let data = try? Data(contentsOf: settingsURL()),
            let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return s
    }

    static func saveSettings(_ s: AppSettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: settingsURL(), options: .atomic)
    }
}

/// Human-readable bytes — binary units, the unit dev tools speak.
func fmtBytes(_ n: Int64) -> String {
    if n <= 0 { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    let d = Double(n)
    let i = min(Int(log(d) / log(1024)), units.count - 1)
    let v = d / pow(1024, Double(i))
    return v >= 100 || i == 0
        ? "\(Int(v.rounded())) \(units[i])"
        : String(format: "%.1f %@", v, units[i])
}
