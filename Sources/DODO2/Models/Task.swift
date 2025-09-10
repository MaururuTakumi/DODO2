import SwiftUI

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var done: Bool
    var labelId: String
    // Priority matrix fields (0...3, >=2 == High). Default Low=1.
    var urgency: Int = 1
    var importance: Int = 1
    var createdAt: Date = .init()
    var updatedAt: Date = .init()

    init(id: UUID = UUID(), title: String, done: Bool = false, labelId: String = "general", urgency: Int = 1, importance: Int = 1, createdAt: Date = .init(), updatedAt: Date = .init()) {
        self.id = id
        self.title = title
        self.done = done
        self.labelId = labelId
        self.urgency = max(0, min(3, urgency))
        self.importance = max(0, min(3, importance))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Quadrant mapping for tasks
extension Task {
    var quadrant: Quadrant {
        switch (importance >= 2, urgency >= 2) {
        case (true,  true):  return .doFirst
        case (true,  false): return .schedule
        case (false, true):  return .delegate
        default:             return .eliminate
        }
    }

    func updating(urgency: Int? = nil, importance: Int? = nil) -> Task {
        var copy = self
        if let u = urgency { copy.urgency = max(0, min(3, u)) }
        if let i = importance { copy.importance = max(0, min(3, i)) }
        copy.updatedAt = .init()
        return copy
    }
}
