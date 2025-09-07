import SwiftUI

struct QuickComposerCard: View {
    @Binding var isPresented: Bool
    var presetLabelName: String?
    var onCommit: (String, String?) -> Void

    @State private var title: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let l = presetLabelName {
                    Text(l)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
                Spacer()
                Button(role: .cancel) { cancel() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Cancel (Esc)")
            }

            TextField("Task title…", text: $title, axis: .vertical)
                .lineLimit(1...2)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(commit)
                .submitLabel(.done)

            HStack {
                Button("Add") { commit() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Cancel", role: .cancel) { cancel() }
                    .controlSize(.small)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(height: UIConst.cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: UIConst.cardCorner)
                .fill(Color.gray.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIConst.cardCorner)
                .stroke(Color.white.opacity(0.06))
        )
        .onAppear { focused = true }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func commit() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { cancel(); return }
        onCommit(t, presetLabelName)
        isPresented = false
    }
    private func cancel() { isPresented = false }
}

