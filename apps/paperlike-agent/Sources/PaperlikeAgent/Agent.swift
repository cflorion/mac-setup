import AppKit
import OSLog
import PaperlikeCore

// A CGDisplayReconfigurationCallBack is a C function pointer and cannot
// capture, so the agent is passed through the userInfo pointer. The callback
// fires twice per change; only the end of the reconfiguration is acted on.
private let reconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
    guard let userInfo, !flags.contains(.beginConfigurationFlag) else { return }
    Unmanaged<Agent>.fromOpaque(userInfo).takeUnretainedValue().displayReconfigured()
}

final class Agent {
    let queue = DispatchQueue(label: "com.user.paperlike-agent.hardware", qos: .utility)
    private let logger = Logger(subsystem: "com.user.paperlike-agent", category: "connection")
    private var timer: DispatchSourceTimer?
    private var serial: SerialPort?
    private var selectedPath: String?
    private var inventory: Inventory?
    private var firmware: UInt8?
    private var state = "starting"
    private var message = "Starting."
    private var sleeping = false
    private var lastHealthCheck = 0.0
    private var lastKeepalive: String?
    private var lastReply: String?
    private let started = Date()
    private var lastAction = 0.0
    private var ditheringReasserts = 0
    private var displayReconfigurations = 0
    private var reconfigurationCallbackRegistered = false
    private var gammaWasLinear: Bool?
    private var lastDitheringReassert: String?
    private var lastDitheringApplied: [DitheringEnforcement] = []
    private var shortcuts: [[String: Any]] = []
    private var lastShortcutResult: [String: Any]?
    // Light modes 1–3 belong to the panel; switching back on restores whichever
    // was last in use. It survives restarts — every reinstall restarts the
    // agent — and falls back to 1 only before any mode has ever been seen.
    private var lastLightMode = (1...3).contains(UserDefaults.standard.integer(forKey: "lastLightMode"))
        ? UserDefaults.standard.integer(forKey: "lastLightMode") : 1 {
        didSet { UserDefaults.standard.set(lastLightMode, forKey: "lastLightMode") }
    }
    private let controlEnabled: Bool
    private let hudEnabled: Bool

    private let configurationProblems: [String]

    private static let observationOnly = PaperlikeError(
        "Observation mode: no USB command is sent. Control is disabled.", code: "observation")
    // Spacing between two setting commands. Rapid shortcut presses are merged
    // upstream, so this only ever delays a command, never refuses one.
    private static let minimumSpacing = 0.1
    // The level used when the light is switched on while its brightness
    // register reads zero; see `switchLight`.
    private static let initialBrightness = 20

    init(controlEnabled: Bool, hudEnabled: Bool = false, configurationProblems: [String] = []) {
        self.controlEnabled = controlEnabled
        self.hudEnabled = hudEnabled
        self.configurationProblems = configurationProblems
        if !configurationProblems.isEmpty {
            logger.error("Configuration: \(configurationProblems.joined(separator: "; "), privacy: .public)")
        }
    }

    func recordShortcutRegistrations(_ results: [(HotKeyBinding, OSStatus)]) {
        queue.async {
            self.shortcuts = results.map { binding, status in
                ["keys": binding.keys, "action": binding.describedAction,
                 "registered": status == noErr, "osStatus": Int(status)]
            }
        }
    }

