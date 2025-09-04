import Foundation

enum DragDropPayload {
    static func taskId(from string: String) -> UUID? {
        guard string.hasPrefix("task:") else { return nil }
        return UUID(uuidString: String(string.dropFirst(5)))
    }
}

