import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, DODO2")
            .padding()
    }
}

// Disable previews when PreviewsMacros are unavailable (e.g., xcodebuild CI)
#if canImport(PreviewsMacros)
#Preview {
    ContentView()
}
#endif
