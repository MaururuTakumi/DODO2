import SwiftUI

@main
struct DODO2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — panel toggled via hotkeys/command
        WindowGroup("Priority Matrix") {
            PriorityMatrixView()
        }
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

                Divider()
                Button("Open Priority Matrix…") {
                    // Open the dedicated window
                    NSApp.activate(ignoringOtherApps: true)
                    // Using SwiftUI scene API ensures the window exists; bring to front
                    // Attempt to find a window titled "Priority Matrix" and order front
                    if let win = NSApp.windows.first(where: { $0.title == "Priority Matrix" }) {
                        win.makeKeyAndOrderFront(nil)
                    } else {
                        // Fallback: create a temporary window hosting the view
                        let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 900, height: 600),
                                         styleMask: [.titled, .closable, .resizable],
                                         backing: .buffered, defer: false)
                        w.title = "Priority Matrix"
                        w.contentView = NSHostingView(rootView: PriorityMatrixView())
                        w.makeKeyAndOrderFront(nil)
                    }
                }
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
