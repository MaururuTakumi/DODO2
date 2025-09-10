import SwiftUI
import AppKit

struct HeaderBar: View {
    @Binding var quickAddText: String
    @Binding var searchText: String
    @Binding var labels: [Label]
    @Binding var selectedLabels: Set<String> // stores label ids
    let onCommitQuickAdd: (String) -> Void
    let onAssignLabelToTaskId: (_ taskId: UUID, _ labelId: String) -> Void
    let onRequestClearCompleted: () -> Void
    let onRequestDeleteSelected: () -> Void
    let hasSelectedTask: Bool
    let counts: [String: Int]
    let suggestNameForTask: (UUID) -> String?
    let reassignTasksFromDeletedLabel: (_ deletedId: String, _ fallbackId: String) -> Void
    var isMatrixOpen: Bool = false
    var onToggleMatrix: () -> Void = {}
    @AppStorage("didSeeMatrixCoachmark") private var didSeeMatrixCoachmark: Bool = false
    @State private var showCoachmark: Bool = false

    @FocusState private var quickAddFocused: Bool
    @State private var showLabelPopover = false
    @State private var editingLabelId: String? = nil
    @State private var draftName: String = ""
    @State private var draftColor: BrandColor = .gray
    @State private var chipFocusIndex: Int? = nil

