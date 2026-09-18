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

// One Paperlike under USB control. Owned by the agent's queue; dropping it
// closes the port.
private final class Link {
    let serial: SerialPort
    var monitor: Monitor
    var lastHealthCheck = ProcessInfo.processInfo.systemUptime
    init(serial: SerialPort, monitor: Monitor) { self.serial = serial; self.monitor = monitor }
}

final class Agent {
    let queue = DispatchQueue(label: "com.user.paperlike-agent.hardware", qos: .utility)
    private let logger = Logger(subsystem: "com.user.paperlike-agent", category: "connection")
    private var timer: DispatchSourceTimer?
    // Every Paperlike under USB control, by port path. Each one is identified
    // and kept alive on its own: a monitor unplugged or silent never costs the
    // other one its link.
    private var links: [String: Link] = [:]
    // Ports that failed identification, and when to ask again. A CH340 that is
    // not a Paperlike is asked for its MCU every `probeRetry` seconds, not on
    // every tick.
    private var probeFailures: [String: (retryAt: TimeInterval, reason: String)] = [:]
    private var inventory: Inventory?
    private var state = "starting"
    private var message = "Starting."
    private var sleeping = false
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
    // was last in use on that monitor. Kept per model, since two monitors do
    // not share a mode, and across restarts, since every reinstall restarts
    // the agent. Falls back to 1 before any mode has been seen.
    private var lastLightModes = UserDefaults.standard.dictionary(forKey: "lastLightModes") as? [String: Int] ?? [:] {
        didSet { UserDefaults.standard.set(lastLightModes, forKey: "lastLightModes") }
    }
    private let controlEnabled: Bool
    private let hudEnabled: Bool
    private let screenClear = ScreenClear()

    private let configurationProblems: [String]

