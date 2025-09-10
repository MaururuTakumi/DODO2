import SwiftUI
import AppKit
import Carbon.HIToolbox

struct PreferencesView: View {
    @State private var labels: [Label]
    @State private var settings: SettingsModel
    @State private var showingDeleteConfirm: Label? = nil
    @State private var overlayKeyCode: UInt32 = SettingsModel.defaultHotKey.keyCode
    @State private var overlayModifiers: UInt32 = SettingsModel.defaultHotKey.modifiers
    @ObservedObject private var hotkeys = HotKeyManager.shared
    @State private var compatMode: Bool = false

    init() {
        let store = Persistence.load()
        _labels = State(initialValue: store.labels)
        _settings = State(initialValue: store.settings ?? SettingsModel.defaults)
        if let hk = (store.settings ?? SettingsModel.defaults).overlayHotKey {
            _overlayKeyCode = State(initialValue: hk.keyCode)
            _overlayModifiers = State(initialValue: hk.modifiers)
        } else {
            _overlayKeyCode = State(initialValue: SettingsModel.defaultHotKey.keyCode)
            _overlayModifiers = State(initialValue: SettingsModel.defaultHotKey.modifiers)
        }
        _compatMode = State(initialValue: (store.settings ?? SettingsModel.defaults).useCompatibilityMode ?? false)
    }

    var body: some View {
        TabView {
            shortcutsTab
                .tabItem { Text("Shortcuts") }
            labelsTab
                .tabItem { Text("Labels") }
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }

    private var shortcutsTab: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Overlay Hotkey").font(.headline)
                HStack(spacing: 12) {
                    ShortcutCaptureView(keyCode: $overlayKeyCode, modifiers: $overlayModifiers)
                    Spacer()
                    Button("Apply") { applyOverlayHotKey() }
                    Button("Reset Default") {
                        overlayKeyCode = SettingsModel.defaultHotKey.keyCode
                        overlayModifiers = SettingsModel.defaultHotKey.modifiers
                        applyOverlayHotKey()
                    }
                }
                Text("現在: \(KeyDisplay.format(keyCode: overlayKeyCode, modifiers: overlayModifiers))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("既定: ⌥Space。衝突する場合（例：Raycast/Alfred）があるため、必要に応じて変更してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Status + compatibility mode
                HStack(spacing: 12) {
                    StatusBadge(status: hotkeys.status)
                    Toggle("互換モード (Event Tap) を有効化", isOn: $compatMode)
                        .onChange(of: compatMode) { on in
                            HotKeyManager.shared.enableCompatibilityMode(on)
                            // persist to settings
                            settings.useCompatibilityMode = on
                            saveSettings()
                        }
                    Spacer()
                    Button("権限を開く…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("テスト") {
                        HotKeyManager.shared.fireForTest()
                    }
                }
                Divider().padding(.vertical, 8)
                Text("Toggle Panel")
                    .font(.headline)
                HStack {
                    Toggle("Enable Primary", isOn: Binding(
                        get: { settings.togglePrimary?.enabled ?? false },
                        set: { on in
                            if settings.togglePrimary == nil { settings.togglePrimary = SettingsModel.defaults.togglePrimary }
                            settings.togglePrimary?.enabled = on
                            saveSettings()
                        }
                    ))
                    Spacer()
                    if let spec = settings.togglePrimary {
                        Text(KeyDisplay.format(keyCode: spec.keyCode, modifiers: spec.modifiers))
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Toggle("Enable Fallback", isOn: Binding(
                        get: { settings.toggleFallback?.enabled ?? true },
                        set: { on in
                            if settings.toggleFallback == nil { settings.toggleFallback = SettingsModel.defaults.toggleFallback }
                            settings.toggleFallback?.enabled = on
                            saveSettings()
                        }
                    ))
                    Spacer()
                    if let spec = settings.toggleFallback {
                        Text(KeyDisplay.format(keyCode: spec.keyCode, modifiers: spec.modifiers))
                            .foregroundColor(.secondary)
                    }
                }

                Divider().padding(.vertical, 8)

                Text("Global Quick Add")
                    .font(.headline)
                HStack(spacing: 12) {
                    Toggle("Enable ⌘⇧N", isOn: Binding(
                        get: { (settings.quickAddGlobal?.enabled ?? false) },
                        set: { on in
                            if settings.quickAddGlobal == nil {
                                settings.quickAddGlobal = HotkeySpec(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | shiftKey), enabled: on)
                            } else {
                                settings.quickAddGlobal?.enabled = on
                            }
                            saveSettings()
                        }
                    ))
                    Spacer()
                    if let spec = settings.quickAddGlobal, spec.enabled {
                        Text(KeyDisplay.format(keyCode: spec.keyCode, modifiers: spec.modifiers))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var labelsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    let newId = UUID().uuidString.prefix(8)
                    let nextColor = BrandColor.allCases.randomElement() ?? .gray
                    labels.append(Label(id: String(newId), name: "New Label", color: nextColor, order: labels.count))
                    saveLabels()
                } label: {
                    SwiftUI.Label("Add Label", systemImage: "plus")
                }
                Spacer()
            }
            List {
                ForEach($labels, id: \.id) { $label in
                    HStack {
                        Circle().fill(label.color.color).frame(width: 10, height: 10)
                        TextField("Name", text: $label.name, onCommit: { saveLabels() })
                        Spacer()
                        Picker("Color", selection: $label.color) {
                            ForEach(BrandColor.allCases, id: \.self) { c in
                                HStack {
                                    Circle().fill(c.color).frame(width: 10, height: 10)
                                    Text(String(describing: c).capitalized)
                                }.tag(c)
                            }
                        }
                        .labelsHidden()
                        Button(role: .destructive) {
                            showingDeleteConfirm = label
                        } label: { Image(systemName: "trash") }
                    }
                }
                .onMove { indices, newOffset in
                    labels.move(fromOffsets: indices, toOffset: newOffset)
                    saveLabels()
                }
                .onDelete { indexSet in
                    labels.remove(atOffsets: indexSet)
                    saveLabels()
                }
            }
            .listStyle(.inset)
        }
        .alert(item: $showingDeleteConfirm) { label in
            Alert(title: Text("Delete \(label.name)?"), message: Text("This will remove the label from the list. Tasks will keep their labelId but may point to a missing label."), primaryButton: .destructive(Text("Delete"), action: {
                labels.removeAll { $0.id == label.id }
                saveLabels()
            }), secondaryButton: .cancel())
        }
    }

