import SwiftUI

@main
struct DODO2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — panel toggled via hotkeys/command
        Settings {
            PreferencesView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle Panel") {
                    PanelWindowController.shared.toggle()
                }
                .keyboardShortcut(.space, modifiers: [.option])

                Button("Quick Add") {
                    NotificationCenter.default.post(name: .focusQuickAdd, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Find") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                // Label assignment ⌘1 … ⌘9 for selected task
                ForEach(1...9, id: \.self) { i in
                    Button("Assign Label \(i)") {
                        NotificationCenter.default.post(name: .assignLabelIndex, object: nil, userInfo: ["index": i])
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(i)")), modifiers: [.command])
                }

                Divider()
                Button("Delete Selected Task") {
                    NotificationCenter.default.post(name: .requestDeleteSelected, object: nil)
                }
                // SwiftUI doesn't expose backspace symbol easily; key monitor already handles ⌘⌫.
                Button("Undo Delete") {
                    NotificationCenter.default.post(name: .requestUndoDelete, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("Delete Completed Tasks") {
                    NotificationCenter.default.post(name: .requestDeleteCompleted, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                // Matrix opens as sheet from main UI; no separate window command
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let togglePanelHotkey = Notification.Name("TogglePanelHotkey")
    static let focusQuickAdd = Notification.Name("FocusQuickAdd")
    static let focusSearch = Notification.Name("FocusSearch")
    static let _internalFocusSearchNow = Notification.Name("_InternalFocusSearchNow")
    static let assignLabelIndex = Notification.Name("AssignLabelIndex")
    static let quickAddHotkey = Notification.Name("QuickAddHotkey")
    static let _internalFocusQuickAddNow = Notification.Name("_InternalFocusQuickAddNow")
    static let navigateSelection = Notification.Name("NavigateSelection")
    static let deleteSelection = Notification.Name("DeleteSelection")
    static let requestDeleteSelected = Notification.Name("requestDeleteSelected")
    static let requestDeleteCompleted = Notification.Name("requestDeleteCompleted")
    static let requestUndoDelete = Notification.Name("requestUndoDelete")
}
