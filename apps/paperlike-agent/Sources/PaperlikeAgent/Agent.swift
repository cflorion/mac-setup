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
    private var message = "Démarrage."
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
    private var shortcut: [String: Any] = [:]
    private var lastShortcutResult: [String: Any]?
    private let controlEnabled: Bool

    init(controlEnabled: Bool) { self.controlEnabled = controlEnabled }

    func recordShortcutRegistration(_ status: Int32) {
        queue.async {
            self.shortcut = ["keys": "Control+Option+Command+R", "registered": status == 0, "osStatus": status]
        }
    }

    func recordShortcutResult(_ reply: [String: Any]) {
        queue.async { self.lastShortcutResult = reply }
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
            logger.error("Callback de reconfiguration refusé (\(registration.rawValue, privacy: .public)) ; seul le minuteur de deux secondes couvre les rebranchements.")
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
            if value { self.disconnect(); self.transition("sleeping", "Mac en veille.") }
            else { self.tick() }
        }
    }

    func request(_ args: [String]) -> [String: Any] {
        queue.sync {
            do {
                if args == ["status"] { return status() }
                guard controlEnabled else {
                    throw PaperlikeError("Mode observation : aucune commande USB n’est envoyée. Le contrôle expérimental est désactivé.")
                }
                if args == ["query"] {
                    guard let serial else { throw PaperlikeError(message) }
                    try sendMacStatus(serial)
                    var registers: [String: Int] = [:]
                    for (name, register) in [("firmware", UInt8(0x10)), ("contrast", 0x01), ("mode", 0x02), ("speed", 0x04)] {
                        registers[name] = Int(try serial.query(register))
                    }
                    return ["ok": true, "registers": registers, "received": serial.lastFrames]
                }
                let action = try Action.parse(args)
                guard let serial else { throw PaperlikeError(message) }
                let now = ProcessInfo.processInfo.systemUptime
                guard now - lastAction >= 0.5 else { throw PaperlikeError("Commande trop rapprochée ; réessayer dans une seconde.") }
                lastAction = now
                try sendMacStatus(serial)
                _ = try serial.readFrames(timeout: 0.02)
                try serial.send(action.frame)
                let replies = try serial.readFrames(timeout: 0.25)
                var response: [String: Any] = ["ok": true, "action": args.joined(separator: " "),
                                                "delivery": "sent", "received": replies.map(\.ascii)]
                if let register = action.register {
                    let actual = try serial.query(register)
                    guard actual == action.frame.value else {
                        throw PaperlikeError("Commande envoyée, mais la relecture du réglage ne confirme pas la valeur demandée (\(actual)).")
                    }
                    response["delivery"] = "confirmed_by_readback"
                    response["value"] = actual
                } else {
                    if replies.contains(where: { $0.acknowledges(action.frame) }) {
                        response["delivery"] = "acknowledged_by_device"
                    }
                    response["note"] = "L’effet visuel de l’effacement reste à constater sur l’écran."
                }
                lastReply = ISO8601DateFormatter().string(from: Date())
                return response
            } catch {
                return ["ok": false, "error": String(describing: error)]
            }
        }
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
                           "Anti-dithering appliqué ; contrôle USB désactivé.")
                return
            }
            let device = try current.selectedDevice()
            if selectedPath != device.path { disconnect() }
            if serial == nil {
                let connection = try SerialPort(path: device.path)
                let version: UInt8
                do { version = try connection.query(0x10) }
                catch { throw PaperlikeError("\(error) Réponses reçues : \(connection.lastFrames.joined(separator: ", "))") }
                guard ProtocolIdentity.isSupported(version) else {
                    throw PaperlikeError(String(format: "MCU non reconnu (0x%02X) ; aucune commande de réglage envoyée.", version))
                }
                serial = connection; selectedPath = device.path; firmware = version
                lastHealthCheck = ProcessInfo.processInfo.systemUptime
            }
            guard let serial else { return }
            try sendMacStatus(serial)
            lastKeepalive = ISO8601DateFormatter().string(from: Date())
            let replies = try serial.readFrames(timeout: 0.02)
            if !replies.isEmpty { lastReply = lastKeepalive }
            if ProcessInfo.processInfo.systemUptime - lastHealthCheck >= 30 {
                let version = try serial.query(0x10)
                guard version == firmware else { throw PaperlikeError("L’identité de l’écran a changé.") }
                lastHealthCheck = ProcessInfo.processInfo.systemUptime
                lastReply = ISO8601DateFormatter().string(from: Date())
            }
            transition("connected", "Écran DASUNG identifié ; contrôle USB actif.")
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
            logger.error("Anti-dithering refusé sur ProductID \(entry.product, privacy: .public) : kern_return \(entry.result, privacy: .public).")
        }
        let restored = applied.filter(\.succeeded).count
        if restored > 0 {
            logger.notice("Anti-dithering rétabli sur \(restored, privacy: .public) sortie(s) DASUNG.")
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
            logger.notice("Table gamma redevenue linéaire sur les sorties DASUNG.")
        } else {
            for state in states where !state.isLinear {
                logger.error("Table gamma écrasée sur DASUNG ProductID \(state.product, privacy: .public) : plafond \(state.ceiling, privacy: .public) au lieu de 1.0. Sur e-ink cela effondre le contraste — vérifier la luminosité logicielle de BetterDisplay ou tout autre outil écrivant la table.")
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
        let ui = DispatchQueue.main.sync { (NSApp.activationPolicy().rawValue, NSApp.windows.count) }
        var result: [String: Any] = ["ok": true, "state": state, "message": message,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "startedAt": ISO8601DateFormatter().string(from: started),
            "keepaliveIntervalSeconds": 2, "headless": ui.0 == 2 && ui.1 == 0,
            "activationPolicy": ui.0, "windowCount": ui.1]
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
        result["refreshShortcut"] = shortcut
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
