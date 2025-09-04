import SwiftUI
import Carbon.HIToolbox

struct PreferencesView: View {
    @State private var labels: [Label]
    @State private var settings: SettingsModel
    @State private var showingDeleteConfirm: Label? = nil

    init() {
        let store = Persistence.load()
        _labels = State(initialValue: store.labels)
        _settings = State(initialValue: store.settings ?? SettingsModel.defaults)
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
}

extension Notification.Name {
    static let labelsDidChange = Notification.Name("LabelsDidChange")
}
