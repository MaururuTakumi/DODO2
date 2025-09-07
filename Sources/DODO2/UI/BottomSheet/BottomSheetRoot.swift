import SwiftUI
import AppKit

struct BottomSheetRoot: View {
    @State private var tasks: [Task]
    @State private var labels: [Label]
    @State private var searchText: String = ""
    @State private var quickAddText: String = ""
    @State private var selectedLabels: Set<String> = [] // label ids
    @State private var selectedTaskId: UUID? = nil
    @State private var showUndo: Bool = false
    @State private var lastDeleted: (task: Task, index: Int)? = nil
    @State private var lastBulkDeletedCount: Int? = nil
    @State private var lastClearSnapshot: [Task]? = nil
    @State private var showClearConfirm: Bool = false
    @State private var clearTargetCount: Int = 0
    @State private var clearScopeTitle: String = "all labels"
    @State private var isMatrixPresented: Bool = false
    @State private var toast: HUDToastState? = nil

    private let onRequestClose: () -> Void

    init(onRequestClose: @escaping () -> Void) {
        let store = Persistence.load()
        self._tasks = State(initialValue: store.tasks)
        self._labels = State(initialValue: store.labels)
        self.onRequestClose = onRequestClose
    }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            HeaderBar(
                quickAddText: $quickAddText,
                searchText: $searchText,
                labels: $labels,
                selectedLabels: $selectedLabels,
                onCommitQuickAdd: addTask,
                onAssignLabelToTaskId: assignLabel(taskId:labelId:),
                onRequestClearCompleted: { prepareClearCompleted() },
                onRequestDeleteSelected: {
                    if let sel = selectedTaskId { deleteTask(id: sel) }
                },
                hasSelectedTask: selectedTaskId != nil,
                counts: countsByLabel(),
                suggestNameForTask: { tid in
                    tasks.first(where: { $0.id == tid })?.title.split(separator: " ").first.map { String($0).capitalized }
                },
                reassignTasksFromDeletedLabel: { deletedId, fallbackId in
                    for i in tasks.indices { if tasks[i].labelId == deletedId { tasks[i].labelId = fallbackId } }
                },
                isMatrixOpen: isMatrixPresented,
                onToggleMatrix: { isMatrixPresented.toggle() }
            )
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(filteredTasks()) { task in
                        let label = labels.first(where: { $0.id == task.labelId })
                        TaskCardView(task: task, label: label, toggleDone: toggleDone(_:), onRequestDelete: {
                            deleteTask(id: task.id)
                        }, onToggleImportant: { _ in toggleImportant(task) }, onToggleUrgent: { _ in toggleUrgent(task) })
                            .contentShape(RoundedRectangle(cornerRadius: BrandTokens.cornerRadius, style: .continuous))
                            .onTapGesture { selectedTaskId = task.id }
                            .overlay(
                                RoundedRectangle(cornerRadius: BrandTokens.cornerRadius, style: .continuous)
                                    .stroke(selectedTaskId == task.id ? Color.accentColor.opacity(0.8) : Color.clear, lineWidth: 2)
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, BrandTokens.gutter)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.18), value: tasks)
            }
            if showUndo {
                HStack(spacing: 12) {
                    Text("Task deleted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Undo") {
                        undoLastDelete()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 8)
            }
            if let n = lastBulkDeletedCount, n > 0 {
                HStack(spacing: 12) {
                    Text("Deleted \(n) completed")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("Undo") {
                        undoLastClearCompleted()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 6)
            }
        }
        // Overlay/scrim
        if isMatrixPresented {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { isMatrixPresented = false } }
                .zIndex(9)
            MatrixOverlayView(items: $tasks, onClose: { withAnimation(.easeOut(duration: 0.15)) { isMatrixPresented = false } })
                .hudToast($toast)
                .transition(.scale.combined(with: .opacity))
                .zIndex(10)
        }
        }
        .withBoardEnvironment()
        .onChange(of: tasks) { _ in saveStore() }
        .onChange(of: labels) { _ in saveStore() }
        .onExitCommand(perform: onRequestClose)
        .onReceive(NotificationCenter.default.publisher(for: .labelsDidChange)) { note in
            if let updated = note.object as? [Label] { labels = updated }
        }
        .onReceive(NotificationCenter.default.publisher(for: .assignLabelIndex)) { note in
            guard let idx = note.userInfo?["index"] as? Int, let sel = selectedTaskId else { return }
            let index = idx - 1
            guard labels.indices.contains(index) else { return }
            assignLabel(taskId: sel, labelId: labels[index].id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateSelection)) { note in
            guard let dir = note.userInfo?["dir"] as? Int else { return }
            moveSelection(by: dir)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleImportantSelected)) { _ in
            if let sel = selectedTaskId, let t = tasks.first(where: {$0.id == sel}) { toggleImportant(t) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleUrgentSelected)) { _ in
            if let sel = selectedTaskId, let t = tasks.first(where: {$0.id == sel}) { toggleUrgent(t) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMatrixOverlay)) { _ in
            isMatrixPresented.toggle()
        }
        .hudToast($toast)
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelection)) { _ in
            if let sel = selectedTaskId { deleteTask(id: sel) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestDeleteSelected)) { _ in
            if let sel = selectedTaskId { deleteTask(id: sel) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestUndoDelete)) { _ in
            undoLastDelete()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestDeleteCompleted)) { _ in
            prepareClearCompleted()
        }
        .alert("Delete completed tasks?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let removed = performClearCompleted()
                if removed > 0 {
                    withAnimation { lastBulkDeletedCount = removed }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { lastBulkDeletedCount = nil } }
                }
            }
        } message: {
            Text("This will delete \(clearTargetCount) completed task(s) in \(clearScopeTitle). This cannot be easily undone.")
        }
    }

    private func saveStore() {
        Persistence.save(Store(tasks: tasks, labels: labels))
    }

    private func addTask(_ input: String) {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var chosenLabelId = selectedLabels.first ?? (labels.first?.id ?? "general")
        if let hashIndex = title.lastIndex(of: "#") {
            let after = title[hashIndex...]
            let parts = after.split(separator: "#")
            if let name = parts.last, !name.isEmpty {
                let labelName = name.trimmingCharacters(in: .whitespaces)
                if let match = labels.first(where: { $0.name.compare(labelName, options: .caseInsensitive) == .orderedSame }) {
                    chosenLabelId = match.id
                    title.removeSubrange(hashIndex..<title.endIndex)
                    title = title.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        let newTask = Task(title: title, done: false, labelId: chosenLabelId)
        tasks.insert(newTask, at: 0)
        selectedTaskId = newTask.id
        NSLog("[DODO2] Added task: %@", title)
    }

    private func assignLabel(taskId: UUID, labelId: String) {
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].labelId = labelId
        }
    }

    private func toggleDone(_ task: Task) {
        if let idx = tasks.firstIndex(of: task) {
            tasks[idx].done.toggle()
        }
    }

    private func toggleImportant(_ task: Task) {
        if let idx = tasks.firstIndex(of: task) {
            let newVal = tasks[idx].importance >= 2 ? 1 : 3
            tasks[idx] = tasks[idx].updating(importance: newVal)
            showTransientFeedback(for: tasks[idx])
        }
    }

    private func toggleUrgent(_ task: Task) {
        if let idx = tasks.firstIndex(of: task) {
            let newVal = tasks[idx].urgency >= 2 ? 1 : 3
            tasks[idx] = tasks[idx].updating(urgency: newVal)
            showTransientFeedback(for: tasks[idx])
        }
    }

    private func showTransientFeedback(for task: Task) {
        let q = task.quadrant
        let msg: String
        switch q {
        case .doFirst: msg = "Moved to Do First"
        case .schedule: msg = "Moved to Schedule"
        case .delegate: msg = "Moved to Delegate"
        case .eliminate: msg = "Moved to Eliminate"
        }
        withAnimation { toast = HUDToastState(message: msg) }
    }

    private func filteredTasks() -> [Task] {
        tasks.filter { t in
            let matchesLabel = selectedLabels.isEmpty || selectedLabels.contains(t.labelId)
            let matchesSearch = searchText.isEmpty || t.title.localizedCaseInsensitiveContains(searchText)
            return matchesLabel && matchesSearch
        }
    }

    private func countsByLabel() -> [String: Int] {
        var dict: [String: Int] = [:]
        for t in tasks { dict[t.labelId, default: 0] += 1 }
        return dict
    }

    private func moveSelection(by delta: Int) {
        let visible = filteredTasks()
        guard !visible.isEmpty else { return }
        let currentIndex = selectedTaskId.flatMap { id in visible.firstIndex(where: { $0.id == id }) } ?? 0
        let newIndex = min(max(0, currentIndex + delta), visible.count - 1)
        selectedTaskId = visible[newIndex].id
    }

    private func deleteTask(id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let removed = tasks.remove(at: idx)
        lastDeleted = (task: removed, index: idx)
        // adjust selection
        if tasks.indices.contains(idx) { selectedTaskId = tasks[idx].id } else { selectedTaskId = nil }
        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndo = false }
        }
    }

    private func undoLastDelete() {
        guard let l = lastDeleted else { return }
        let insertAt = min(l.index, tasks.count)
        tasks.insert(l.task, at: insertAt)
        selectedTaskId = l.task.id
        lastDeleted = nil
    }

    private func currentScopePredicate() -> (Task) -> Bool {
        if selectedLabels.isEmpty { return { _ in true } }
        let set = selectedLabels
        return { task in set.contains(task.labelId) }
    }

    private func currentScopeTitleText() -> String {
        if selectedLabels.isEmpty { return "all labels" }
        if selectedLabels.count == 1, let id = selectedLabels.first, let name = labels.first(where: { $0.id == id })?.name {
            return "\u{201C}\(name)\u{201D}"
        }
        return "selected labels"
    }

    private func prepareClearCompleted() {
        let predicate = currentScopePredicate()
        clearTargetCount = tasks.filter { $0.done && predicate($0) }.count
        clearScopeTitle = currentScopeTitleText()
        if clearTargetCount > 0 {
            showClearConfirm = true
        } else {
            NSSound.beep()
        }
    }

    @discardableResult
    private func performClearCompleted() -> Int {
        let predicate = currentScopePredicate()
        let before = tasks
        let removed = before.filter { $0.done && predicate($0) }.count
        guard removed > 0 else { return 0 }
        lastClearSnapshot = before
        tasks.removeAll { $0.done && predicate($0) }
        saveStore()
        return removed
    }

    private func undoLastClearCompleted() {
        guard let snap = lastClearSnapshot else { return }
        tasks = snap
        lastClearSnapshot = nil
        saveStore()
    }
}
