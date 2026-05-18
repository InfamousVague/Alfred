import Foundation
import AppKit

struct Find: Identifiable, Hashable {
    let url: URL
    let categoryID: String
    let project: String
    let sizeBytes: Int64
    var id: String { url.path }
}

struct ScanProgress {
    var scannedDirs: Int
    var found: Int
    var totalBytes: Int64
    var current: String
}

struct CleanOutcome {
    var trashed: [URL]
    var failures: [(url: URL, error: String)]
    var freedBytes: Int64
}

/// All disk work. Pure `Foundation` — `FileManager` walk + Trash;
/// no third-party deps, matching the rest of the menu-bar apps.
enum Scanner {

    private static let pruned: Set<String> = [
        "Library", "Applications", ".Trash", ".git", ".hg", ".svn",
        "System", "Pictures", "Movies", "Music",
    ]

    /// Conventional dev folders that exist, else the home dir
    /// (Library/system are pruned mid-walk).
    static func defaultRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let names = [
            "Development", "Projects", "project", "code", "Code",
            "src", "repos", "dev", "work", "Documents/GitHub",
        ]
        let found = names
            .map { home.appendingPathComponent($0) }
            .filter { isDir($0) }
        return found.isEmpty ? [home] : found
    }

    static func defaultRootPaths() -> [String] {
        defaultRoots().map(\.path)
    }

    private static func isDir(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?
            .isDirectory ?? false
    }

    /// Recursive on-disk size, not following symlinks.
    static func dirSize(_ url: URL, cancelled: () -> Bool) -> Int64 {
        var total: Int64 = 0
        let keys: [URLResourceKey] = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .fileSizeKey, .isRegularFileKey,
        ]
        guard let en = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }
        for case let f as URL in en {
            if cancelled() { break }
            let v = try? f.resourceValues(forKeys: Set(keys))
            if v?.isRegularFile == true {
                total += Int64(
                    v?.totalFileAllocatedSize
                        ?? v?.fileAllocatedSize
                        ?? v?.fileSize
                        ?? 0
                )
            }
        }
        return total
    }

    /// Walk roots + global caches. `enabled` empty = default-on
    /// categories. `progress` is called periodically off the main
    /// actor; the caller hops to main to publish it.
    static func scan(
        roots: [URL],
        enabled: Set<String>,
        minBytes: Int64,
        cancelled: @escaping () -> Bool,
        progress: (ScanProgress) -> Void
    ) -> [Find] {
        let prules = Catalog.projectRules
        let grules = Catalog.globalRules
        let defaultsOn = Set(
            Catalog.all.filter(\.defaultEnabled).map(\.id)
        )
        func on(_ id: String) -> Bool {
            enabled.isEmpty ? defaultsOn.contains(id) : enabled.contains(id)
        }

        var finds: [Find] = []
        var scanned = 0
        var total: Int64 = 0
        let fm = FileManager.default

        for root in roots {
            guard isDir(root) else { continue }
            guard let en = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else { continue }

            for case let url as URL in en {
                if cancelled() { return finds }
                guard
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?
                        .isDirectory == true
                else { continue }

                let name = url.lastPathComponent

                if en.level > 1, pruned.contains(name) {
                    en.skipDescendants()
                    continue
                }
                // Depth cap — deep monorepos otherwise crawl forever.
                if en.level > 10 {
                    en.skipDescendants()
                    continue
                }

                scanned += 1
                if scanned % 200 == 0 {
                    progress(ScanProgress(
                        scannedDirs: scanned,
                        found: finds.count,
                        totalBytes: total,
                        current: url.path
                    ))
                }

                guard
                    let rule = prules.first(where: {
                        $0.dirName == name && on($0.cat.id)
                    })
                else { continue }

                let parent = url.deletingLastPathComponent()
                let siblingOK = rule.siblingAny.isEmpty
                    || rule.siblingAny.contains {
                        fm.fileExists(atPath:
                            parent.appendingPathComponent($0).path)
                    }
                guard siblingOK else { continue }

                let size = dirSize(url, cancelled: cancelled)
                if size >= minBytes {
                    total += size
                    finds.append(Find(
                        url: url,
                        categoryID: rule.cat.id,
                        project: parent.lastPathComponent,
                        sizeBytes: size
                    ))
                }
                // Never descend into a matched artifact dir.
                en.skipDescendants()
            }
        }

        // Global caches — checked directly, not walked.
        let home = fm.homeDirectoryForCurrentUser
        for g in grules where on(g.cat.id) {
            if cancelled() { break }
            let base = home.appendingPathComponent(g.rel)
            guard isDir(base) else { continue }
            if g.perChild {
                let kids = (try? fm.contentsOfDirectory(
                    at: base,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )) ?? []
                for child in kids where isDir(child) {
                    if cancelled() { break }
                    let size = dirSize(child, cancelled: cancelled)
                    if size >= minBytes {
                        total += size
                        finds.append(Find(
                            url: child,
                            categoryID: g.cat.id,
                            project: child.lastPathComponent,
                            sizeBytes: size
                        ))
                    }
                }
            } else {
                let size = dirSize(base, cancelled: cancelled)
                if size >= minBytes {
                    total += size
                    finds.append(Find(
                        url: base,
                        categoryID: g.cat.id,
                        project: g.cat.label,
                        sizeBytes: size
                    ))
                }
            }
        }

        finds.sort { $0.sizeBytes > $1.sizeBytes }
        return finds
    }

    /// Trash (recoverable, default) or permanently delete. Every URL
    /// is re-validated against the catalog first — defense in depth
    /// so a stale selection can't delete something arbitrary.
    static func clean(_ urls: [URL], useTrash: Bool) -> CleanOutcome {
        var out = CleanOutcome(trashed: [], failures: [], freedBytes: 0)
        let fm = FileManager.default
        for url in urls {
            guard Catalog.isCleanable(url) else {
                out.failures.append((url,
                    "refused: not a recognised cleanable artifact"))
                continue
            }
            if !fm.fileExists(atPath: url.path) {
                out.trashed.append(url)  // already gone — drop the row
                continue
            }
            let size = dirSize(url, cancelled: { false })
            do {
                if useTrash {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try fm.removeItem(at: url)
                }
                out.freedBytes += size
                out.trashed.append(url)
            } catch {
                out.failures.append((url, error.localizedDescription))
            }
        }
        return out
    }

    /// Reveal a path in Finder (the "show me what you'd delete"
    /// escape hatch).
    static func reveal(_ url: URL) {
        let target = FileManager.default.fileExists(atPath: url.path)
            ? url : url.deletingLastPathComponent()
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
}