    var body: some View {
        HStack(spacing: BrandTokens.gutter) {
            NewTaskButton {
                NotificationCenter.default.post(name: ._internalFocusQuickAddNow, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
            .help("New Task (⌘N)")

            // Label chips scroll
            ZStack(alignment: .leading) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                    ForEach(Array(labels.enumerated()), id: \.0) { i, spec in
                        let isSelected = selectedLabels.contains(spec.id)
                        DropChip(spec: spec, isSelected: isSelected, isFocused: chipFocusIndex == i, count: counts[spec.id] ?? 0, onTap: { toggleLabel(spec.id) }) { taskId in
                            onAssignLabelToTaskId(taskId, spec.id)
                        }
                        .contextMenu {
                            Button("Rename…") { beginEdit(labelId: spec.id, mode: .rename) }
                            Button("Change Color…") { beginEdit(labelId: spec.id, mode: .color) }
                            Divider()
                            Button(role: .destructive) { deleteLabel(spec) } label: { Text("Delete…") }
                        }
                        .onDrag { NSItemProvider(object: NSString(string: "label:\(spec.id)")) }
                        .onDrop(of: ["public.text"], isTargeted: .constant(false)) { provs in
                            guard let p = provs.first else { return false }
                            _ = p.loadObject(ofClass: NSString.self) { (obj, _) in
                                guard let s = obj as? NSString, s.hasPrefix("label:"), let id = s.components(separatedBy: ":").last else { return }
                                DispatchQueue.main.async { moveLabel(id: id, toBefore: spec.id) }
                            }
                            return true
                        }
                    }
                    Divider().frame(height: 18)
                    PlusChip(showCreatePopover: $showLabelPopover, onDropTask: { tid in
                        draftName = suggestNameForTask(tid) ?? "New Label"
                        draftColor = nextDistinctColor()
                        editingLabelId = nil
                    })
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.12), location: 0.0),
                        .init(color: Color.clear, location: 1.0)
                    ]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
                    Spacer()
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.black.opacity(0.12), location: 1.0)
                    ]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
                }
                .allowsHitTesting(false)
                KeyboardCatcher(onLeft: { moveChipFocus(-1) }, onRight: { moveChipFocus(1) }, onToggle: { toggleFocusChip() })
                    .frame(width: 0, height: 0)
            }
            .popover(isPresented: $showLabelPopover) { LabelEditorPopover(name: $draftName, color: $draftColor, mode: editingLabelId == nil ? .create : .edit, onSubmit: {
                submitLabelEdit()
            }, onCancel: { showLabelPopover = false }) }

            Spacer(minLength: 0)

            Button(action: { onRequestDeleteSelected() }) {
                Image(systemName: "trash")
            }
            .help("Delete selected task")
            .disabled(!hasSelectedTask)

            Button(action: { onRequestClearCompleted() }) {
                SwiftUI.Label("Clear Completed…", systemImage: "trash.slash")
            }
            .help("Delete completed tasks in current scope")

            Button(action: { onToggleMatrix(); didSeeMatrixCoachmark = true; showCoachmark = false }) {
                if isMatrixOpen {
                    SwiftUI.Label("Close Matrix", systemImage: "xmark.square")
                        .tint(.accentColor)
                } else {
                    SwiftUI.Label("Matrix", systemImage: "square.grid.2x2")
                }
            }
            .help(isMatrixOpen ? "Close priority matrix (⌘⇧M)" : "Open priority matrix (⌘⇧M)")
            .controlSize(.small)
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Menu {
                Button("設定…") { _ = PreferencesLauncher.open() }
                Divider()
                Button("DODO2 を終了") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle").imageScale(.large)
            }
            .help("その他")
            .buttonStyle(.plain)
            .accessibilityLabel("その他メニュー")

            // Density menu removed to reduce crowding
            .popover(isPresented: $showCoachmark, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority Matrix")
                        .font(.headline)
                    Text("View tasks by Urgent × Important. You can also drag between quadrants.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(width: 260)
            }

            SearchField(text: $searchText)
                .frame(width: 220)
                .accessibilityLabel(Text("Search"))
                .accessibilityHint(Text("Type to filter tasks by title"))
        }
        .onAppear {
            if !didSeeMatrixCoachmark {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showCoachmark = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { showCoachmark = false; didSeeMatrixCoachmark = true }
            }
        }
        .padding(.horizontal, BrandTokens.gutter)
        .frame(height: BrandTokens.headerHeight)
        .onReceive(NotificationCenter.default.publisher(for: .focusQuickAdd)) { _ in
            // Forward to QuickAddField via internal notification
            NotificationCenter.default.post(name: ._internalFocusQuickAddNow, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            // handled inside SearchField via coordinator
            NotificationCenter.default.post(name: ._internalFocusSearchNow, object: nil)
        }
    }

    private func commitQuickAdd() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCommitQuickAdd(trimmed)
        quickAddText = ""
        // Keep focus
        quickAddFocused = true
    }

    private func toggleLabel(_ id: String) {
        if selectedLabels.contains(id) {
            selectedLabels.remove(id)
        } else {
            selectedLabels.insert(id)
        }
    }

    private enum EditMode { case create, rename, color, edit }
    private func beginEdit(labelId: String, mode: EditMode) {
        if let idx = labels.firstIndex(where: { $0.id == labelId }) {
            draftName = labels[idx].name
            draftColor = labels[idx].color
            editingLabelId = labels[idx].id
            showLabelPopover = true
        }
    }

    private func submitLabelEdit() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { showLabelPopover = false; return }
        if let id = editingLabelId, let idx = labels.firstIndex(where: { $0.id == id }) {
            labels[idx].name = String(name.prefix(24))
            labels[idx].color = draftColor
        } else {
            let newId = UUID().uuidString
            let ord = labels.count
            let newLabel = Label(id: newId, name: String(name.prefix(24)), color: draftColor, order: ord)
            labels.append(newLabel)
        }
        showLabelPopover = false
        editingLabelId = nil
    }

    private func deleteLabel(_ label: Label) {
        let count = counts[label.id] ?? 0
        let alert = NSAlert()
        alert.messageText = "Delete ‘\(label.name)’?"
        alert.informativeText = "\(count) tasks use this label. They will be reassigned."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let fallback = labels.first(where: { $0.id == "general" && $0.id != label.id })?.id ?? labels.first(where: { $0.id != label.id })?.id ?? label.id
            reassignTasksFromDeletedLabel(label.id, fallback)
            labels.removeAll { $0.id == label.id }
            for i in labels.indices { labels[i].order = i }
        }
    }

    private func moveLabel(id draggedId: String, toBefore targetId: String) {
        guard let from = labels.firstIndex(where: { $0.id == draggedId }), let to = labels.firstIndex(where: { $0.id == targetId }) else { return }
        var copy = labels
        let item = copy.remove(at: from)
        copy.insert(item, at: to)
        for i in copy.indices { copy[i].order = i }
        labels = copy
    }

    private func nextDistinctColor() -> BrandColor {
        let used = Set(labels.map { $0.color })
        if let c = BrandColor.allCases.first(where: { !used.contains($0) }) { return c }
        return BrandColor.allCases.randomElement() ?? .gray
    }

    private func moveChipFocus(_ delta: Int) {
        guard !labels.isEmpty else { chipFocusIndex = nil; return }
        let current = chipFocusIndex ?? 0
        var next = current + delta
        next = min(max(0, next), labels.count - 1)
        chipFocusIndex = next
    }

    private func toggleFocusChip() {
        guard let idx = chipFocusIndex, labels.indices.contains(idx) else { return }
        toggleLabel(labels[idx].id)
    }
}

