import Foundation

enum TaskPersistence {
    private static var appSupportDir: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "DODO2"
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private static var fileURL: URL { appSupportDir.appendingPathComponent("tasks.json") }

    static func load() -> [TaskItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([TaskItem].self, from: data)) ?? []
    }

    static func save(_ items: [TaskItem]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