    private func saveLabels() {
        // Persist labels without altering tasks
        var store = Persistence.load()
        store.labels = labels
        Persistence.save(store)
        NotificationCenter.default.post(name: .labelsDidChange, object: labels)
    }

    private func saveSettings() {
        var store = Persistence.load()
        store.settings = settings
        Persistence.save(store)
        HotKeyManager.shared.apply(settings: settings)
    }

    private func applyOverlayHotKey() {
        // Require at least one modifier to avoid bare Space etc.
        guard overlayModifiers != 0 else {
            let alert = NSAlert()
            alert.messageText = "修飾キーが必要です"
            alert.informativeText = "⌘/⌥/⇧/⌃のいずれかを含めてください（例：⌥Space）。"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        let candidate = HotKeyCombo(keyCode: overlayKeyCode, modifiers: overlayModifiers)
        if HotKeyManager.shared.start(with: candidate) {
            settings.overlayHotKey = candidate
            saveSettings()
            NotificationCenter.default.post(name: .hotKeySettingChanged, object: candidate)
        } else {
            // Revert to previously saved (or default) and inform user
            let fallback = settings.overlayHotKey ?? SettingsModel.defaultHotKey
            overlayKeyCode = fallback.keyCode
            overlayModifiers = fallback.modifiers
            settings.overlayHotKey = fallback
            saveSettings()
            let alert = NSAlert()
            alert.messageText = "ショートカット登録に失敗しました"
            alert.informativeText = "そのショートカットは他で使用されています。別の組み合わせを選んでください。"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

extension Notification.Name {
    static let labelsDidChange = Notification.Name("LabelsDidChange")
}

private struct StatusBadge: View {
    let status: HotKeyManager.HotKeyStatus
    var body: some View {
        let (text, color): (String, Color) = {
            switch status {
            case .inactive: return ("Inactive", .gray)
            case .active(.carbon): return ("Active (Carbon)", .green)
            case .active(.eventTap): return ("Active (Event Tap)", .blue)
            case .conflict: return ("Conflict", .orange)
            case .denied: return ("Permission Required", .red)
            case .error(_): return ("Error", .red)
            }
        }()
        return Text(text)
            .font(.caption).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
            .accessibilityLabel(Text(text))
    }
}
