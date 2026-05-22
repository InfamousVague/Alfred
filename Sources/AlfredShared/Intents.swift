import AppIntents

/// AppIntents driven by the widget's `Button(intent:)`. Both set
/// `openAppWhenRun = true` so the system delegates execution to the
/// host (Alfred) process — keeping the scanner + Trash code path
/// out of the sandboxed widget extension, where `FileManager`
/// access to the user's home dir is restricted.
///
/// `perform()` runs on the host once it's launched/woken, hits
/// `IntentBus.shared` which the host's `AppDelegate` registered
/// during launch, and the bus calls back into `AlfredStore`. The
/// widget itself never touches these handlers — it just emits the
/// intent.
public struct ScanIntent: AppIntent {
    public static var title: LocalizedStringResource =
        "Scan for cleanup"
    public static var description = IntentDescription(
        "Run an Alfred scan and refresh the widget with new totals."
    )
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.scan()
        return .result()
    }
}

public struct CleanAllSafeIntent: AppIntent {
    public static var title: LocalizedStringResource =
        "Clean safe items"
    // IntentDescription accepts a string LITERAL via
    // ExpressibleByStringLiteral; a `"a" + "b"` concatenation is an
    // expression, not a literal, and won't compile. Keep it one line.
    public static var description = IntentDescription("Move every safe-tier finding to the Trash. Review-tier items (virtualenvs, Pods, bare dist/) are NEVER touched from the widget — they require a manual review in the panel.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.cleanAllSafe()
        return .result()
    }
}
