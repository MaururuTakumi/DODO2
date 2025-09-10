import Foundation

enum Quadrant: String, Codable, CaseIterable, Hashable {
    case doFirst, schedule, delegate, eliminate
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var title: String
    var notes: String?
    var urgency: Int   // 0...3 (>=2 = High)
    var importance: Int // 0...3 (>=2 = High)
    var createdAt: Date = .init()
    var updatedAt: Date = .init()

    var quadrant: Quadrant {
        switch (importance >= 2, urgency >= 2) {
        case (true,  true):  return .doFirst
        case (true,  false): return .schedule
        case (false, true):  return .delegate
        default:             return .eliminate
        }
    }

    func updating(urgency: Int? = nil, importance: Int? = nil) -> TaskItem {
        var copy = self
        if let u = urgency { copy.urgency = max(0, min(3, u)) }
        if let i = importance { copy.importance = max(0, min(3, i)) }
        copy.updatedAt = .init()
        return copy
    }
}

