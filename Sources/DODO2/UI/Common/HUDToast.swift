import SwiftUI

struct HUDToastState: Identifiable, Equatable {
    let id = UUID()
    var message: String
}

struct HUDToast: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.75), in: Capsule())
            .shadow(radius: 6)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct HUDToastModifier: ViewModifier {
    @Binding var state: HUDToastState?
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let s = state {
                HUDToast(message: s.message)
                    .padding(.bottom, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { state = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state)
    }
}

extension View {
    func hudToast(_ state: Binding<HUDToastState?>) -> some View {
        self.modifier(HUDToastModifier(state: state))
    }
}

