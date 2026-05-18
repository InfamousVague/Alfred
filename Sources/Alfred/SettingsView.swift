import SwiftUI

struct SettingsView: View {
    let initial: AppSettings
    let categories: [Category]
    let onSave: (AppSettings) -> Void
    let onCancel: () -> Void

    @State private var roots: [String]
    @State private var enabled: Set<String>
    @State private var useTrash: Bool
    @State private var minMB: Int
    @State private var theme: String
    @State private var newRoot: String = ""

    private let detected = Scanner.defaultRootPaths()

    init(
        initial: AppSettings,
        categories: [Category],
        onSave: @escaping (AppSettings) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.categories = categories
        self.onSave = onSave
        self.onCancel = onCancel
        _roots = State(initialValue: initial.roots)
        _enabled = State(initialValue: Set(
            initial.enabled.isEmpty
                ? categories.filter(\.defaultEnabled).map(\.id)
                : initial.enabled
        ))
        _useTrash = State(initialValue: initial.useTrash)
        _minMB = State(initialValue: initial.minSizeMB)
        _theme = State(initialValue: initial.theme)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rootsSection
                    catSection(
                        "Project artifacts",
                        categories.filter { $0.scope == .project }
                    )
                    catSection(
                        "Global tool caches",
                        categories.filter { $0.scope == .global }
                    )
                    behaviourSection
                }
                .padding(16)
            }
            .frame(maxHeight: 420)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save & rescan") {
                    onSave(AppSettings(
                        roots: roots,
                        enabled: categories
                            .filter { enabled.contains($0.id) }
                            .map(\.id),
                        useTrash: useTrash,
                        minSizeMB: max(0, minMB),
                        theme: theme
                    ))
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 460)
    }

    // MARK: Roots

    private var rootsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan roots").font(.system(size: 12, weight: .semibold))
            Text("Folders Alfred walks for project artifacts. Empty = detected defaults: \(detected.joined(separator: "  ·  "))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if roots.isEmpty {
                Text("Using defaults")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                ForEach(roots, id: \.self) { r in
                    HStack {
                        Text(r)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1).truncationMode(.head)
                        Spacer()
                        Button {
                            roots.removeAll { $0 == r }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField("/Users/you/code", text: $newRoot)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                Button("Add") {
                    let v = newRoot.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    if !v.isEmpty, !roots.contains(v) { roots.append(v) }
                    newRoot = ""
                }
                .disabled(newRoot.trimmingCharacters(
                    in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: Categories

    private func catSection(_ title: String, _ cats: [Category]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold))
            ForEach(cats) { c in
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { enabled.contains(c.id) },
                        set: { on in
                            if on { enabled.insert(c.id) }
                            else { enabled.remove(c.id) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(c.label)
                                .font(.system(size: 12, weight: .medium))
                            if c.confidence == .review {
                                Text("review")
                                    .font(.system(size: 8, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(c.blurb)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Behaviour

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Behaviour").font(.system(size: 12, weight: .semibold))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Move to Trash")
                        .font(.system(size: 12, weight: .medium))
                    Text("Recoverable. Off = permanent delete (no undo).")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $useTrash)
                    .labelsHidden().toggleStyle(.switch)
                    .controlSize(.small)
            }
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Minimum size")
                        .font(.system(size: 12, weight: .medium))
                    Text("Ignore finds smaller than this (MB).")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Stepper(
                    "\(minMB) MB",
                    value: $minMB, in: 0...1024, step: 1
                )
                .font(.system(size: 11))
                .fixedSize()
            }
            HStack {
                Text("Appearance")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $theme) {
                    Text("System").tag("system")
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}
