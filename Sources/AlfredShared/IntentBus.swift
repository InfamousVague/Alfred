import Foundation

/// Bridge between the AppIntents (defined here in AlfredShared so
/// both the widget extension and the host can see them) and the
/// running Alfred host process that will actually do the work.
///
/// Both `ScanIntent` and `CleanAllSafeIntent` declare
/// `openAppWhenRun = true`, so when the widget's `Button(intent:)`
/// fires the system wakes / launches Alfred and runs `perform()` in
/// the **host process** — that's where the scanner has the user's
/// real file privileges, not the sandboxed widget extension. The
/// host's `AppDelegate` calls `IntentBus.shared.register(...)` at
/// launch with closures that drive `AlfredStore`; the AppIntent's
/// `perform()` invokes those closures via the bus. No registered
/// handlers (running in the extension by accident, or before the
/// host has finished launching) → silent no-op rather than crash.
@MainActor
public final class IntentBus {
    public static let shared = IntentBus()
    private init() {}

    private var scanHandler: (@MainActor () -> Void)?
    private var cleanSafeHandler: (@MainActor () -> Void)?

    public func register(
        scan: @escaping @MainActor () -> Void,
        cleanSafe: @escaping @MainActor () -> Void
    ) {
        self.scanHandler = scan
        self.cleanSafeHandler = cleanSafe
    }

    public func scan() { scanHandler?() }
    public func cleanAllSafe() { cleanSafeHandler?() }
}
