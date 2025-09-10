import AppKit
import Carbon.HIToolbox
import ApplicationServices

final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private init() {}

    enum Mode { case carbon, eventTap }
    enum HotKeyStatus { case inactive, active(Mode), conflict, denied, error(String) }

    @Published var status: HotKeyStatus = .inactive

    // Carbon
    private var carbonInstalled = false
    private var carbonRef: EventHotKeyRef?

    // Event Tap
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var compatOn: Bool = false

    // State
    private var lastFiredAt: Date = .distantPast
    private var currentCombo: HotKeyCombo = SettingsModel.defaultHotKey
    private var preferred: Mode = .carbon

    // MARK: Public API
    @discardableResult
    func start(with combo: HotKeyCombo, prefer mode: Mode = .carbon) -> Bool {
        stop()
        currentCombo = combo
        preferred = mode
        switch mode {
        case .carbon:
            if registerCarbon(combo) { updateStatus(.active(.carbon)); return true }
            updateStatus(.conflict)
            if compatOn { return startEventTap(combo) }
            return false
        case .eventTap:
            return startEventTap(combo)
        }
    }

    func stop() {
        // Carbon
        if let r = carbonRef { UnregisterEventHotKey(r); carbonRef = nil }
        // Event tap
        if let s = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes); tapSource = nil }
        if let t = tap { CFMachPortInvalidate(t); tap = nil }
        updateStatus(.inactive)
    }

    func enableCompatibilityMode(_ on: Bool) {
        compatOn = on
        switch status {
        case .conflict where on:
            _ = start(with: currentCombo, prefer: .eventTap)
        case .active(.eventTap) where !on:
            _ = start(with: currentCombo, prefer: .carbon)
        default: break
        }
    }

    func apply(settings: SettingsModel) {
        let combo = settings.overlayHotKey ?? SettingsModel.defaultHotKey
        _ = start(with: combo, prefer: preferred)
    }

    // Apply using plain combo + event tap preference
    func apply(settings combo: HotKeyCombo, preferEventTap: Bool) {
        _ = start(with: combo, prefer: preferEventTap ? .eventTap : .carbon)
    }

    // MARK: Carbon
    private func installCarbonHandlerIfNeeded() {
        guard !carbonInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if err == noErr { HotKeyManager.shared.fire(); return noErr }
            return err
        }, 1, &spec, nil, nil)
        if status == noErr { carbonInstalled = true }
    }

    private func registerCarbon(_ combo: HotKeyCombo) -> Bool {
        installCarbonHandlerIfNeeded()
        var ref: EventHotKeyRef? = nil
        let id = EventHotKeyID(signature: OSType(0x444F4432), id: 1) // 'DOD2'
        let s = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if s == noErr { carbonRef = ref }
        #if DEBUG
        NSLog("[HotKey] Carbon register keyCode=%u mods=%u => %d", combo.keyCode, combo.modifiers, s)
        #endif
        return s == noErr
    }

    // MARK: Event Tap
    private func startEventTap(_ combo: HotKeyCombo) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true as CFBoolean] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) { updateStatus(.denied); return false }
        let mask = (1 << CGEventType.keyDown.rawValue)
        let cb: CGEventTapCallBack = { _, type, ev, info in
            guard type == .keyDown else { return Unmanaged.passUnretained(ev) }
            let code = UInt32(ev.getIntegerValueField(.keyboardEventKeycode))
            let mods = HotKeyManager.toCarbon(ev.flags)
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(info!).takeUnretainedValue()
            if code == mgr.currentCombo.keyCode && (mods & mgr.currentCombo.modifiers) == mgr.currentCombo.modifiers {
                mgr.fire(); return nil
            }
            return Unmanaged.passUnretained(ev)
        }
        let info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: cb, userInfo: info) else {
            updateStatus(.denied); return false
        }
        tap = t
        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        if let s = tapSource { CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes) }
        CGEvent.tapEnable(tap: t, enable: true)
        updateStatus(.active(.eventTap))
        #if DEBUG
        NSLog("[HotKey] EventTap enabled keyCode=%u mods=%u", combo.keyCode, combo.modifiers)
        #endif
        return true
    }

    private static func toCarbon(_ flags: CGEventFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.maskCommand) { m |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { m |= UInt32(optionKey) }
        if flags.contains(.maskShift) { m |= UInt32(shiftKey) }
        if flags.contains(.maskControl) { m |= UInt32(controlKey) }
        return m
    }

    // MARK: Fire with debounce
    private func fire() {
        let now = Date(); if now.timeIntervalSince(lastFiredAt) < 0.25 { return }
        lastFiredAt = now
        DispatchQueue.main.async {
            PanelWindowController.shared.showOverlayFromHotkey()
            NotificationCenter.default.post(name: .toggleMatrixOverlay, object: nil)
        }
    }

    private func updateStatus(_ s: HotKeyStatus) {
        DispatchQueue.main.async {
            self.status = s
            NotificationCenter.default.post(name: .hotKeyStatusChanged, object: s)
        }
    }

    // Manual trigger for testing from Preferences
    func fireForTest() {
        DispatchQueue.main.async {
            PanelWindowController.shared.showOverlayFromHotkey()
            NotificationCenter.default.post(name: .toggleMatrixOverlay, object: nil)
        }
    }
}

extension Notification.Name {
    static let hotKeyStatusChanged = Notification.Name("HotKeyStatusChanged")
}
