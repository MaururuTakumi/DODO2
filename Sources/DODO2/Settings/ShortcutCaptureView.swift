import SwiftUI
import Carbon.HIToolbox

struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    func makeNSView(context: Context) -> CaptureField {
        let v = CaptureField()
        v.onChange = { code, mods in
            keyCode = code
            modifiers = mods
        }
        return v
    }

    func updateNSView(_ nsView: CaptureField, context: Context) {
        // No-op
    }

    final class CaptureField: NSView {
        var onChange: ((UInt32, UInt32) -> Void)?

        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return }
            let code = UInt32(event.keyCode)
            let mods = carbonMask(from: event.modifierFlags)
            // Ignore pure modifier-only
            if code == 0 && mods != 0 { return }
            onChange?(code, mods)
        }

        private func carbonMask(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var mask: UInt32 = 0
            if flags.contains(.command) { mask |= UInt32(cmdKey) }
            if flags.contains(.option) { mask |= UInt32(optionKey) }
            if flags.contains(.shift) { mask |= UInt32(shiftKey) }
            if flags.contains(.control) { mask |= UInt32(controlKey) }
            return mask
        }
    }
}
