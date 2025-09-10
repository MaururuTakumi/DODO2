import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutCaptureField: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.onUpdate = { kc, mods in
            // 要: 少なくとも1つの修飾キー
            guard mods != 0 else { NSBeep(); return }
            keyCode = kc; modifiers = mods
        }
        return v
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {}

    final class CaptureView: NSView {
        var onUpdate: ((UInt32, UInt32) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

        override func keyDown(with e: NSEvent) {
            let mods = toCarbon(e.modifierFlags)
            let kc = UInt32(e.keyCode)
            onUpdate?(kc, mods)
        }

        private func toCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
            var m: UInt32 = 0
            if flags.contains(.command)  { m |= UInt32(cmdKey) }
            if flags.contains(.shift)    { m |= UInt32(shiftKey) }
            if flags.contains(.option)   { m |= UInt32(optionKey) }
            if flags.contains(.control)  { m |= UInt32(controlKey) }
            return m
        }
    }
}

