import SwiftUI
import UniformTypeIdentifiers

struct PriorityMatrixView: View {
    @State private var items: [TaskItem] = []
    @State private var filter: MatrixFilter = .all

    var body: some View {
        VStack(spacing: 12) {
            header
            content
        }
        .padding()
        .onAppear { load() }
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 12) {
            Text("Urgency × Importance").font(.title2).bold()
            Spacer()
            // counts
            HStack(spacing: 8) {
                countChip("Do First", counts[.doFirst] ?? 0)
                countChip("Schedule", counts[.schedule] ?? 0)
                countChip("Delegate", counts[.delegate] ?? 0)
                countChip("Eliminate", counts[.eliminate] ?? 0)
            }.font(.caption)

            Picker("Filter", selection: $filter) {
                ForEach(MatrixFilter.allCases) { f in
                    Text(f.title).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            Button("New Task") { createDummy() }
        }
    }

    private func countChip(_ title: String, _ n: Int) -> some View {
        Text("\(title): \(n)")
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Content
    @ViewBuilder
    private var content: some View {
        if let q = filter.quadrant {
            quadrantColumn(q, title: q.title)
        } else {
            let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                quadrantColumn(.doFirst,   title: "Do First")
                quadrantColumn(.schedule,  title: "Schedule")
                quadrantColumn(.delegate,  title: "Delegate")
                quadrantColumn(.eliminate, title: "Eliminate")
            }
        }
    }

    @ViewBuilder
    private func quadrantColumn(_ q: Quadrant, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(sortedItems(in: q)) { item in
                        TaskCard(
                            item: item,
                            onToggleImportant: { toggleImportant(item) },
                            onToggleUrgent: { toggleUrgent(item) }
                        )
                        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            handleDrop(into: q, providers: providers)
        }
    }

    private func sortedItems(in q: Quadrant) -> [TaskItem] {
        items.filter { $0.quadrant == q }.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: D&D
    @discardableResult
    private func handleDrop(into q: Quadrant, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first,
              provider.canLoadObject(ofClass: NSString.self) else { return false }

        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let idStr = (obj as? NSString) as String?,
                  let uuid = UUID(uuidString: idStr),
                  let idx = items.firstIndex(where: { $0.id == uuid })
            else { return }

            let (i, u): (Int, Int) = {
                switch q {
                case .doFirst:   return (3,3)
                case .schedule:  return (3,1)
                case .delegate:  return (1,3)
                case .eliminate: return (1,1)
                }
            }()

            DispatchQueue.main.async {
                items[idx] = items[idx].updating(urgency: u, importance: i)
                save()
            }
        }
        return true
    }

    // MARK: Toggle Actions (binary → levels)
    private func isImportant(_ item: TaskItem) -> Bool { item.importance >= 2 }
    private func isUrgent(_ item: TaskItem) -> Bool { item.urgency >= 2 }

    private func toggleImportant(_ item: TaskItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        let newVal = isImportant(item) ? 1 : 3
        items[idx] = items[idx].updating(importance: newVal)
        save()
    }

    private func toggleUrgent(_ item: TaskItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        let newVal = isUrgent(item) ? 1 : 3
        items[idx] = items[idx].updating(urgency: newVal)
        save()
    }

    // MARK: Persistence
    private func load() { items = TaskPersistence.load() }
    private func save() { TaskPersistence.save(items) }

    // MARK: Sample
    private func createDummy() {
        items.append(TaskItem(title: "New Task", notes: nil, urgency: 1, importance: 1))
        save()
    }

    // counts
    private var counts: [Quadrant: Int] {
        Dictionary(grouping: items, by: \.quadrant).mapValues(\.count)
    }
}

private struct TaskCard: View {
    let item: TaskItem
    var onToggleImportant: () -> Void
    var onToggleUrgent: () -> Void

    private var importantActive: Bool { item.importance >= 2 }
    private var urgentActive: Bool { item.urgency >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title).font(.subheadline).bold()
            HStack(spacing: 8) {
                PillButton(active: importantActive, label: "Important", systemImage: "star.fill", action: onToggleImportant)
                PillButton(active: urgentActive, label: "Urgent", systemImage: "bolt.fill", action: onToggleUrgent)
                Spacer()
                Text("I:\(item.importance)  U:\(item.urgency)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PillButton: View {
    var active: Bool
    var label: String
    var systemImage: String?
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            SwiftUI.Label(label, systemImage: systemImage ?? "circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background((active ? Color.accentColor.opacity(0.20) : Color.gray.opacity(0.15)))
        .overlay(Capsule().stroke(active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Filter helper
private enum MatrixFilter: String, CaseIterable, Identifiable {
    case all, doFirst, schedule, delegate, eliminate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .doFirst: return "Do First"
        case .schedule: return "Schedule"
        case .delegate: return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }
    var quadrant: Quadrant? {
        switch self {
        case .all: return nil
        case .doFirst: return .doFirst
        case .schedule: return .schedule
        case .delegate: return .delegate
        case .eliminate: return .eliminate
        }
    }
}

private extension Quadrant {
    var title: String {
        switch self {
        case .doFirst: return "Do First"
        case .schedule: return "Schedule"
        case .delegate: return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }
}
