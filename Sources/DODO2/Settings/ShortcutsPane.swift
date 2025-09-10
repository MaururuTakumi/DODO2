import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ショートカット")
                .font(.title2).bold()
            Text("ここにホットキー設定 UI を追加します。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ShortcutsPane()
}
