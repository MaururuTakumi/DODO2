import AppKit
import SwiftUI

private let kBottomMargin: CGFloat = 16  // Bottom margin when docking to bottom edge

final class PanelWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PanelWindowController()

    private let panelHeight: CGFloat = 360
    private let sideInset: CGFloat = 24
    private let bottomInset: CGFloat = 24

    private var hostingView: NSHostingView<BottomSheetRoot>?
    private var keyMonitor: Any?
    private var outsideClickGlobal: Any?
    private var outsideClickLocal: Any?

    private init() {
        // Initial frame; exact position will be set at show-time via applyBottomFullWidthLayout()
        let frame: NSRect = NSRect(x: 200, y: 200, width: 800, height: panelHeight)
        // Use a key-capable panel with a hidden title bar for a borderless look
        let style: NSWindow.StyleMask = [.titled, .fullSizeContentView]
        let panel = KeyPanel(contentRect: frame, styleMask: style, backing: .buffered, defer: false)

        panel.titleVisibility = NSWindow.TitleVisibility.hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        // Hide automatically when app deactivates (user clicks another app)
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = NSWindow.Level.floating
        // Use exactly one combination; prefer moveToActiveSpace
        panel.collectionBehavior = NSWindow.CollectionBehavior([.fullScreenAuxiliary, .moveToActiveSpace])
        assert(!(panel.collectionBehavior.contains(.canJoinAllSpaces)
                 && panel.collectionBehavior.contains(.moveToActiveSpace)),
               "collectionBehavior cannot include both .canJoinAllSpaces and .moveToActiveSpace")
        panel.setFrame(frame, display: false)
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = false

        super.init(window: panel)

        // Visual effect background
        let vev = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        vev.autoresizingMask = NSView.AutoresizingMask([.width, .height])
        vev.material = NSVisualEffectView.Material.sidebar
        vev.blendingMode = NSVisualEffectView.BlendingMode.withinWindow
        vev.state = NSVisualEffectView.State.active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 16
        vev.layer?.masksToBounds = true
        panel.contentView = vev

        let root = BottomSheetRoot(onRequestClose: { [weak self] in
            self?.hide(animated: true)
        })
        let host = NSHostingView(rootView: root)
        hostingView = host
        host.translatesAutoresizingMaskIntoConstraints = false
        vev.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: vev.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: vev.trailingAnchor),
            host.topAnchor.constraint(equalTo: vev.topAnchor),
            host.bottomAnchor.constraint(equalTo: vev.bottomAnchor)
        ])

        NSLog("[DODO2] Panel initialized at %@", NSStringFromRect(frame))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(animated: Bool) {
        guard let panel = self.window else { return }
        // Instrument window state before show
        let hadNonActivating = panel.styleMask.contains(.nonactivatingPanel)
        NSLog("[DODO2] Before show — styleMask=%@ nonactivating=%@ isKey=%d canBecomeKey=%d",
              String(describing: panel.styleMask), String(hadNonActivating), panel.isKeyWindow, panel.canBecomeKey)
        if hadNonActivating { NSLog("[DODO2][ERR] nonactivatingPanel present — inputs cannot focus") }
        // Prepare fade; perform layout and ordering via showWindow(_:)
        panel.alphaValue = 0.0
        // Activate as an agent; won't switch Desktops
        NSApp.activate(ignoringOtherApps: true)
        // Order and layout exactly once
        self.showWindow(nil)
        let animations = {
            panel.animator().alphaValue = 1.0
        }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animations()
                // content spring-like rise
                if let content = self.hostingView?.layer ?? panel.contentView?.layer {
                    content.removeAllAnimations()
                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.22)
                    let trans = CABasicAnimation(keyPath: "transform.translation.y")
                    trans.fromValue = 24
                    trans.toValue = 0
                    trans.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    content.add(trans, forKey: "rise")
                    let fade = CABasicAnimation(keyPath: "opacity")
                    fade.fromValue = 0
                    fade.toValue = 1
                    content.add(fade, forKey: "fade")
                    CATransaction.commit()
                }
            } completionHandler: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .focusQuickAdd, object: nil)
                }
            }
        } else {
            animations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .focusQuickAdd, object: nil)
            }
        }
        NSLog("[DODO2] After show — isKey=%d canBecomeKey=%d firstResponder=%@",
              panel.isKeyWindow, panel.canBecomeKey, String(describing: panel.firstResponder))
        NSLog("[DODO2] Panel shown")
        installKeyMonitor()
        installOutsideClickMonitors()
    }

    func hide(animated: Bool) {
        guard let panel = self.window else { return }
        let animations = {
            panel.animator().alphaValue = 0.0
        }
        let completion = { panel.orderOut(nil) }
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                animations()
                if let content = self.hostingView?.layer ?? panel.contentView?.layer {
                    content.removeAllAnimations()
                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.18)
                    let trans = CABasicAnimation(keyPath: "transform.translation.y")
                    trans.fromValue = 0
                    trans.toValue = 24
                    trans.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    content.add(trans, forKey: "drop")
                    let fade = CABasicAnimation(keyPath: "opacity")
                    fade.fromValue = 1
                    fade.toValue = 0
                    content.add(fade, forKey: "fade")
                    CATransaction.commit()
                }
            }, completionHandler: completion)
        } else {
            animations()
            completion()
        }
        NSLog("[DODO2] Panel hidden")
        removeKeyMonitor()
        removeOutsideClickMonitors()
    }

    func toggle() {
        if window?.isVisible == true {
            hide(animated: true)
        } else {
            show(animated: true)
        }
    }

    // Hotkey entry: ensure single, frontmost appearance on current Space
    func showOverlayFromHotkey() {
        DispatchQueue.main.async {
            guard let panel = self.window else { return }
            panel.collectionBehavior.insert([.moveToActiveSpace, .fullScreenAuxiliary])
            if panel.isVisible { return }
            NSApp.activate(ignoringOtherApps: true)
            self.show(animated: true)
        }
    }

    // On screen change, reapply layout as a safety (does not change effects/animations)
    func windowDidChangeScreen(_ notification: Notification) {
        applyBottomFullWidthLayout()
    }

    // Bottom-docked, full-width layout with pixel snapping
    private func applyBottomFullWidthLayout() {
        guard let w = window else { return }
        let screen = pickScreen(for: w)
        let vf = screen.visibleFrame

        let current = w.frame
        let scale = max(1.0, w.backingScaleFactor)
        @inline(__always) func snap(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }

        // Height preserves current, clamps to visible height minus bottom margin
        let maxHeight = max(0, vf.height - kBottomMargin)
        let height = min(current.height, maxHeight)

        let target = CGRect(
            x: snap(vf.minX),
            y: snap(vf.minY + kBottomMargin),
            width: snap(vf.width),
            height: snap(height)
        )

        // Exactly one setFrame during show flow
        w.setFrame(target, display: true)

        #if DEBUG || LOG_PANEL_GEOMETRY
        let dbg = String(format: "[DODO2][geom] vis=(%.1f,%.1f,%.1f,%.1f) -> frame=(%.1f,%.1f,%.1f,%.1f) scale=%.2f",
                         vf.minX, vf.minY, vf.width, vf.height,
                         target.minX, target.minY, target.width, target.height, scale)
        NSLog("%@", dbg)
        #endif
    }

    // Screen selection: window.screen → mouse location → main
    private func pickScreen(for w: NSWindow) -> NSScreen {
        if let s = w.screen { return s }
        let mouse = NSEvent.mouseLocation
        if let underMouse = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) { return underMouse }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    // Ensure placement for callers that use NSWindowController.showWindow(_:) directly
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let w = window else { return }
        // Disable autosave/restore; placement is controlled explicitly
        w.isRestorable = false
        w.delegate = self
        applyBottomFullWidthLayout()
        w.makeKeyAndOrderFront(nil)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Global shortcuts: ⌘M toggles matrix overlay when panel is visible
            if event.modifierFlags.contains([.command, .shift]), event.charactersIgnoringModifiers?.lowercased() == "m" {
                NotificationCenter.default.post(name: .toggleMatrixOverlay, object: nil)
                return nil
            }
            // Don't handle character toggles if editing text
            if let panel = self.window, panel.firstResponder is NSText || panel.firstResponder is NSTextView {
                return event
            }
            if event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]) {
                if event.charactersIgnoringModifiers?.lowercased() == "i" {
                    NotificationCenter.default.post(name: .toggleImportantSelected, object: nil)
                    return nil
                }
                if event.charactersIgnoringModifiers?.lowercased() == "u" {
                    NotificationCenter.default.post(name: .toggleUrgentSelected, object: nil)
                    return nil
                }
            }
            if event.modifierFlags.contains(.command) && event.keyCode == 51 { // Command + Delete
                NotificationCenter.default.post(name: .deleteSelection, object: nil)
                return nil
            }
            switch event.specialKey {
            case .upArrow?:
                NotificationCenter.default.post(name: .navigateSelection, object: nil, userInfo: ["dir": -1])
                return nil
            case .downArrow?:
                NotificationCenter.default.post(name: .navigateSelection, object: nil, userInfo: ["dir": 1])
                return nil
            case .home?:
                NotificationCenter.default.post(name: .navigateSelection, object: nil, userInfo: ["dir": Int.min])
                return nil
            case .end?:
                NotificationCenter.default.post(name: .navigateSelection, object: nil, userInfo: ["dir": Int.max])
                return nil
            default:
                break
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let mon = keyMonitor { NSEvent.removeMonitor(mon); keyMonitor = nil }
    }

    // Close when clicking anywhere outside the panel
    private func installOutsideClickMonitors() {
        guard outsideClickGlobal == nil, outsideClickLocal == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickGlobal = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            guard let self = self, let panel = self.window else { return }
            let point = NSEvent.mouseLocation
            if !panel.frame.contains(point) {
                self.hide(animated: true)
            }
        }
        outsideClickLocal = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self = self, let panel = self.window else { return event }
            // If the click is in another window (or outside), close and swallow
            let locationInScreen = event.locationInWindow
            let screenPoint: NSPoint
            if let w = event.window {
                screenPoint = w.convertToScreen(NSRect(origin: locationInScreen, size: .zero)).origin
            } else {
                screenPoint = NSEvent.mouseLocation
            }
            if !panel.frame.contains(screenPoint) {
                self.hide(animated: true)
                return nil
            }
            return event
        }
    }

    private func removeOutsideClickMonitors() {
        if let g = outsideClickGlobal { NSEvent.removeMonitor(g); outsideClickGlobal = nil }
        if let l = outsideClickLocal { NSEvent.removeMonitor(l); outsideClickLocal = nil }
    }
}
