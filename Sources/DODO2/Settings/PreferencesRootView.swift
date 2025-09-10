import SwiftUI

enum PrefPane: String, CaseIterable, Identifiable {
    case general, shortcuts, rules, subscription
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "一般"
        case .shortcuts: return "ショートカット"
        case .rules: return "ルール"
        case .subscription: return "サブスクリプション"
        }
    }
}

struct PreferencesRootView: View {
    @AppStorage("prefs.selectedPane") private var stored = PrefPane.shortcuts.rawValue
    @State private var selection: PrefPane? = .shortcuts

    var body: some View {
        NavigationSplitView {
            List(PrefPane.allCases, selection: $selection) { pane in
                SwiftUI.Label(pane.title, systemImage: icon(for: pane)).tag(pane as PrefPane?)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            .onAppear { selection = PrefPane(rawValue: stored) ?? .shortcuts }
            .onChange(of: selection) { _, new in stored = (new ?? .shortcuts).rawValue }
        } detail: {
            switch selection ?? .shortcuts {
            case .shortcuts: ShortcutsPane()
            case .general:   GeneralPlaceholder()
            case .rules:     RulesPlaceholder()
            case .subscription: SubscriptionPlaceholder()
            }
        }
    }
    private func icon(for p: PrefPane) -> String {
        switch p {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .rules: return "slider.horizontal.3"
        case .subscription: return "person.badge.key"
        }
    }
}

private struct GeneralPlaceholder: View {
    var body: some View { Text("一般設定（後で追加）").padding() }
}
private struct RulesPlaceholder: View {
    var body: some View { Text("ルール（後で追加）").padding() }
}
private struct SubscriptionPlaceholder: View {
    var body: some View { Text("サブスクリプション（後で追加）").padding() }
}
