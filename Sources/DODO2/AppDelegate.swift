import AppKit
import SwiftUI
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an agent app (no Dock, no app switcher)
        NSApp.setActivationPolicy(.accessory)
        NSLog("[DODO2] App launched — setting up hotkeys and observers")

        // Register global hotkey for matrix overlay (user-configurable), prefer Carbon unless compatibility mode is enabled
        var store = Persistence.load()
        let combo = store.settings?.overlayHotKey ?? SettingsModel.defaultHotKey
        let preferTap = (store.settings?.useCompatibilityMode ?? false)
        if !HotKeyManager.shared.start(with: combo, prefer: preferTap ? .eventTap : .carbon) {
            // Fallback to default when registration fails
            store.settings?.overlayHotKey = SettingsModel.defaultHotKey
            Persistence.save(store)
            _ = HotKeyManager.shared.start(with: SettingsModel.defaultHotKey, prefer: preferTap ? .eventTap : .carbon)
        }

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
            let s = Persistence.load()
            let c = s.settings?.overlayHotKey ?? SettingsModel.defaultHotKey
            let preferTap = (s.settings?.useCompatibilityMode ?? false)
            _ = HotKeyManager.shared.start(with: c, prefer: preferTap ? .eventTap : .carbon)
        }
        // React to settings changes from Preferences
        NotificationCenter.default.addObserver(forName: .hotKeySettingChanged, object: nil, queue: .main) { note in
            let s = Persistence.load()
            let combo = s.settings?.overlayHotKey ?? SettingsModel.defaultHotKey
            let preferTap = (s.settings?.useCompatibilityMode ?? false)
            if !HotKeyManager.shared.start(with: combo, prefer: preferTap ? .eventTap : .carbon) {
                _ = HotKeyManager.shared.start(with: SettingsModel.defaultHotKey, prefer: preferTap ? .eventTap : .carbon)
                NSApp.presentError(NSError(domain: "DODO2", code: -1, userInfo: [NSLocalizedDescriptionKey: "そのショートカットは他で使用されています。別の組み合わせを選んでください。"]))
            }
        }
        // Status notifications -> show toast hints
        NotificationCenter.default.addObserver(forName: .hotKeyStatusChanged, object: nil, queue: .main) { note in
            guard let st = note.object as? HotKeyManager.HotKeyStatus else { return }
            let msg: String?
            switch st {
            case .conflict:
                msg = "⌥Space は他アプリと競合しています。設定で変更するか互換モードを有効化してください。"
            case .denied:
                msg = "互換モードは権限が必要です: システム設定 > 入力監視 で許可してください。"
            default:
                msg = nil
            }
            if let m = msg {
                NotificationCenter.default.post(name: .showHUDToast, object: nil, userInfo: ["message": m])
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen toggles panel
        PanelWindowController.shared.toggle()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.stop()
        Persistence.flush()
    }
}
