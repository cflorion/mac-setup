import AppKit
import OSLog
import PaperlikeCore

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
        do {
            let current = Inventory.capture()
            inventory = current
            guard controlEnabled else {
                transition(current.displays.contains(where: \.isDasung) ? "detected" : "waiting",
                           "Mode observation : détection uniquement, sans ouverture du port USB.")
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
