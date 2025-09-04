import SwiftUI

enum BrandTokens {
    static let gutter: CGFloat = 16
    static let cornerRadius: CGFloat = 14
    static let chipRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 8
    static let headerHeight: CGFloat = 56

    static let titleFont: Font = .system(size: 16, weight: .semibold)
    static let bodyFont: Font = .system(size: 14)

    // Chip visuals
    static let chipBackground: Color = Color.secondary.opacity(0.12)
    static let chipHoverBackground: Color = Color.secondary.opacity(0.18)
    static let chipSelectedFill: Color = Color.accentColor.opacity(0.25)
    static let chipSelectedStroke: Color = Color.accentColor
    static let countBadgeBackground: Color = Color(nsColor: .windowBackgroundColor).opacity(0.8)
}

enum BrandColor: String, Codable, CaseIterable {
    case gray, blue, pink, purple, orange, green, red, teal, indigo

    var nsColor: NSColor {
        switch self {
        case .gray: return .systemGray
        case .blue: return .systemBlue
        case .pink: return .systemPink
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        case .green: return .systemGreen
        case .red: return .systemRed
        case .teal: return .systemTeal
        case .indigo: return NSColor.systemIndigo
        }
    }

    var color: Color { Color(nsColor) }
}
