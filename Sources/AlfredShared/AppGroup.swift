import Foundation

/// One source of truth for the App Group id used by the host
/// (Alfred / AlfredPane) and the widget extension to share the
/// `SharedStats` payload. **Must match the
/// `com.apple.security.application-groups` entitlement value in
/// `Alfred.entitlements` and `AlfredWidgets.entitlements`** — if any
/// of these three drift, the Group Container resolves to `nil` and
/// the widget silently shows the dev fallback file instead of live
/// data.
///
/// macOS requires App Group ids to be prefixed with the developer
/// team id (`F6ZAL7ANAD`) — `containermanagerd` rejects unprefixed
/// ids at runtime ("Group containers identifiers should be prefixed
/// by requestor's team ID"), and the widget extension dies 35ms
/// after launch with a connection-invalidated XPC error. iOS is
/// more lenient (any `group.*` works there) which is why this
/// convention bites everyone porting widget code.
public enum AppGroup {
    public static let id = "F6ZAL7ANAD.group.com.mattssoftware.alfred"
}
