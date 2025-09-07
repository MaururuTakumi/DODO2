import AppKit
import SwiftUI

final class PanelWindowController: NSWindowController {
    static let shared = PanelWindowController()

    private let panelHeight: CGFloat = 360
    private let sideInset: CGFloat = 24
    private let bottomInset: CGFloat = 24

    private var hostingView: NSHostingView<BottomSheetRoot>?
    private var keyMonitor: Any?
    private var outsideClickGlobal: Any?
    private var outsideClickLocal: Any?

    private init() {
        let chosenScreen = PanelWindowController.targetScreen() ?? NSScreen.main
        let frame: NSRect
        if let s = chosenScreen {
            frame = PanelWindowController.targetFrame(on: s, height: panelHeight, sideInset: sideInset, bottomInset: bottomInset)
        } else {
            frame = NSRect(x: 200, y: 200, width: 800, height: panelHeight)
        }
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
        repositionToCurrentScreen()
        // Instrument window state before show
        let hadNonActivating = panel.styleMask.contains(.nonactivatingPanel)
        NSLog("[DODO2] Before show — styleMask=%@ nonactivating=%@ isKey=%d canBecomeKey=%d",
              String(describing: panel.styleMask), String(hadNonActivating), panel.isKeyWindow, panel.canBecomeKey)
        if hadNonActivating { NSLog("[DODO2][ERR] nonactivatingPanel present — inputs cannot focus") }
        // 1) Move to current Space first (no Space switch)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()
        // 2) Activate as an agent; won't switch Desktops
        NSApp.activate(ignoringOtherApps: true)
        // 3) Become key so text inputs focus
        panel.makeKeyAndOrderFront(nil)
        let finalFrame = panel.frame
        var startFrame = finalFrame
        startFrame.origin.y -= 20
        panel.setFrame(startFrame, display: false)

        let animations = {
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(finalFrame, display: true)
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
        let finalFrame = panel.frame
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

    func repositionToCurrentScreen() {
        guard let panel = self.window else { return }
        guard let screen = PanelWindowController.targetScreen() ?? panel.screen ?? NSScreen.main else { return }
        let frame = PanelWindowController.targetFrame(on: screen, height: panelHeight, sideInset: sideInset, bottomInset: bottomInset)
        panel.setFrame(frame, display: true)
        NSLog("[DODO2] Panel repositioned to screen %@ -> %@", screen.debugDescription, NSStringFromRect(frame))
    }

    private static func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        for s in NSScreen.screens {
            if s.frame.contains(mouse) { return s }
        }
        return NSScreen.main
    }

    private static func targetFrame(on screen: NSScreen, height: CGFloat, sideInset: CGFloat, bottomInset: CGFloat) -> NSRect {
        let vis = screen.visibleFrame
        let width = max(200, vis.width - (sideInset * 2))
        let x = vis.minX + sideInset
        let y = vis.minY + bottomInset
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Global shortcuts: ⌘M toggles matrix overlay when panel is visible
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "m" {
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
