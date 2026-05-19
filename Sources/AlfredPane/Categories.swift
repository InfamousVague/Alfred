import Foundation

/// Pure regenerable cache (default-on) vs heavier/occasionally-kept
/// (opt-in). Mirrors the safety tiering of the original design.
enum Confidence: String, Codable {
    case safe
    case review
}

/// Where a category is found: walked under the user's project roots
/// (sibling-gated so we only ever flag a regenerable artifact), or a
/// fixed well-known global tool cache under the home dir.
enum Scope: String, Codable {
    case project
    case global
}

struct Category: Identifiable, Hashable {
    let id: String
    let label: String
    let blurb: String
    let scope: Scope
    let confidence: Confidence
    let defaultEnabled: Bool

    static func == (a: Category, b: Category) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// A project-artifact rule: a directory name that, when found next to
/// one of `siblingAny` (empty = no gate), is a safe-to-delete,
/// regenerable artifact.
struct ProjectRule {
    let cat: Category
    let dirName: String
    let siblingAny: [String]
}

/// A fixed global cache at `rel` under the home dir. `perChild`
/// lists each immediate child as its own row (DerivedData/<proj>);
/// else the whole dir is one row.
struct GlobalRule {
    let cat: Category
    let rel: String
    let perChild: Bool
}

enum Catalog {
    static let projectRules: [ProjectRule] = [
        ProjectRule(cat: Category(id: "node_modules", label: "node_modules",
            blurb: "JS/TS dependencies — restored by `npm/pnpm/yarn install`.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: "node_modules", siblingAny: ["package.json"]),
        ProjectRule(cat: Category(id: "cargo-target", label: "Cargo target/",
            blurb: "Rust build output — restored by `cargo build`.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: "target", siblingAny: ["Cargo.toml"]),
        ProjectRule(cat: Category(id: "next", label: "Next.js .next/",
            blurb: "Next.js build cache — restored by `next build`.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".next", siblingAny: ["package.json"]),
        ProjectRule(cat: Category(id: "turbo", label: "Turbo .turbo/",
            blurb: "Turborepo task cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".turbo", siblingAny: ["package.json"]),
        ProjectRule(cat: Category(id: "vite", label: "Vite .vite/",
            blurb: "Vite dependency pre-bundle cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".vite", siblingAny: ["package.json"]),
        ProjectRule(cat: Category(id: "parcel", label: "Parcel .parcel-cache/",
            blurb: "Parcel bundler cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".parcel-cache", siblingAny: []),
        ProjectRule(cat: Category(id: "pycache", label: "__pycache__/",
            blurb: "Python bytecode cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: "__pycache__", siblingAny: []),
        ProjectRule(cat: Category(id: "pytest", label: ".pytest_cache/",
            blurb: "pytest run cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".pytest_cache", siblingAny: []),
        ProjectRule(cat: Category(id: "mypy", label: ".mypy_cache/",
            blurb: "mypy type-check cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".mypy_cache", siblingAny: []),
        ProjectRule(cat: Category(id: "ruff", label: ".ruff_cache/",
            blurb: "Ruff linter cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".ruff_cache", siblingAny: []),
        ProjectRule(cat: Category(id: "dart-tool", label: ".dart_tool/",
            blurb: "Dart/Flutter package tooling cache.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".dart_tool", siblingAny: ["pubspec.yaml"]),
        ProjectRule(cat: Category(id: "swiftpm", label: "SwiftPM .build/",
            blurb: "Swift Package Manager build dir.",
            scope: .project, confidence: .safe, defaultEnabled: true),
            dirName: ".build", siblingAny: ["Package.swift"]),
        // ── Review (opt-in) ──────────────────────────────────────
        ProjectRule(cat: Category(id: "venv", label: "Python venv",
            blurb: "Virtualenv — regenerable but re-installs every dep.",
            scope: .project, confidence: .review, defaultEnabled: false),
            dirName: ".venv", siblingAny: []),
        ProjectRule(cat: Category(id: "cocoapods", label: "CocoaPods Pods/",
            blurb: "Installed pods — restored by `pod install`.",
            scope: .project, confidence: .review, defaultEnabled: false),
            dirName: "Pods", siblingAny: ["Podfile"]),
        ProjectRule(cat: Category(id: "dist", label: "dist/ output",
            blurb: "Build output next to a JS manifest. Some libs commit this — review first.",
            scope: .project, confidence: .review, defaultEnabled: false),
            dirName: "dist", siblingAny: ["package.json"]),
    ]

    static let globalRules: [GlobalRule] = [
        GlobalRule(cat: Category(id: "xcode-deriveddata", label: "Xcode DerivedData",
            blurb: "Per-project build intermediates — fully rebuilt on next build.",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: "Library/Developer/Xcode/DerivedData", perChild: true),
        GlobalRule(cat: Category(id: "coresim-caches", label: "CoreSimulator Caches",
            blurb: "iOS Simulator caches.",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: "Library/Developer/CoreSimulator/Caches", perChild: false),
        GlobalRule(cat: Category(id: "npm-cache", label: "npm cache",
            blurb: "npm content-addressable cache (~/.npm/_cacache).",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: ".npm/_cacache", perChild: false),
        GlobalRule(cat: Category(id: "go-build", label: "Go build cache",
            blurb: "`go build` object cache.",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: "Library/Caches/go-build", perChild: false),
        GlobalRule(cat: Category(id: "gradle-caches", label: "Gradle caches",
            blurb: "~/.gradle/caches — re-downloaded on next build.",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: ".gradle/caches", perChild: false),
        GlobalRule(cat: Category(id: "cargo-registry", label: "Cargo registry cache",
            blurb: "Downloaded crate archives — re-fetched on next build.",
            scope: .global, confidence: .safe, defaultEnabled: true),
            rel: ".cargo/registry/cache", perChild: false),
        GlobalRule(cat: Category(id: "xcode-archives", label: "Xcode Archives",
            blurb: "Built .xcarchive bundles — you may want release archives. Opt-in.",
            scope: .global, confidence: .review, defaultEnabled: false),
            rel: "Library/Developer/Xcode/Archives", perChild: true),
    ]

    /// Flat catalog the UI renders + the delete guard validates
    /// against.
    static let all: [Category] =
        projectRules.map(\.cat) + globalRules.map(\.cat)

    static func category(_ id: String) -> Category? {
        all.first { $0.id == id }
    }

    /// Project-rule dir names + resolved global roots — the set a
    /// path must match to be deletable (defense in depth so a stale
    /// selection can't turn Alfred into an arbitrary `rm`).
    static func isCleanable(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if projectRules.contains(where: { $0.dirName == name }) {
            return true
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        for g in globalRules {
            let base = home.appendingPathComponent(g.rel)
            if url.standardizedFileURL == base.standardizedFileURL {
                return true
            }
            if url.deletingLastPathComponent().standardizedFileURL
                == base.standardizedFileURL {
                return true
            }
        }
        return false
    }
}
