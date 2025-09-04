import AppKit
import Carbon.HIToolbox

final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var handlerInstalled = false
    private var hotKeyRefs: [Action: EventHotKeyRef?] = [:]
    private var idToAction: [UInt32: Action] = [:]
    private var lastIMEWarn: Date = .distantPast

    enum Action: UInt32 { case togglePrimary = 1, toggleFallback = 2, quickAdd = 3 }

    func registerHotKeys() {
        installHandlerIfNeeded()
        let defaults = SettingsModel.defaults
        apply(settings: defaults)
    }

    func ensureHotKeysArmed() {
        if hotKeyRefs.isEmpty { registerHotKeys() }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { (next, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if err == noErr {
                NSLog("[DODO2] Hotkey pressed: id=%u", hotKeyID.id)
                let action = HotKeyManager.shared.idToAction[hotKeyID.id]
                switch action {
                case .togglePrimary, .toggleFallback:
                    NotificationCenter.default.post(name: .togglePanelHotkey, object: nil)
                case .quickAdd:
                    NotificationCenter.default.post(name: .quickAddHotkey, object: nil)
                case .none:
                    break
                }
                return noErr
            }
            return err
        }, 1, &eventType, nil, nil)
        if status == noErr {
            handlerInstalled = true
            NSLog("[DODO2] Installed global hotkey handler")
        } else {
            NSLog("[DODO2][WARN] Failed to install hotkey handler: %d", status)
        }
    }

    private func registerHotKey(action: Action, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef? = nil
        let hotKeyID = EventHotKeyID(signature: OSType("D2HK".fourCharCodeValue), id: action.rawValue)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            hotKeyRefs[action] = hotKeyRef
            idToAction[action.rawValue] = action
            NSLog("[DODO2] Registered hotkey action=%@ keyCode=%d modifiers=%d", String(describing: action), keyCode, modifiers)
        } else {
            let now = Date()
            if now.timeIntervalSince(lastIMEWarn) > 10 {
                lastIMEWarn = now
                NSLog("[DODO2][WARN] RegisterEventHotKey failed: %d for keyCode=%d modifiers=%d", status, keyCode, modifiers)
            }
        }
    }

    private func unregister(action: Action) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeValue(forKey: action)
        idToAction.removeValue(forKey: action.rawValue)
    }

    func apply(settings: SettingsModel) {
        installHandlerIfNeeded()
        // Toggle primary
        unregister(action: .togglePrimary)
        if let spec = settings.togglePrimary, spec.enabled {
            registerHotKey(action: .togglePrimary, keyCode: spec.keyCode, modifiers: spec.modifiers)
        }
        // Toggle fallback
        unregister(action: .toggleFallback)
        if let spec = settings.toggleFallback, spec.enabled {
            registerHotKey(action: .toggleFallback, keyCode: spec.keyCode, modifiers: spec.modifiers)
        }
        // Quick add
        unregister(action: .quickAdd)
        if let spec = settings.quickAddGlobal, spec.enabled {
            registerHotKey(action: .quickAdd, keyCode: spec.keyCode, modifiers: spec.modifiers)
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
