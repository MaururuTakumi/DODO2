import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an agent app (no Dock, no app switcher)
        NSApp.setActivationPolicy(.accessory)
        NSLog("[DODO2] App launched — setting up hotkeys and observers")

        HotKeyManager.shared.registerHotKeys()

        // Optional: for automated verification, show panel at launch when flag is passed
        if CommandLine.arguments.contains("--autotest-show") {
            PanelWindowController.shared.show(animated: false)
        }

        NotificationCenter.default.addObserver(forName: .togglePanelHotkey, object: nil, queue: .main) { _ in
            NSLog("[DODO2] Received TogglePanelHotkey notification")
            PanelWindowController.shared.toggle()
        }

        NotificationCenter.default.addObserver(forName: .quickAddHotkey, object: nil, queue: .main) { _ in
            NSLog("[DODO2] Received QuickAddHotkey notification")
            PanelWindowController.shared.show(animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .focusQuickAdd, object: nil)
            }
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            // Re-arm hotkeys if needed
            HotKeyManager.shared.ensureHotKeysArmed()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen toggles panel
        PanelWindowController.shared.toggle()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Persistence.flush()
    }
}