// NSSearchField wrapper
struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let v = FocusableSearchField()
        v.placeholderString = "Search"
        v.isEnabled = true
        v.delegate = context.coordinator
        context.coordinator.field = v
        NotificationCenter.default.addObserver(forName: ._internalFocusSearchNow, object: nil, queue: .main) { [weak v] _ in
            v?.window?.makeFirstResponder(v)
        }
        return v
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let owner: SearchField
        weak var field: NSSearchField?
        init(_ owner: SearchField) { self.owner = owner }
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                owner.text = field.stringValue
            }
        }
    }
}

final class FocusableSearchField: NSSearchField {
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { super.becomeFirstResponder() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

// Chip view that is both a toggle button and a drop target
private struct DropChip: View {
    let spec: Label
    let isSelected: Bool
    let isFocused: Bool
    let count: Int
    let onTap: () -> Void
    let onDropTask: (UUID) -> Void

    @State private var isTargeted: Bool = false
    @State private var countAnim: Bool = false
    @State private var hovering: Bool = false

    init(spec: Label, isSelected: Bool, isFocused: Bool, count: Int, onTap: @escaping () -> Void, onDropTask: @escaping (UUID) -> Void) {
        self.spec = spec
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.count = count
        self.onTap = onTap
        self.onDropTask = onDropTask
    }

    var body: some View {
        Button(action: { onTap() }) {
            HStack(spacing: 6) {
                Circle().fill(spec.color.color).frame(width: 8, height: 8)
                Text(spec.name)
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BrandTokens.countBadgeBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
                    .foregroundColor(.secondary)
                    .scaleEffect(countAnim ? 1.06 : 1.0)
                    .opacity(countAnim ? 0.95 : 1.0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(backgroundColor)
            )
            .overlay(
                Capsule().stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onChange(of: count) { _ in
            withAnimation(.easeInOut(duration: 0.12)) { countAnim = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.easeInOut(duration: 0.12)) { countAnim = false }
            }
        }
        .onDrop(of: ["public.text"], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { (obj, _) in
                guard let s = obj as? NSString, let id = DragDropPayload.taskId(from: s as String) else { return }
                DispatchQueue.main.async {
                    onDropTask(id)
                }
            }
            return true
        }
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Filter: \(spec.name), \(count) items"))
        .accessibilityValue(Text(isSelected ? "selected" : "not selected"))
        .accessibilityHint(Text("Drop to set label \(spec.name)"))
    }

    private var backgroundColor: Color {
        if isTargeted { return spec.color.color.opacity(0.25) }
        if isSelected { return BrandTokens.chipSelectedFill }
        return hovering ? BrandTokens.chipHoverBackground : BrandTokens.chipBackground
    }
    private var borderColor: Color { isFocused ? BrandTokens.chipSelectedStroke : (isSelected ? BrandTokens.chipSelectedStroke : .clear) }
}

// Custom Quick Add field using NSTextField for placeholder contrast and caret color
private struct QuickAddField: NSViewRepresentable {
    @Binding var text: String
    let onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = QuickAddTextField()
        tf.placeholderAttributedString = NSAttributedString(
            string: "Quick add a task…",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        tf.font = NSFont.systemFont(ofSize: 16)
        tf.isBordered = true
        tf.focusRingType = .default
        tf.bezelStyle = .roundedBezel
        tf.delegate = context.coordinator
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 1
        tf.isEditable = true
        tf.isSelectable = true
        tf.backgroundColor = .clear
        tf.textColor = NSColor.labelColor
        if let editor = tf.currentEditor() as? NSTextView {
            editor.insertionPointColor = NSColor.labelColor
        }
        NotificationCenter.default.addObserver(forName: ._internalFocusQuickAddNow, object: nil, queue: .main) { [weak tf] _ in
            tf?.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let owner: QuickAddField
        init(_ owner: QuickAddField) { self.owner = owner }
        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField { owner.text = tf.stringValue }
        }
        func controlTextDidEndEditing(_ obj: Notification) { /* noop */ }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                owner.onCommit()
                return true
            }
            return false
        }
    }
}

final class QuickAddTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { super.becomeFirstResponder() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

private struct LabelEditorPopover: View {
    @Binding var name: String
    @Binding var color: BrandColor
    enum Mode { case create, edit }
    let mode: Mode
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .create ? "Create Label" : "Edit Label").font(.headline)
            TextField("Label name", text: $name)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { onSubmit() }
                .onChange(of: name) { newValue in
                    if newValue.count > 24 { name = String(newValue.prefix(24)) }
                }
            HStack { Text("Color"); Spacer() }
            FlowLayout(data: BrandColor.allCases, spacing: 8) { c in
                Circle().fill(c.color).frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.primary.opacity(color == c ? 0.8 : 0), lineWidth: 2))
                    .onTapGesture { color = c }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(mode == .create ? "Create" : "Save", action: onSubmit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear { nameFocused = true }
        .padding(16)
        .frame(width: 280)
    }
}

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    init(data: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.spacing = spacing; self.content = content
    }
    var body: some View {
        var w = CGFloat.zero
        var h = CGFloat.zero
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(data), id: \.self) { item in
                    content(item)
                        .padding(.trailing, spacing)
                        .alignmentGuide(.leading) { d in
                            if abs(w - d.width) > geo.size.width { w = 0; h -= d.height + spacing }
                            let result = w
                            if item == data.first { w = 0 } else { w -= d.width + spacing }
                            return result
                        }
                        .alignmentGuide(.top) { _ in h }
                }
            }
        }.frame(height: 28)
    }
}

