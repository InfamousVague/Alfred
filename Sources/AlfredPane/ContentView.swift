import SwiftUI
import AppKit

/// Alfred's brand accent. Mirrors the Espresso pattern (a named
/// accent + a darker companion) — derived from the cool-slate
/// chromatic region of the real app icon, brightened so it reads
/// as a confident tint on the dark popover rather than mud.
extension Color {
    static let alfredAccent = Color(red: 0.46, green: 0.56, blue: 0.86)
    static let alfredAccentDark = Color(red: 0.286, green: 0.322, blue: 0.416)
}

struct ContentView: View {
    @Environment(AlfredStore.self) private var store
    @State private var showSettings = false
    @State private var confirming = false
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 46)
            Divider()
            hero
            if let err = store.errorMessage {
                errorStrip(err)
            }
            Divider()
            content
            Divider()
            footer
                .frame(height: 46)
        }
        .frame(width: 340, height: 540)
        .glassScrollers()
        // Brand-tint controls (buttons, the checkbox, .tint usages)
        // the way Espresso applies `.tint(accent)` panel-wide.
        .tint(.alfredAccent)
        .sheet(isPresented: $showSettings) {
            SettingsView(
                initial: store.settings,
                categories: store.categories
            ) { next in
                store.apply(next)
                showSettings = false
            } onCancel: {
                showSettings = false
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 7) {
                // The tray glyph itself, tinted in the brand accent —
                // exactly how Espresso shows its cup glyph in crema
                // in the panel header (vs. the full-colour app icon).
                Image(nsImage: AlfredBrand.trayGlyph)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    // The glyph is now a tall, tightly-cropped duster
                    // (aspect ~0.71). aspectRatio(.fit) keeps it from
                    // being squashed into a square box; a 24pt tall
                    // frame makes it read at a confident size beside
                    // the wordmark instead of tiny-with-whitespace.
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.alfredAccent)
                Text("ALFRED")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
                if store.phase == .scanning || store.phase == .cleaning {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                }
            }
            Spacer()
            Text("reclaim dev disk space")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 2) {
            Text(fmtBytes(store.totalBytes))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(heroLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var heroLabel: String {
        switch store.phase {
        case .scanning: return "scanning…"
        case .cleaning: return "cleaning…"
        default:
            return store.finds.isEmpty
                ? "nothing to reclaim"
                : "reclaimable across \(store.finds.count) item\(store.finds.count == 1 ? "" : "s")"
        }
    }

    private func errorStrip(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(msg).font(.system(size: 11)).lineLimit(2)
            Spacer()
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.10))
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .scanning:
            centered {
                ProgressView().controlSize(.small)
                Text(scanStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if let p = store.progress {
                    Text(p.current)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .padding(.horizontal, 24)
                }
            }
        default:
            if store.finds.isEmpty {
                centered {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)
                    Text(emptyMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            } else {
                resultsList
            }
        }
    }

    private var scanStatus: String {
        guard let p = store.progress else {
            return "Walking your project roots…"
        }
        return "Scanned \(p.scannedDirs) folders · \(p.found) found"
    }

    private var emptyMessage: String {
        if let freed = store.lastFreedBytes {
            return "Done — \(fmtBytes(freed)) reclaimed. Spotless."
        }
        return "No safe-to-delete cruft found. Tidy machine."
    }

    private func centered<C: View>(
        @ViewBuilder _ c: () -> C
    ) -> some View {
        VStack(spacing: 12) { c() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groups: [(cat: Category, items: [Find], bytes: Int64)] {
        var byCat: [String: [Find]] = [:]
        for f in store.finds { byCat[f.categoryID, default: []].append(f) }
        return byCat.compactMap { id, items -> (Category, [Find], Int64)? in
            guard let cat = Catalog.category(id) else { return nil }
            let sorted = items.sorted { $0.sizeBytes > $1.sizeBytes }
            return (cat, sorted, sorted.reduce(0) { $0 + $1.sizeBytes })
        }
        .sorted { $0.2 > $1.2 }
        .map { (cat: $0.0, items: $0.1, bytes: $0.2) }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(groups, id: \.cat.id) { g in
                    groupCard(g.cat, g.items, g.bytes)
                }
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity)
    }

    private func groupCard(
        _ cat: Category, _ items: [Find], _ bytes: Int64
    ) -> some View {
        let sel = items.filter { store.selected.contains($0.id) }.count
        let allSel = sel == items.count
        let isOpen = expanded.contains(cat.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                CheckBox(
                    state: allSel ? .on : (sel == 0 ? .off : .mixed)
                ) { store.toggleCategory(cat.id, on: !allSel) }
                Button {
                    if isOpen { expanded.remove(cat.id) }
                    else { expanded.insert(cat.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOpen
                            ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(cat.label)
                            .font(.system(size: 12, weight: .medium))
                        if cat.confidence == .review {
                            Text("review")
                                .font(.system(size: 8, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.18))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        PaddedCount(items.count)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(fmtBytes(bytes))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(10)

            if !isOpen {
                Text(cat.blurb)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { f in
                        Divider()
                        itemRow(f)
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func itemRow(_ f: Find) -> some View {
        HStack(spacing: 8) {
            CheckBox(
                state: store.selected.contains(f.id) ? .on : .off
            ) { store.toggle(f.id) }
            Image(systemName: "folder")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.project)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(f.url.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Text(fmtBytes(f.sizeBytes))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                Scanner.reveal(f.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if confirming {
            HStack {
                Text("\(store.settings.useTrash ? "Move to Trash" : "Delete") \(store.selectedFinds.count) · \(fmtBytes(store.selectedBytes))?")
                    .font(.system(size: 11))
                Spacer()
                Button("Cancel") { confirming = false }
                    .controlSize(.small)
                Button(store.settings.useTrash ? "Trash" : "Delete") {
                    confirming = false
                    store.cleanSelected()
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .tint(.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        } else {
            HStack(spacing: 10) {
                if store.phase == .scanning {
                    Button("Stop") { store.cancelScan() }
                        .controlSize(.small)
                } else {
                    Button {
                        store.rescan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .help("Rescan")
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .controlSize(.small)
                .help("Settings")

                Spacer()

                if store.phase == .results, !store.finds.isEmpty {
                    // Selected count/size readout removed — it just
                    // duplicated the hero's reclaimable total + item
                    // count shown up top.
                    Button(
                        store.selected.count == store.finds.count
                            ? "None" : "All"
                    ) {
                        store.selectAll(
                            store.selected.count != store.finds.count
                        )
                    }
                    .controlSize(.small)
                    Button("Clean") { confirming = true }
                        .controlSize(.small)
                        .keyboardShortcut(.defaultAction)
                        .disabled(store.selectedFinds.isEmpty
                            || store.phase == .cleaning)
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .controlSize(.small)
                .help("Quit Alfred")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }
}

// MARK: - Small components

/// Pulsing "live" dot, same affordance Port uses in its header.
struct LiveDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .opacity(on ? 1 : 0.35)
            .animation(
                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                value: on
            )
            .onAppear { on = true }
    }
}

/// A tri-state checkbox that reads cleanly in both light/dark menu
/// popovers (the system one is heavy here).
struct CheckBox: View {
    enum State { case on, off, mixed }
    let state: State
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(state == .off
                    ? Color.clear : Color.alfredAccent)
                .frame(width: 15, height: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            state == .off
                                ? Color.secondary.opacity(0.5)
                                : Color.alfredAccent,
                            lineWidth: 1.5
                        )
                )
                .overlay(glyph)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var glyph: some View {
        switch state {
        case .on:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        case .mixed:
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: 7, height: 2)
        case .off:
            EmptyView()
        }
    }
}
