import SwiftUI

enum CardDensity: String, CaseIterable, Identifiable, Codable {
    case compact, comfy, spacious
    var id: String { rawValue }
    var title: String {
        switch self { case .compact: "Compact"; case .comfy: "Comfy"; case .spacious: "Spacious" }
    }
}

struct CardMetrics: Equatable {
    let height: CGFloat      // unified card height
    let corner: CGFloat
    let vPad: CGFloat
    let hPad: CGFloat
    let controlSize: ControlSize

    static func `for`(_ d: CardDensity) -> CardMetrics {
        switch d {
        case .compact:  return .init(height: 112, corner: 14, vPad: 8,  hPad: 12, controlSize: .mini)
        case .comfy:    return .init(height: 132, corner: 16, vPad: 10, hPad: 14, controlSize: .small)
        case .spacious: return .init(height: 156, corner: 18, vPad: 12, hPad: 16, controlSize: .regular)
        }
    }
}

extension EnvironmentValues {
    private struct CardMetricsKey: EnvironmentKey { static let defaultValue = CardMetrics.for(.comfy) }
    var cardMetrics: CardMetrics {
        get { self[CardMetricsKey.self] }
        set { self[CardMetricsKey.self] = newValue }
    }
}

