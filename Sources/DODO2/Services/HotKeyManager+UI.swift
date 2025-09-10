import SwiftUI

extension HotKeyManager {
    var statusText: String {
        switch status {
        case .inactive: return "未登録"
        case .active(.carbon): return "有効（Carbon）"
        case .active(.eventTap): return "有効（Event Tap）"
        case .conflict: return "競合：他アプリ/OSが占有"
        case .denied: return "権限が必要（入力監視/アクセシビリティ）"
        case .error(let s): return "エラー：\(s)"
        }
    }

    var statusColor: Color {
        switch status {
        case .active: return .green
        case .conflict: return .red
        case .denied: return .orange
        default: return .secondary
        }
    }
}

