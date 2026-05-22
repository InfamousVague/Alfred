import Foundation

/// Binary-units byte formatter — same vocabulary the panel uses, so
/// the widget readout matches what the user sees in Alfred itself.
/// Duplicated rather than imported from AlfredPane because the
/// widget extension never links AlfredPane (it must stay tiny and
/// only depends on AlfredShared).
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

/// Compact "X ago" — "2m", "3h", "1d". Empty string for nil so the
/// view can `.lineLimit(1)` away missing lines without `if let`s.
func fmtAgo(_ when: Date?) -> String {
    guard let when else { return "" }
    let s = max(0, Date().timeIntervalSince(when))
    if s < 60 { return "just now" }
    if s < 3600 { return "\(Int(s / 60))m ago" }
    if s < 86400 { return "\(Int(s / 3600))h ago" }
    return "\(Int(s / 86400))d ago"
}
