import Foundation

/// The wire format Alfred writes to the App Group container and the
/// widget reads off its timeline. Plain Codable — no platform types
/// — so the schema stays stable when AlfredPane's internals churn.
///
/// Update `version` when you add a non-optional field; the widget's
/// reader treats a version mismatch as "no data yet" rather than
/// crashing on a stale payload from an older Alfred build sitting
/// in `/Applications`.
public struct SharedStats: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int

    public var totalBytes: Int64
    public var itemCount: Int
    public var lastFreedBytes: Int64?
    public var lastFreedAt: Date?
    public var lastScanAt: Date?
    public var topCategories: [CategoryBreakdown]

    public init(
        version: Int = SharedStats.currentVersion,
        totalBytes: Int64 = 0,
        itemCount: Int = 0,
        lastFreedBytes: Int64? = nil,
        lastFreedAt: Date? = nil,
        lastScanAt: Date? = nil,
        topCategories: [CategoryBreakdown] = []
    ) {
        self.version = version
        self.totalBytes = totalBytes
        self.itemCount = itemCount
        self.lastFreedBytes = lastFreedBytes
        self.lastFreedAt = lastFreedAt
        self.lastScanAt = lastScanAt
        self.topCategories = topCategories
    }

    /// Placeholder used by `Provider.placeholder` while the widget is
    /// being designed in the gallery, and by the first launch before
    /// any scan has populated the Group Container.
    public static let placeholder = SharedStats(
        totalBytes: 0,
        itemCount: 0,
        lastFreedBytes: nil,
        lastFreedAt: nil,
        lastScanAt: nil,
        topCategories: [
            CategoryBreakdown(id: "node_modules", label: "node_modules",
                              bytes: 0, count: 0),
            CategoryBreakdown(id: "cargo-target", label: "Cargo target/",
                              bytes: 0, count: 0),
        ]
    )
}

/// One row in `SharedStats.topCategories`. Decoupled from
/// AlfredPane's `Category` struct on purpose — the widget never
/// imports AlfredPane (extension/host process split), so we ship a
/// flat schema and let the host pre-rollup.
public struct CategoryBreakdown: Codable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let bytes: Int64
    public let count: Int
    public init(id: String, label: String, bytes: Int64, count: Int) {
        self.id = id; self.label = label; self.bytes = bytes; self.count = count
    }
}
