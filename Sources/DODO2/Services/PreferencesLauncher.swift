import SwiftUI
import AppKit

enum PreferencesLauncher {
    private static var windowRef: NSWindow?
    @discardableResult
    static func open() -> Bool {
        // 1) Broadcast to SwiftUI Settings scene via dynamic selector
        if NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil) {
            return true
        }
        // 2) Final fallback — create our own window and present PreferencesRootView
        if let w = windowRef {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }
        let controller = NSHostingController(rootView: PreferencesRootView())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        windowRef = window
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
