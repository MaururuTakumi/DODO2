import SwiftUI

struct Label: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: BrandColor
    var order: Int = 0

    enum CodingKeys: String, CodingKey { case id, name, color, order }
}
