// EyeBreak — menu-bar app that reminds you to rest your eyes (20-20-20 rule):
// every <interval> minutes, a full-screen overlay asks you to look ~6 m away
// for <duration> seconds. Single file, AppKit only; built by ./build.sh.
import AppKit

// MARK: - Settings (persisted in UserDefaults)

enum Settings {
    static let defaults = UserDefaults.standard
    static var intervalMinutes: Int {
        get { let v = defaults.integer(forKey: "intervalMinutes"); return v > 0 ? v : 20 }
        set { defaults.set(newValue, forKey: "intervalMinutes") }
    }
    static var breakSeconds: Int {
        get { let v = defaults.integer(forKey: "breakSeconds"); return v > 0 ? v : 20 }
        set { defaults.set(newValue, forKey: "breakSeconds") }
    }
}

// MARK: - Break overlay

/// Borderless windows cannot become key by default; this one must, to catch Esc.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayView: NSView {
    var onEscape: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

final class BreakOverlay {
    private var windows: [NSWindow] = []
    private var countdownLabels: [NSTextField] = []
    private var timer: Timer?
    private var remaining = 0
    private let onFinish: (_ completed: Bool, _ snoozeMinutes: Int?) -> Void

    init(seconds: Int, onFinish: @escaping (_ completed: Bool, _ snoozeMinutes: Int?) -> Void) {
        remaining = seconds
        self.onFinish = onFinish
    }

    func show() {
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = NSColor.black.withAlphaComponent(0.92)
            window.isOpaque = false
            window.isReleasedWhenClosed = false
            window.setFrame(screen.frame, display: true)

            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onEscape = { [weak self] in self?.finish(completed: false, snooze: nil) }
            window.contentView = view

            let title = label("Repose tes yeux", size: 44, weight: .semibold)
            let subtitle = label("Regarde au loin, à 6 mètres ou plus, et cligne des yeux.", size: 20, weight: .regular)
            let countdown = label(format(remaining), size: 72, weight: .light, monospaced: true)
            countdownLabels.append(countdown)

            let skip = button("Passer (Échap)", action: #selector(skipPressed))
            let snooze = button("Dans 5 min", action: #selector(snoozePressed))
            let buttons = NSStackView(views: [snooze, skip])
            buttons.spacing = 16

            let stack = NSStackView(views: [title, subtitle, countdown, buttons])
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 24
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])

            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let first = windows.first {
            first.makeKeyAndOrderFront(nil)
            first.makeFirstResponder(first.contentView)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            NSSound(named: "Glass")?.play()
            finish(completed: true, snooze: nil)
            return
        }
        countdownLabels.forEach { $0.stringValue = format(remaining) }
    }

    @objc private func skipPressed() { finish(completed: false, snooze: nil) }
    @objc private func snoozePressed() { finish(completed: false, snooze: 5) }

    private func finish(completed: Bool, snooze: Int?) {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onFinish(completed, snooze)
    }

    private func format(_ seconds: Int) -> String {
        seconds >= 60 ? String(format: "%d:%02d", seconds / 60, seconds % 60) : "\(seconds)"
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, monospaced: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = monospaced ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
                                : .systemFont(ofSize: size, weight: weight)
        field.textColor = .white
        field.alignment = .center
        return field
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        return b
    }
}

// MARK: - App / menu bar

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var nextBreak = Date()
    private var pausedUntil: Date?
    private var overlay: BreakOverlay?
    private var ticker: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Pause yeux")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        scheduleNext()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }

        // Time asleep or locked counts as a break: restart the cycle on wake/unlock.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleNext()
            }
        }
    }

    private func scheduleNext(in minutes: Int? = nil) {
        nextBreak = Date().addingTimeInterval(TimeInterval((minutes ?? Settings.intervalMinutes) * 60))
        updateTitle()
    }

    /// Seconds since the last keyboard/mouse input.
    private var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                 eventType: CGEventType(rawValue: ~0)!)
    }

    private func tick() {
        guard overlay == nil else { return }
        if let until = pausedUntil {
            if Date() < until { updateTitle(); return }
            pausedUntil = nil
            scheduleNext()
        }
        // Away from the keyboard at least as long as a break: that was a break.
        if idleSeconds >= Double(max(Settings.breakSeconds, 60)) {
            scheduleNext()
            return
        }
        if Date() >= nextBreak { startBreak() } else { updateTitle() }
    }

    /// Minutes only, so the menu bar redraws once a minute (friendly to e-ink displays).
    private func updateTitle() {
        let text: String
        if let until = pausedUntil {
            text = until == .distantFuture ? " ⏸" : " ⏸ \(minutesLeft(until))"
        } else {
            text = " \(minutesLeft(nextBreak))"
        }
        if statusItem.button?.title != text { statusItem.button?.title = text }
    }

    private func minutesLeft(_ date: Date) -> Int {
        max(1, Int(ceil(date.timeIntervalSinceNow / 60)))
    }

    @objc private func startBreak() {
        guard overlay == nil else { return }
        pausedUntil = nil
        overlay = BreakOverlay(seconds: Settings.breakSeconds) { [weak self] _, snooze in
            self?.overlay = nil
            self?.scheduleNext(in: snooze)
        }
        overlay?.show()
    }

    // MARK: Menu (rebuilt each time it opens so the state is always current)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status: String
        if let until = pausedUntil {
            status = until == .distantFuture ? "En pause" : "En pause jusqu’à \(timeString(until))"
        } else {
            status = "Prochaine pause à \(timeString(nextBreak))"
        }
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(item("Faire une pause maintenant", #selector(startBreak)))
        if pausedUntil != nil {
            menu.addItem(item("Reprendre", #selector(resume)))
        } else {
            menu.addItem(item("Suspendre 1 heure", #selector(pauseHour)))
            menu.addItem(item("Suspendre jusqu’à reprise", #selector(pauseIndefinitely)))
        }
        menu.addItem(.separator())
        menu.addItem(choiceMenu("Intervalle", values: [10, 20, 30, 45, 60], current: Settings.intervalMinutes,
                                label: { "\($0) min" }, action: #selector(setInterval(_:))))
        menu.addItem(choiceMenu("Durée de la pause", values: [20, 30, 60, 120, 300], current: Settings.breakSeconds,
                                label: { $0 < 60 ? "\($0) s" : "\($0 / 60) min" }, action: #selector(setDuration(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quitter", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func choiceMenu(_ title: String, values: [Int], current: Int,
                            label: (Int) -> String, action: Selector) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for v in values {
            let i = item(label(v), action)
            i.tag = v
            i.state = v == current ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    @objc private func resume() { pausedUntil = nil; scheduleNext() }
    @objc private func pauseHour() { pausedUntil = Date().addingTimeInterval(3600); updateTitle() }
    @objc private func pauseIndefinitely() { pausedUntil = .distantFuture; updateTitle() }
    @objc private func setInterval(_ sender: NSMenuItem) { Settings.intervalMinutes = sender.tag; scheduleNext() }
    @objc private func setDuration(_ sender: NSMenuItem) { Settings.breakSeconds = sender.tag }
    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
