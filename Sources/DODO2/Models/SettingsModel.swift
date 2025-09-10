import Foundation
import Carbon.HIToolbox

struct HotkeySpec: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var enabled: Bool
}

struct SettingsModel: Codable, Equatable {
    var togglePrimary: HotkeySpec?    // e.g. ⌥Space
    var toggleFallback: HotkeySpec?   // e.g. ⌘⌥Space (recommended enabled)
    var quickAddGlobal: HotkeySpec?   // e.g. ⌘⇧N (optional)
    // Global overlay toggle hotkey (user configurable)
    var overlayHotKey: HotKeyCombo?
    // Compatibility mode for Event Tap (Input Monitoring permission)
    var useCompatibilityMode: Bool? = false

    static var defaults: SettingsModel {
        SettingsModel(
            togglePrimary: HotkeySpec(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), enabled: true),
            toggleFallback: HotkeySpec(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | cmdKey), enabled: true),
            quickAddGlobal: nil,
            overlayHotKey: defaultHotKey,
            useCompatibilityMode: false
        )
    }
}

// Simple combo for Carbon hotkeys
struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32   // Carbon virtual key code
    var modifiers: UInt32 // Carbon modifiers (cmdKey/optionKey/shiftKey/controlKey)
}

extension SettingsModel {
    // Default: Option + Space (⌥Space)
    static let defaultHotKey = HotKeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
}

enum KeyDisplay {
    static func format(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(symbolForKeyCode(Int(keyCode)))
        return parts.joined()
    }

    static func symbolForKeyCode(_ code: Int) -> String {
        switch code {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "⎋"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_N: return "N"
        default: return "Key(\(code))"
        }
    }
}

extension Notification.Name {
    static let hotKeySettingChanged = Notification.Name("hotKeySettingChanged")
}
