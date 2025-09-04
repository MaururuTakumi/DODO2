import SwiftUI

struct BottomSheetRoot: View {
    @State private var tasks: [Task]
    @State private var labels: [Label]
    @State private var searchText: String = ""
    @State private var quickAddText: String = ""
    @State private var selectedLabels: Set<String> = [] // label ids
    @State private var selectedTaskId: UUID? = nil

    private let onRequestClose: () -> Void

    init(onRequestClose: @escaping () -> Void) {
        let store = Persistence.load()
        self._tasks = State(initialValue: store.tasks)
        self._labels = State(initialValue: store.labels)
        self.onRequestClose = onRequestClose
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                quickAddText: $quickAddText,
                searchText: $searchText,
                labels: $labels,
                selectedLabels: $selectedLabels,
                onCommitQuickAdd: addTask,
                onAssignLabelToTaskId: assignLabel(taskId:labelId:),
                counts: countsByLabel(),
                suggestNameForTask: { tid in
                    tasks.first(where: { $0.id == tid })?.title.split(separator: " ").first.map { String($0).capitalized }
                },
                reassignTasksFromDeletedLabel: { deletedId, fallbackId in
                    for i in tasks.indices { if tasks[i].labelId == deletedId { tasks[i].labelId = fallbackId } }
                }
            )
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(filteredTasks()) { task in
                        let label = labels.first(where: { $0.id == task.labelId })
                        TaskCardView(task: task, label: label, toggleDone: toggleDone(_:))
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
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelection)) { _ in
            deleteSelectedWithConfirm()
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

    private func deleteSelectedWithConfirm() {
        guard let sel = selectedTaskId, let idx = tasks.firstIndex(where: { $0.id == sel }) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete task?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let nextIndex = min(idx, tasks.count - 2)
            tasks.remove(at: idx)
            if tasks.indices.contains(nextIndex) { selectedTaskId = tasks[nextIndex].id } else { selectedTaskId = nil }
        }
    }
}