    private static let observationOnly = PaperlikeError(
        "Observation mode: no USB command is sent. Control is disabled.", code: "observation")
    // Spacing between two setting commands. Rapid shortcut presses are merged
    // upstream, so this only ever delays a command, never refuses one.
    private static let minimumSpacing = 0.1
    // The level used when the light is switched on while its brightness
    // register reads zero; see `switchLight`.
    private static let initialBrightness = 20
    private static let probeRetry = 10.0

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
    // repeated writes cost nothing because `disableOnPaperlike` skips any
    // output already at false.
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
            if value { self.links.removeAll(); self.transition("sleeping", "Mac asleep.") }
            else { self.tick() }
        }
    }

    func request(_ args: [String]) -> [String: Any] {
        let request = Request(args)
        let arguments = request.arguments
        if arguments == ["status"] { return queue.sync { status() } }
        let diagnostic = arguments == ["query"] || (arguments.count == 2 && arguments[0] == "read")
        guard diagnostic else {
            do { return perform(try Action.parse(arguments), monitor: request.monitor) } catch { return Agent.failure(error) }
        }
        return queue.sync {
            do {
                guard controlEnabled else { throw Agent.observationOnly }
                let link = try target(request.monitor)
                let serial = link.serial
                if arguments.count == 2 {
                    // Diagnostic: 0x0A + register is a non-destructive read, so an
                    // arbitrary register is safe to expose. Writing is not.
                    guard let register = UInt8(arguments[1].replacingOccurrences(of: "0x", with: ""), radix: 16) else {
                        throw PaperlikeError("Expected a hexadecimal register, for example: paperlike read 09.")
                    }
                    try sendMacStatus(serial)
                    return ["ok": true, "monitor": link.monitor.name, "register": String(format: "0x%02X", register),
                            "value": Int(try serial.query(register))]
                }
                try sendMacStatus(serial)
                var registers = ["firmware": Int(try serial.query(0x10)), "model": Int(try serial.query(Model.register))]
                for setting in Setting.all { registers[setting.name] = Int(try serial.query(setting.command)) }
                return ["ok": true, "monitor": link.monitor.name, "port": link.monitor.path,
                        "registers": registers, "received": serial.lastFrames]
            } catch {
                return Agent.failure(error)
            }
        }
    }

    // Every setting command, from the command line or a shortcut. The reply
    // carries what the HUD needs (setting, bounds, value), so feedback never
    // costs a serial exchange of its own.
    func perform(_ action: Action, monitor name: String? = nil) -> [String: Any] {
        // Drawn on screen, not sent over USB: it runs in observation mode too,
        // and off `queue`, so the flash never delays anti-dithering.
        if action == .clear { return screenClear.run(monitor: name) }
        return queue.sync {
            do {
                guard controlEnabled else { throw Agent.observationOnly }
                let link = try target(name)
                let serial = link.serial
                let wait = lastAction + Agent.minimumSpacing - ProcessInfo.processInfo.systemUptime
                if wait > 0 { Thread.sleep(forTimeInterval: wait) }
                defer { lastAction = ProcessInfo.processInfo.systemUptime }
                try sendMacStatus(serial)
                _ = try serial.readFrames(timeout: 0.02)

                var response: [String: Any] = ["ok": true, "action": action.arguments.joined(separator: " "),
                                               "monitor": link.monitor.name]
                switch action {
                case .clear:
                    break
                case .refresh:
                    guard let frame = action.frame(value: 0) else { break }
                    try serial.send(frame)
                    let replies = try serial.readFrames(timeout: 0.25) { $0.contains { $0.acknowledges(frame) } }
                    response["received"] = replies.map(\.ascii)
                    response["delivery"] = replies.contains(where: { $0.acknowledges(frame) })
                        ? "acknowledged_by_device" : "sent"
                    response["note"] = "The visual effect of the cleanup can only be checked on the panel."
                case .set(let setting, let adjustment):
                    try set(setting, adjustment, on: link, into: &response)
                case .light(let power):
                    try switchLight(power, on: link, into: &response)
                case .mode(let choice):
                    try switchMode(choice, on: link, into: &response)
                }
                lastReply = ISO8601DateFormatter().string(from: Date())
                return response
            } catch {
                return Agent.failure(error)
            }
        }
    }

    // The monitor a command acts on — see Targeting. On `queue`; the display
    // under the pointer is read through CoreGraphics, with no hop to the main
    // thread.
    private func target(_ name: String?) throws -> Link {
        guard !links.isEmpty else { throw PaperlikeError(message, code: "unavailable") }
        inferModels()
        let monitors = links.values.map(\.monitor).sorted { $0.path < $1.path }
        let chosen = try Targeting.choose(monitors, named: name, pointer: name == nil ? Display.underPointer() : nil,
                                          screens: inventory?.displays ?? [])
        guard let link = links[chosen.path] else { throw PaperlikeError(message, code: "unavailable") }
        return link
    }

    private func inferModels() {
        for monitor in Monitor.inferModels(links.values.map(\.monitor), screens: inventory?.displays ?? []) {
            links[monitor.path]?.monitor = monitor
        }
    }

    private func set(_ setting: Setting, _ adjustment: Adjustment, on link: Link,
                     into response: inout [String: Any]) throws {
        let serial = link.serial
        response["setting"] = setting.name
        response["bounds"] = [setting.bounds.lowerBound, setting.bounds.upperBound]
        if setting.name == "light" { return try adjustLight(setting, adjustment, on: link, into: &response) }
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
        if setting.name == "light-mode" { rememberLightMode(target, of: link.monitor) }
    }

    // Brightness as one level where 0 means off — see FrontLight. Switching
    // off leaves the brightness register alone, so the toggle brings the last
    // level back.
    private func adjustLight(_ light: Setting, _ adjustment: Adjustment, on link: Link,
                             into response: inout [String: Any]) throws {
        guard let mode = Setting.named("light-mode") else { return }
        let serial = link.serial
        let current = Int(try serial.query(mode.command))
        rememberLightMode(current, of: link.monitor)
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
            received += try write(mode, lastLightMode(of: link.monitor), on: serial)
            received += try write(light, value, on: serial)
            response["value"] = value
            response["power"] = "on"
        }
        response["received"] = received
        response["delivery"] = received.isEmpty && response["value"] as? Int == level ? "unchanged" : "confirmed_by_readback"
    }

    // The current mode is read fresh, as for a relative setting: the monitor's
    // own buttons change it too. A monitor whose model is unknown is refused
    // rather than given another model's values.
    private func switchMode(_ choice: ModeChoice, on link: Link, into response: inout [String: Any]) throws {
        guard let setting = Setting.named("mode") else { return }
        guard let model = link.monitor.model else {
            throw PaperlikeError("\(link.monitor.name): unknown model, so its display modes are unknown.")
        }
        let modes = DisplayMode.modes(of: model)
        let before = Int(try link.serial.query(setting.command))
        let target = try DisplayMode.choose(choice, current: before, among: modes)
        response["setting"] = setting.name
        response["modes"] = modes.map(\.name)
        response["mode"] = target.name
        response["from"] = before
        response["value"] = target.readBack
        guard target.readBack != before else {
            response["delivery"] = "unchanged"
            return
        }
        response["received"] = try write(setting, target.value, on: link.serial, expecting: target.readBack)
        response["delivery"] = "confirmed_by_readback"
    }

    // The panel keeps its brightness register while the light is off, so
    // switching back on normally restores the previous level. Only a level of
    // zero is raised: a light switched "on" at zero changes nothing on the
    // panel, which reads as a broken shortcut.
    private func switchLight(_ power: Power, on link: Link, into response: inout [String: Any]) throws {
        guard let mode = Setting.named("light-mode"), let light = Setting.named("light") else { return }
        let serial = link.serial
        let current = Int(try serial.query(mode.command))
        rememberLightMode(current, of: link.monitor)
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
        if current == 0 { received += try write(mode, lastLightMode(of: link.monitor), on: serial) }
        var level = Int(try serial.query(light.command))
        if level == 0 {
            received += try write(light, Agent.initialBrightness, on: serial)
            level = Agent.initialBrightness
        }
        response["received"] = received
        response["value"] = level
        response["delivery"] = current == 0 || !received.isEmpty ? "confirmed_by_readback" : "unchanged"
    }

    private func lastLightMode(of monitor: Monitor) -> Int {
        let mode = lastLightModes[monitor.key] ?? 1
        return (1...3).contains(mode) ? mode : 1
    }

    // Only a lit mode is remembered: 0 is "off", not a mode to restore.
    private func rememberLightMode(_ mode: Int, of monitor: Monitor) {
        guard (1...3).contains(mode), lastLightModes[monitor.key] != mode else { return }
        lastLightModes[monitor.key] = mode
    }

    // Read-back is the contract for every write: the vendor client
    // acknowledged commands that had not landed, which is precisely the
    // failure this agent exists to avoid. An acknowledgement only ends the
    // wait early; it is never taken as proof.
    private func write(_ setting: Setting, _ value: Int, on serial: SerialPort, expecting expected: Int? = nil) throws -> [String] {
        let frame = Frame(setting.command, UInt8(value))
        try serial.send(frame)
        let received = try serial.readFrames(timeout: 0.25) { $0.contains { $0.acknowledges(frame) } }
        let actual = Int(try serial.query(setting.command))
        let expected = expected ?? value
        guard actual == expected else {
            throw PaperlikeError("Command sent, but the read-back gives \(actual) instead of \(expected). The monitor may have clamped the value.")
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
        guard controlEnabled else {
            transition(current.displays.contains(where: \.isPaperlike) ? "detected" : "waiting",
                       "Anti-dithering applied; USB control disabled.")
            return
        }
        let candidates: [SerialDevice]
        do { candidates = try current.controlCandidates() } catch {
            links.removeAll(); probeFailures.removeAll()
            transition("waiting", String(describing: error))
            return
        }
        let paths = Set(candidates.map(\.path))
        links = links.filter { paths.contains($0.key) }
        probeFailures = probeFailures.filter { paths.contains($0.key) }
        let now = ProcessInfo.processInfo.systemUptime
        for device in candidates where links[device.path] == nil {
            if let failure = probeFailures[device.path], now < failure.retryAt { continue }
            do {
                links[device.path] = try connect(device.path)
                probeFailures[device.path] = nil
            } catch {
                probeFailures[device.path] = (now + Agent.probeRetry, String(describing: error))
            }
        }
        for (path, link) in links {
            do { try keepAlive(link) } catch {
                // Identified once, so not a foreign adapter: retried next tick.
                links[path] = nil
                probeFailures[path] = (now, "\(link.monitor.name): \(error)")
            }
        }
        guard !links.isEmpty else {
            transition("waiting", probeFailures.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.reason)" }.joined(separator: " "))
            return
        }
        transition("connected", "USB control active: " + links.values.map(\.monitor).sorted { $0.path < $1.path }
            .map { "\($0.name) on \($0.path)" }.joined(separator: ", ") + ".")
    }

    private func connect(_ path: String) throws -> Link {
        let connection = try SerialPort(path: path)
        let version: UInt8
        do { version = try connection.query(0x10) }
        catch { throw PaperlikeError("\(error) Replies received: \(connection.lastFrames.joined(separator: ", "))") }
        guard ProtocolIdentity.isSupported(version) else {
            throw PaperlikeError(String(format: "Unrecognized MCU (0x%02X); no setting command sent.", version))
        }
        // An unknown model still connects: the MCU vouches for the protocol,
        // and only choosing a monitor by the pointer needs the model.
        let monitor = Monitor(path: path, firmware: version, modelCode: (try? connection.query(Model.register)) ?? 0)
        if let mode = try? connection.query(0x07) { rememberLightMode(Int(mode), of: monitor) }
        logger.notice("Identified \(monitor.name, privacy: .public) on \(path, privacy: .public).")
        return Link(serial: connection, monitor: monitor)
    }

    private func keepAlive(_ link: Link) throws {
        try sendMacStatus(link.serial)
        lastKeepalive = ISO8601DateFormatter().string(from: Date())
        let replies = try link.serial.readFrames(timeout: 0.02)
        if !replies.isEmpty { lastReply = lastKeepalive }
        if ProcessInfo.processInfo.systemUptime - link.lastHealthCheck >= 30 {
            guard try link.serial.query(0x10) == link.monitor.firmware else {
                throw PaperlikeError("The display's identity changed.")
            }
            link.lastHealthCheck = ProcessInfo.processInfo.systemUptime
            lastReply = ISO8601DateFormatter().string(from: Date())
        }
    }

    // macOS restores dithering on reconnect, wake and mode changes. Only a
    // framebuffer whose value is not already false is written, so the counter
    // below measures how often macOS actually resets it.
    private func enforceDithering() {
        let applied = DitheringState.disableOnPaperlike()
        guard !applied.isEmpty else { return }
        ditheringReasserts += applied.count
        lastDitheringReassert = ISO8601DateFormatter().string(from: Date())
        lastDitheringApplied = applied
        for entry in applied where !entry.succeeded {
            logger.error("Anti-dithering refused on vendor \(entry.vendor, privacy: .public) ProductID \(entry.product, privacy: .public): kern_return \(entry.result, privacy: .public).")
        }
        let restored = applied.filter(\.succeeded).count
        if restored > 0 {
            logger.notice("Anti-dithering restored on \(restored, privacy: .public) Paperlike output(s).")
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
            logger.notice("Gamma table back to linear on the Paperlike outputs.")
        } else {
            for state in states where !state.isLinear {
                logger.error("Gamma table crushed on Paperlike ProductID \(state.product, privacy: .public): ceiling \(state.ceiling, privacy: .public) instead of 1.0. On e-ink this collapses contrast — check BetterDisplay's software brightness or any other tool writing the table.")
            }
        }
    }

    // The 0x20 frame tells the monitor the host has dithering off, so it is
    // only sent once every Paperlike output reads back `enableDither = No`.
    private func sendMacStatus(_ serial: SerialPort) throws {
        let panels = Set((inventory?.displays ?? []).filter(\.isPaperlike).map(\.panel))
        try DitheringState.requireDisabled(DitheringState.capture(), panels: panels)
        try serial.send(Frame(0x20, 1))
    }

    private func transition(_ state: String, _ message: String) {
        if self.state != state || self.message != message {
            logger.notice("\(state, privacy: .public): \(message, privacy: .public)")
        }
        self.state = state; self.message = message
    }

    private func status() -> [String: Any] {
        inferModels()
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
        result["monitors"] = links.values.sorted { $0.monitor.path < $1.monitor.path }.map { link -> [String: Any] in
            ["name": link.monitor.name, "port": link.monitor.path,
             "firmware": String(format: "0x%02X", link.monitor.firmware),
             "model": Int(link.monitor.modelCode), "names": link.monitor.model?.names ?? [],
             "inferredModel": link.monitor.inferred?.name ?? NSNull(),
             "lightModeRestored": lastLightMode(of: link.monitor), "recentFrames": link.serial.lastFrames]
        }
        result["portProblems"] = probeFailures.mapValues(\.reason)
        result["lastKeepaliveSentAt"] = lastKeepalive
        result["lastReplyAt"] = lastReply
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
