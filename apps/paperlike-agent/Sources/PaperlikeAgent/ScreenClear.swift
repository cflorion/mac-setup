import AppKit
import PaperlikeCore

// Ghost cleanup drawn by the host: full-screen black, then white, over the
// Paperlike output chosen by ClearTarget, then the panel redraws the desktop. Each
// full-range transition overwrites every pixel, an approximation of the
// monitor's own Ghost Cleanup that needs no USB link.
//
// The covers are non-activating and ignore the mouse, like the HUD: the
// focused window keeps the keyboard throughout.
final class ScreenClear {
    // Long enough for the panel to settle on each colour before the next one.
    private static let phases: [(color: NSColor, seconds: Double)] = [(.black, 0.3), (.white, 0.3)]

    // Main thread only.
    private var running = false

    // Blocks the calling thread for the length of the flash, so it must never
    // be the main thread, which draws it. Shortcuts and the socket both call
    // from a global queue.
    // A named monitor (`paperlike 13k clear`) narrows the candidates to the
    // screens that model drives.
    func run(monitor: String? = nil) -> [String: Any] {
        dispatchPrecondition(condition: .notOnQueue(.main))
        let done = DispatchSemaphore(value: 0)
        var reply: [String: Any] = [:]
        DispatchQueue.main.async {
            self.start(monitor: monitor) { reply = $0; done.signal() }
        }
        done.wait()
        return reply
    }

    private func start(monitor: String?, _ finish: @escaping ([String: Any]) -> Void) {
        guard !running else { return finish(["ok": true, "action": "clear", "delivery": "already_running"]) }
        let screens = NSScreen.screens.compactMap { screen -> (NSScreen, CGDirectDisplayID)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return nil }
            return (screen, number.uint32Value)
        }
        let pointer = NSEvent.mouseLocation
        let paperlike = screens.map(\.1).filter { id in
            let display = Display(id: id)
            return display.isPaperlike && (monitor.map { Model.any(named: $0, drives: display) } ?? true)
        }
        let targets = ClearTarget.displays(
            paperlike: paperlike,
            pointer: screens.first { NSMouseInRect(pointer, $0.0.frame, false) }?.1)
        guard !targets.isEmpty else {
            return finish(["ok": false, "action": "clear", "error": "No Paperlike display to clear."])
        }
        running = true
        let covers = screens.filter { targets.contains($0.1) }.map { ScreenClear.cover($0.0) }
        var remaining = ScreenClear.phases[...]
        func next() {
            guard let phase = remaining.popFirst() else {
                covers.forEach { $0.orderOut(nil) }
                running = false
                return finish(["ok": true, "action": "clear", "delivery": "drawn", "displays": targets.map(Int.init)])
            }
            for cover in covers {
                cover.backgroundColor = phase.color
                cover.orderFrontRegardless()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + phase.seconds, execute: next)
        }
        next()
    }

    // The whole frame, menu bar included, above everything but the cursor.
    private static func cover(_ screen: NSScreen) -> NSPanel {
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.setFrame(screen.frame, display: false)
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.isOpaque = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }
}
