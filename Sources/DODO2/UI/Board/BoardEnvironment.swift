import SwiftUI

struct BoardEnvironment: ViewModifier {
    @AppStorage("cardDensity") private var densityRaw: String = CardDensity.comfy.rawValue
    private var density: CardDensity { CardDensity(rawValue: densityRaw) ?? .comfy }
    func body(content: Content) -> some View {
        content.environment(\.cardMetrics, CardMetrics.for(density))
    }
}

extension View {
    func withBoardEnvironment() -> some View { modifier(BoardEnvironment()) }
}