    func recordShortcutResult(_ keys: String, _ reply: [String: Any]) {
        queue.async { self.lastShortcutResult = reply.merging(["keys": keys]) { current, _ in current } }
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
        // The two-second timer alone would leave a monitor dithered for up to
        // two seconds after it is plugged in. This fires as soon as macOS
        // finishes reconfiguring the displays.
        let registration = CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        queue.async { self.reconfigurationCallbackRegistered = registration == .success }
        if registration != .success {
            logger.error("Display reconfiguration callback refused (\(registration.rawValue, privacy: .public)); only the two-second timer covers hotplugs.")
        }
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(reconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    // macOS may set `enableDither` slightly after the reconfiguration ends, so
    // one write on the event is not enough. The schedule is fixed and bounded;
    // repeated writes cost nothing because `disableOnDasung` skips any output
    // already at false.
    private static let reapplyDelays: [Double] = [0, 0.15, 0.4, 1.0]

    // Called from the main run loop: every access to agent state has to hop
    // onto `queue`, which owns it.
    fileprivate func displayReconfigured() {
        queue.async { self.displayReconfigurations += 1 }
        for delay in Agent.reapplyDelays {
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.sleeping else { return }
                self.enforceDithering()
            }
        }
    }

    func sleep(_ value: Bool) {
        queue.async {
            self.sleeping = value
            if value { self.disconnect(); self.transition("sleeping", "Mac asleep.") }
            else { self.tick() }
        }
    }

    func request(_ args: [String]) -> [String: Any] {
        let diagnostic = args == ["status"] || args == ["query"] || (args.count == 2 && args[0] == "read")
        guard diagnostic else {
            do { return perform(try Action.parse(args)) } catch { return Agent.failure(error) }
        }
        return queue.sync {
            do {
                if args == ["status"] { return status() }
                guard controlEnabled else { throw Agent.observationOnly }
                if args.count == 2, args[0] == "read" {
                    // Diagnostic: 0x0A + register is a non-destructive read, so an
                    // arbitrary register is safe to expose. Writing is not.
                    guard let register = UInt8(args[1].replacingOccurrences(of: "0x", with: ""), radix: 16) else {
                        throw PaperlikeError("Expected a hexadecimal register, for example: paperlike read 09.")
                    }
                    guard let serial else { throw PaperlikeError(message) }
                    try sendMacStatus(serial)
                    return ["ok": true, "register": String(format: "0x%02X", register),
                            "value": Int(try serial.query(register))]
                }
                guard let serial else { throw PaperlikeError(message) }
                try sendMacStatus(serial)
                var registers: [String: Int] = [:]
                for (name, register) in [("firmware", UInt8(0x10)), ("contrast", 0x01), ("mode", 0x02), ("speed", 0x04)] {
                    registers[name] = Int(try serial.query(register))
                }
                return ["ok": true, "registers": registers, "received": serial.lastFrames]
            } catch {
                return Agent.failure(error)
            }
        }
    }

    // Every setting command, from the command line or a shortcut. The reply
    // carries what the HUD needs (setting, bounds, value), so feedback never
    // costs a serial exchange of its own.
    func perform(_ action: Action) -> [String: Any] {
        queue.sync {
            do {
                guard controlEnabled else { throw Agent.observationOnly }
                guard let serial else { throw PaperlikeError(message, code: "unavailable") }
                let wait = lastAction + Agent.minimumSpacing - ProcessInfo.processInfo.systemUptime
                if wait > 0 { Thread.sleep(forTimeInterval: wait) }
                defer { lastAction = ProcessInfo.processInfo.systemUptime }
                try sendMacStatus(serial)
                _ = try serial.readFrames(timeout: 0.02)

                var response: [String: Any] = ["ok": true, "action": action.arguments.joined(separator: " ")]
                switch action {
                case .refresh:
                    let frame = action.frame(value: 0)
                    try serial.send(frame)
                    let replies = try serial.readFrames(timeout: 0.25) { $0.contains { $0.acknowledges(frame) } }
                    response["received"] = replies.map(\.ascii)
                    response["delivery"] = replies.contains(where: { $0.acknowledges(frame) })
                        ? "acknowledged_by_device" : "sent"
                    response["note"] = "The visual effect of the cleanup can only be checked on the panel."
                case .set(let setting, let adjustment):
                    try set(setting, adjustment, on: serial, into: &response)
                case .light(let power):
                    try switchLight(power, on: serial, into: &response)
                }
                lastReply = ISO8601DateFormatter().string(from: Date())
                return response
            } catch {
                return Agent.failure(error)
            }
        }
    }

    private func set(_ setting: Setting, _ adjustment: Adjustment, on serial: SerialPort,
                     into response: inout [String: Any]) throws {
        response["setting"] = setting.name
        response["bounds"] = [setting.bounds.lowerBound, setting.bounds.upperBound]
        if setting.name == "light" { return try adjustLight(setting, adjustment, on: serial, into: &response) }
        if let requirement = setting.requires, try serial.query(requirement.command) == 0 {
            throw PaperlikeError("\(setting.name) cannot be set: \(requirement.explanation).", code: requirement.code)
        }
        // A relative change is resolved against a fresh read, never a cached
        // value: the monitor is also driven by its own buttons.
        let before = Int(try serial.query(setting.command))
        let target = adjustment.resolve(from: before, within: setting.bounds)
        response["from"] = before
        guard setting.bounds.contains(target) else {
            throw PaperlikeError("\(setting.name) expects a value from \(setting.bounds.lowerBound) to \(setting.bounds.upperBound); \(target) is out of range.")
        }
        guard target != before else {
            response["delivery"] = "unchanged"
            response["value"] = before
            return
        }
        response["received"] = try write(setting, target, on: serial)
        response["delivery"] = "confirmed_by_readback"
        response["value"] = target
        // `paperlike light-mode 3` is how a mode is chosen for the toggle.
        if setting.name == "light-mode", target != 0 { lastLightMode = target }
    }

    // Brightness as one level where 0 means off — see FrontLight. Switching
    // off leaves the brightness register alone, so the toggle brings the last
    // level back.
    private func adjustLight(_ light: Setting, _ adjustment: Adjustment, on serial: SerialPort,
                             into response: inout [String: Any]) throws {
        guard let mode = Setting.named("light-mode") else { return }
        let current = Int(try serial.query(mode.command))
        if current != 0 { lastLightMode = current }
        let level = current != 0 ? Int(try serial.query(light.command)) : 0
        response["from"] = level
        var received: [String] = []
        switch FrontLight.step(isOn: current != 0, level: level, by: adjustment, within: light.bounds) {
        case .stay(let value):
            response["value"] = value
            if current == 0 { response["power"] = "off" }
        case .switchOff:
            received += try write(mode, 0, on: serial)
            response["value"] = 0
            response["power"] = "off"
        case .setLevel(let value):
            received += try write(light, value, on: serial)
            response["value"] = value
        case .switchOn(let value):
            received += try write(mode, lastLightMode, on: serial)
            received += try write(light, value, on: serial)
            response["value"] = value
            response["power"] = "on"
        }
        response["received"] = received
        response["delivery"] = received.isEmpty && response["value"] as? Int == level ? "unchanged" : "confirmed_by_readback"
    }

    // The panel keeps its brightness register while the light is off, so
    // switching back on normally restores the previous level. Only a level of
    // zero is raised: a light switched "on" at zero changes nothing on the
    // panel, which reads as a broken shortcut.
    private func switchLight(_ power: Power, on serial: SerialPort, into response: inout [String: Any]) throws {
        guard let mode = Setting.named("light-mode"), let light = Setting.named("light") else { return }
        let current = Int(try serial.query(mode.command))
        if current != 0 { lastLightMode = current }
        let on = power == .toggle ? current == 0 : power == .on
        response["setting"] = light.name
        response["bounds"] = [light.bounds.lowerBound, light.bounds.upperBound]
        response["power"] = on ? "on" : "off"
        guard on else {
            if current != 0 { response["received"] = try write(mode, 0, on: serial) }
            response["delivery"] = current == 0 ? "unchanged" : "confirmed_by_readback"
            return
        }
        var received: [String] = []
        if current == 0 { received += try write(mode, lastLightMode, on: serial) }
        var level = Int(try serial.query(light.command))
        if level == 0 {
            received += try write(light, Agent.initialBrightness, on: serial)
            level = Agent.initialBrightness
        }
        response["received"] = received
        response["value"] = level
        response["delivery"] = current == 0 || !received.isEmpty ? "confirmed_by_readback" : "unchanged"
    }

    // Read-back is the contract for every write: the vendor client
    // acknowledged commands that had not landed, which is precisely the
    // failure this agent exists to avoid. An acknowledgement only ends the
    // wait early; it is never taken as proof.
    private func write(_ setting: Setting, _ value: Int, on serial: SerialPort) throws -> [String] {
        let frame = Frame(setting.command, UInt8(value))
        try serial.send(frame)
        let received = try serial.readFrames(timeout: 0.25) { $0.contains { $0.acknowledges(frame) } }
        let actual = Int(try serial.query(setting.command))
        guard actual == value else {
            throw PaperlikeError("Command sent, but the read-back gives \(actual) instead of \(value). The monitor may have clamped the value.")
        }
        return received.map(\.ascii)
    }

    private static func failure(_ error: Error) -> [String: Any] {
        var reply: [String: Any] = ["ok": false, "error": String(describing: error)]
        reply["code"] = (error as? PaperlikeError)?.code
        return reply
    }

    private func tick() {
        guard !sleeping else { return }
        let current = Inventory.capture()
        inventory = current
        // Runs whatever the control mode: clearing `enableDither` is an IOKit
        // property write on the framebuffer and never touches the USB port.
        enforceDithering()
        reportGamma()
        do {
            guard controlEnabled else {
                transition(current.displays.contains(where: \.isDasung) ? "detected" : "waiting",
                           "Anti-dithering applied; USB control disabled.")
                return
            }
            let device = try current.selectedDevice()
            if selectedPath != device.path { disconnect() }
            if serial == nil {
                let connection = try SerialPort(path: device.path)
                let version: UInt8
                do { version = try connection.query(0x10) }
                catch { throw PaperlikeError("\(error) Replies received: \(connection.lastFrames.joined(separator: ", "))") }
                guard ProtocolIdentity.isSupported(version) else {
                    throw PaperlikeError(String(format: "Unrecognized MCU (0x%02X); no setting command sent.", version))
                }
                serial = connection; selectedPath = device.path; firmware = version
                if let mode = try? connection.query(0x07), (1...3).contains(Int(mode)) { lastLightMode = Int(mode) }
                lastHealthCheck = ProcessInfo.processInfo.systemUptime
            }
            guard let serial else { return }
            try sendMacStatus(serial)
            lastKeepalive = ISO8601DateFormatter().string(from: Date())
            let replies = try serial.readFrames(timeout: 0.02)
            if !replies.isEmpty { lastReply = lastKeepalive }
            if ProcessInfo.processInfo.systemUptime - lastHealthCheck >= 30 {
                let version = try serial.query(0x10)
                guard version == firmware else { throw PaperlikeError("The display's identity changed.") }
                lastHealthCheck = ProcessInfo.processInfo.systemUptime
                lastReply = ISO8601DateFormatter().string(from: Date())
            }
            transition("connected", "DASUNG display identified; USB control active.")
        } catch {
            disconnect()
            transition("waiting", String(describing: error))
        }
    }

    // macOS restores dithering on reconnect, wake and mode changes. Only a
    // framebuffer whose value is not already false is written, so the counter
    // below measures how often macOS actually resets it.
    private func enforceDithering() {
        let applied = DitheringState.disableOnDasung()
        guard !applied.isEmpty else { return }
        ditheringReasserts += applied.count
        lastDitheringReassert = ISO8601DateFormatter().string(from: Date())
        lastDitheringApplied = applied
        for entry in applied where !entry.succeeded {
            logger.error("Anti-dithering refused on ProductID \(entry.product, privacy: .public): kern_return \(entry.result, privacy: .public).")
        }
        let restored = applied.filter(\.succeeded).count
        if restored > 0 {
            logger.notice("Anti-dithering restored on \(restored, privacy: .public) DASUNG output(s).")
        }
    }

    // Reported, never corrected — see GammaState. A crushed table is the single
    // most destructive host-side setting for an e-ink panel and is invisible in
    // Display settings, so it is worth a log line the moment it appears.
    private func reportGamma() {
        let states = GammaState.capture()
        guard !states.isEmpty else { gammaWasLinear = nil; return }
        let linear = states.allSatisfy(\.isLinear)
        defer { gammaWasLinear = linear }
        guard gammaWasLinear != linear else { return }
        if linear {
            logger.notice("Gamma table back to linear on the DASUNG outputs.")
        } else {
            for state in states where !state.isLinear {
                logger.error("Gamma table crushed on DASUNG ProductID \(state.product, privacy: .public): ceiling \(state.ceiling, privacy: .public) instead of 1.0. On e-ink this collapses contrast — check BetterDisplay's software brightness or any other tool writing the table.")
            }
        }
    }

    private func disconnect() {
        serial = nil; selectedPath = nil; firmware = nil
    }

    private func sendMacStatus(_ serial: SerialPort) throws {
        let products = Set((inventory?.displays ?? []).filter(\.isDasung).map(\.product))
        try DitheringState.requireDisabled(DitheringState.capture(), products: products)
        try serial.send(Frame(0x20, 1))
    }

    private func transition(_ state: String, _ message: String) {
        if self.state != state || self.message != message {
            logger.notice("\(state, privacy: .public): \(message, privacy: .public)")
        }
        self.state = state; self.message = message
    }

    private func status() -> [String: Any] {
        // With the HUD, "zero windows" no longer describes the agent; what still
        // holds is that it never becomes the active application, so that is
        // what `takesFocus` reports.
        let ui = DispatchQueue.main.sync {
            (NSApp.activationPolicy(), NSApp.isActive, NSApp.windows.filter(\.isVisible).count)
        }
        var result: [String: Any] = ["ok": true, "state": state, "message": message,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "startedAt": ISO8601DateFormatter().string(from: started),
            "keepaliveIntervalSeconds": 2, "takesFocus": ui.0 == .regular || ui.1,
            "activationPolicy": ui.0.rawValue, "visibleWindowCount": ui.2, "hud": hudEnabled]
        result["controlEnabled"] = controlEnabled
        result["port"] = selectedPath
        result["firmware"] = firmware.map { String(format: "0x%02X", $0) }
        result["lastKeepaliveSentAt"] = lastKeepalive
        result["lastReplyAt"] = lastReply
        result["recentFrames"] = serial?.lastFrames
        result["ditheringReasserts"] = ditheringReasserts
        result["displayReconfigurations"] = displayReconfigurations
        result["reconfigurationCallbackRegistered"] = reconfigurationCallbackRegistered
        result["lastDitheringReassert"] = lastDitheringReassert
        if let data = try? JSONEncoder().encode(lastDitheringApplied) {
            result["lastDitheringApplied"] = try? JSONSerialization.jsonObject(with: data)
        }
        if let data = try? JSONEncoder().encode(GammaState.capture()) {
            result["gamma"] = try? JSONSerialization.jsonObject(with: data)
        }
        result["hotkeys"] = shortcuts
        result["configurationPath"] = Configuration.path
        result["configurationProblems"] = configurationProblems
        result["lastShortcutResult"] = lastShortcutResult
        if let data = try? JSONEncoder().encode(DitheringState.capture()) {
            result["dithering"] = try? JSONSerialization.jsonObject(with: data)
        }
        if let inventory, let data = try? JSONEncoder().encode(inventory) {
            result["inventory"] = try? JSONSerialization.jsonObject(with: data)
        }
        return result
    }
}
