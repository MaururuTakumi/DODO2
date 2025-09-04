import SwiftUI

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var done: Bool
    var labelId: String

    init(id: UUID = UUID(), title: String, done: Bool = false, labelId: String = "general") {
        self.id = id
        self.title = title
        self.done = done
        self.labelId = labelId
    }
}
