import Foundation

struct Store: Codable {
    var tasks: [Task]
    var labels: [Label]
    var settings: SettingsModel?
    var schemaVersion: Int?
}

enum Persistence {
    static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("DODO2/store.json")
    }()

    private static let queue = DispatchQueue(label: "com.example.DODO2.persistence", qos: .utility)
    private static var pendingWorkItem: DispatchWorkItem?

    static func load() -> Store {
        ensureParentDir()
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var store = try decoder.decode(Store.self, from: data)
            if store.settings == nil { store.settings = SettingsModel.defaults }
            migrate(&store)
            return store
        } catch {
            let seeded = defaultStore()
            save(seeded, immediate: true)
            return seeded
        }
    }

    static func save(_ store: Store, immediate: Bool = false) {
        ensureParentDir()
        let work = DispatchWorkItem {
            do {
                let data = try JSONEncoder().encode(store)
                try data.write(to: url, options: [.atomic])
                NSLog("[DODO2] Store saved (%d tasks, %d labels)", store.tasks.count, store.labels.count)
            } catch {
                NSLog("[DODO2][ERR] Failed to save store: %@", error.localizedDescription)
            }
        }
        queue.sync {
            pendingWorkItem?.cancel()
            if immediate {
                work.perform()
                pendingWorkItem = nil
            } else {
                pendingWorkItem = work
                queue.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
        }
    }

    static func flush() {
        queue.sync {
            pendingWorkItem?.perform()
            pendingWorkItem = nil
        }
    }

    private static func ensureParentDir() {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private static func defaultStore() -> Store {
        let defaultLabels: [Label] = [
            Label(id: "general", name: "General", color: .gray, order: 0),
            Label(id: "work", name: "Work", color: .blue, order: 1),
            Label(id: "personal", name: "Personal", color: .pink, order: 2),
            Label(id: "ideas", name: "Ideas", color: .purple, order: 3),
            Label(id: "errands", name: "Errands", color: .orange, order: 4)
        ]
        let tasks: [Task] = [
            Task(title: "Sketch bottom sheet layout", done: false, labelId: "work"),
            Task(title: "Write Quick Add logic", done: false, labelId: "work"),
            Task(title: "Test hotkeys ⌘⌥Space", done: false, labelId: "general"),
            Task(title: "Grocery list", done: true, labelId: "errands"),
            Task(title: "Vacation plans", done: false, labelId: "personal"),
            Task(title: "Feature ideas backlog", done: false, labelId: "ideas")
        ]
        return Store(tasks: tasks, labels: defaultLabels, settings: SettingsModel.defaults, schemaVersion: 1)
    }

    private static func migrate(_ store: inout Store) {
        // Assign order if missing
        var changed = false
        if store.labels.enumerated().contains(where: { $0.element.order == 0 && $0.offset != 0 }) || store.labels.allSatisfy({ $0.order == 0 }) {
            for (idx, var l) in store.labels.enumerated() {
                l.order = idx
                store.labels[idx] = l
            }
            changed = true
        }
        // Normalize order consistency
        let sorted = store.labels.sorted(by: { $0.order < $1.order })
        if sorted.map({$0.id}) != store.labels.map({$0.id}) {
            store.labels = sorted
            changed = true
        }
        if store.schemaVersion == nil { store.schemaVersion = 1; changed = true }
        if changed { save(store, immediate: true) }
    }
}