private struct PlusChip: View {
    @Binding var showCreatePopover: Bool
    var onDropTask: (UUID) -> Void
    @State private var isTargeted = false
    var body: some View {
        Button(action: { showCreatePopover = true }) {
            Image(systemName: "plus")
                .padding(6)
                .background(Capsule().fill(isTargeted ? BrandTokens.chipHoverBackground : BrandTokens.chipBackground))
        }
        .buttonStyle(.plain)
        .onDrop(of: ["public.text"], isTargeted: $isTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: NSString.self) { (obj, _) in
                guard let s = obj as? NSString, let id = DragDropPayload.taskId(from: s as String) else { return }
                DispatchQueue.main.async {
                    onDropTask(id)
                    showCreatePopover = true
                }
            }
            return true
        }
    }
}

private struct KeyboardCatcher: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onToggle: () -> Void
    func makeNSView(context: Context) -> NSView { KeyView(onLeft: onLeft, onRight: onRight, onToggle: onToggle) }
    func updateNSView(_ nsView: NSView, context: Context) {}
    final class KeyView: NSView {
        let onLeft: () -> Void; let onRight: () -> Void; let onToggle: () -> Void
        init(onLeft: @escaping () -> Void, onRight: @escaping () -> Void, onToggle: @escaping () -> Void) { self.onLeft = onLeft; self.onRight = onRight; self.onToggle = onToggle; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var acceptsFirstResponder: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { return nil }
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: onLeft() // left
            case 124: onRight() // right
            case 36, 49: onToggle() // return/space
            default: break
            }
        }
    }
}
