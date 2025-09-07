import SwiftUI

struct NewTaskButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            SwiftUI.Label("New", systemImage: "plus")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel("New Task")
    }
}
