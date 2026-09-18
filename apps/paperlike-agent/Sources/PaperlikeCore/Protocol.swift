import Foundation

public struct PaperlikeError: Error, CustomStringConvertible {
    public let description: String
    // A stable identifier for the few failures the HUD words differently from
    // the full sentence, which is written for the command line.
    public let code: String?
    public init(_ description: String, code: String? = nil) {
        self.description = description; self.code = code
    }
}

// ASCII protocol observed in the official macOS client and independent USB
// captures. See RESEARCH.md; these are protocol facts, not vendor source code.
public struct Frame: Equatable {
    public let bytes: [UInt8]
    public var command: UInt8 { bytes[0] }
    public var value: UInt8 { bytes[1] }
    public var ascii: String {
        "5FF5" + bytes.map { String(format: "%02X", $0) }.joined() + "A0FA"
    }
    public init(_ command: UInt8, _ value: UInt8 = 0) {
        bytes = [command, value, 0, 0, 0, 0, 0, 0]
    }
    init(bytes: [UInt8]) { self.bytes = bytes }

    public func registerValue(_ register: UInt8) -> UInt8? {
        // Query replies: 5FF5 [00 or F0] 0A <register> <value> ... A0FA.
        guard [0x00, 0xf0].contains(command), value == 0x0a,
              bytes[2] == register else { return nil }
        return bytes[3]
    }

    public func acknowledges(_ sent: Frame) -> Bool {
        command == 0xf0 && value == sent.command && bytes.dropFirst(2).allSatisfy { $0 == 0 }
    }
}

public struct FrameParser {
    private var buffer: [UInt8] = []
    public init() {}
    public mutating func append(_ data: Data) -> [Frame] {
        buffer.append(contentsOf: data)
        var frames: [Frame] = []
        let header = Array("5FF5".utf8), trailer = Array("A0FA".utf8)
        // Normalize lowercase hex without accepting arbitrary Unicode input.
        buffer = buffer.map { (97...102).contains($0) ? $0 - 32 : $0 }
        while buffer.count >= 4 {
            guard buffer.starts(with: header) else { buffer.removeFirst(); continue }
            guard buffer.count >= 24 else { break }
            let candidate = Array(buffer.prefix(24))
            let payload = String(bytes: candidate[4..<20], encoding: .ascii) ?? ""
            let hex = Array(payload.utf8)
            guard candidate.suffix(4).elementsEqual(trailer), hex.count == 16,
                  hex.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else {
                buffer.removeFirst(); continue
            }
            let bytes = stride(from: 0, to: 16, by: 2).map {
                UInt8(String(bytes: hex[$0..<$0+2], encoding: .ascii)!, radix: 16)!
            }
            frames.append(Frame(bytes: bytes))
            buffer.removeFirst(24)
        }
        return frames
    }
}

// Every writable setting the official client drives, with the command byte each
// one carries. The mapping was read off the client's own update methods — see
// RESEARCH.md. Two commands are deliberately absent: 0x05 is the device's
// real-time clock, and 0x13 is the model identifier (see Model). Neither is
// exposed for writing.
public struct Setting: Equatable {
    public let name: String
    public let command: UInt8
    public let bounds: ClosedRange<Int>
    public let summary: String
    // Some registers are only writable once another one is on. The monitor
    // silently keeps the old value otherwise, so the dependency is declared
    // here and checked before writing rather than reported as a bounds error.
    public let requires: Requirement?

    public struct Requirement: Equatable {
        public let command: UInt8
        public let explanation: String
        public let code: String
    }

    public static let all: [Setting] = [
        Setting(name: "contrast", command: 0x01, bounds: 1...9,
                summary: "Contrast (the client's “Contrast Level”)", requires: nil),
        // The register's values differ per model (see DisplayMode); the bounds
        // only span every model's, the agent checks the monitor's own list.
        Setting(name: "mode", command: 0x02, bounds: 2...7,
                summary: "Display mode: next, or a name (text, image, web, active, auto)", requires: nil),
        Setting(name: "speed", command: 0x04, bounds: 1...5,
                summary: "Refresh speed: 1 slow and clean, 5 fast", requires: nil),
        // The mode is a temperature preset: mode 1 reads back temperature 100,
        // and writing a temperature switches to mode 3 (observed on the 13K).
        Setting(name: "light-mode", command: 0x07, bounds: 0...3,
                summary: "Front light: mode (0 off, 3 custom temperature)", requires: nil),
        Setting(name: "light-temp", command: 0x08, bounds: 0...100,
                summary: "Front light: temperature, 0 cool to 100 warm (selects mode 3)", requires: nil),
        Setting(name: "light", command: 0x09, bounds: 0...100,
                summary: "Front light: brightness (0 switches it off)", requires: Requirement(command: 0x07,
                    explanation: "the front light is off; switch it on first with “paperlike light on”",
                    code: "light-off")),
        Setting(name: "text-enhance", command: 0x12, bounds: 0...1,
                summary: "Text enhancement: 0 off, 1 on", requires: nil),
    ]

    public static func named(_ name: String) -> Setting? { all.first { $0.name == name } }
}

// A hotkey adjusts a setting without knowing its current value, so relative
// changes are resolved against a fresh read rather than a cached figure.
public enum Adjustment: Equatable {
    case absolute(Int)
    case relative(Int)

    public func resolve(from current: Int, within bounds: ClosedRange<Int>) -> Int {
        switch self {
        case .absolute(let value): return value
        case .relative(let delta): return min(max(current + delta, bounds.lowerBound), bounds.upperBound)
        }
    }
}

// The front light as a single level where 0 means off, the way a brightness
// key behaves. The monitor ignores brightness while its light is off, so
// "brighter" from off has to switch it on, and reaching zero switches it off
// instead of leaving it lit at a zero level.
public enum FrontLight {
    public enum Step: Equatable {
        case stay(Int)       // nothing to write; the level as seen, 0 when off
        case switchOff       // mode 0; the brightness register keeps its value
        case setLevel(Int)   // light already on: write the brightness
        case switchOn(Int)   // write the mode, then the brightness
    }

    public static func step(isOn: Bool, level: Int, by adjustment: Adjustment,
                            within bounds: ClosedRange<Int>) -> Step {
        let current = isOn ? level : 0
        let target = adjustment.resolve(from: current, within: bounds)
        if target <= 0 { return isOn ? .switchOff : .stay(0) }
        if target == current { return .stay(current) }
        return isOn ? .setLevel(target) : .switchOn(target)
    }
}

// Switching the front light is its own action rather than a value of
// `light-mode`: on/off is what a shortcut wants, and 1–3 are panel modes the
// agent has no business choosing between on the user's behalf.
public enum Power: String, Equatable {
    case on, off, toggle
}

// The display mode (register 0x02), as the official client lists it per model
// (`updateDisplayVersonModes`, `updateCurrentModeValueInfo`): four modes (three
// on the black-and-white 253), in the client's order, which is also the order
// its own mode hotkey cycles through. The same name does not carry the same
// value from one model to the next, hence a table rather than bounds. See
// RESEARCH.md.
public struct DisplayMode: Equatable {
    public let name: String
    public let value: Int
    // What the register reads once the mode is set, when it is not the value
    // written: the 13K takes web as 6 and reports it as 1.
    public let readBack: Int
    public init(_ name: String, _ value: Int, readBack: Int? = nil) {
        self.name = name; self.value = value; self.readBack = readBack ?? value
    }

    public static let names = ["text", "image", "web", "active", "auto"]

    public static func modes(of model: Model) -> [DisplayMode] {
        switch model {
        case .color13K, .mono13K:
            return [DisplayMode("web", 6, readBack: 1), DisplayMode("text", 2), DisplayMode("image", 3), DisplayMode("active", 7)]
        case .paperlike103:
            return [DisplayMode("auto", 5), DisplayMode("text", 2), DisplayMode("image", 3), DisplayMode("active", 7)]
        case .color253:
            return [DisplayMode("image", 3), DisplayMode("active", 4), DisplayMode("web", 5), DisplayMode("text", 2)]
        // The client offers web too, but the black-and-white 253 (MCU 0x10)
        // does not take it: writing 5 reads back 2, text.
        case .mono253:
            return [DisplayMode("image", 3), DisplayMode("active", 4), DisplayMode("text", 2)]
        }
    }

    // A value the table does not know (set by another tool, or the monitor's
    // own buttons) restarts the cycle at the first mode.
    public static func choose(_ choice: ModeChoice, current: Int, among modes: [DisplayMode]) throws -> DisplayMode {
        switch choice {
        case .next:
            guard let index = modes.firstIndex(where: { $0.readBack == current }) else { return modes[0] }
            return modes[(index + 1) % modes.count]
        case .named(let name):
            guard let mode = modes.first(where: { $0.name == name }) else {
                throw PaperlikeError("This monitor has no “\(name)” mode; it has \(modes.map(\.name).joined(separator: ", ")).")
            }
            return mode
        }
    }
}

public enum ModeChoice: Equatable {
    case next
    case named(String)
}

public enum Action: Equatable {
    case refresh
    case set(Setting, Adjustment)
    case light(Power)
    case mode(ModeChoice)
    // Ghost cleanup drawn by the host rather than asked of the monitor: the
    // panel is flashed black then white, which drives every pixel through the
    // full range. It needs no USB link, so it also serves a Paperlike plugged
    // in by HDMI alone — which `refresh` cannot reach.
    case clear

    public static func parse(_ args: [String]) throws -> Action {
        if args == ["refresh"] { return .refresh }
        if args == ["clear"] { return .clear }
        if args.count == 2, args[0] == "light", let power = Power(rawValue: args[1]) { return .light(power) }
        // Modes are chosen by name: the number behind a name depends on the
        // model, which is only known once the command reaches a monitor.
        if args.count == 2, args[0] == "mode" {
            if args[1] == "next" { return .mode(.next) }
            guard DisplayMode.names.contains(args[1]) else {
                throw PaperlikeError("mode expects next or a name: \(DisplayMode.names.joined(separator: ", ")).")
            }
            return .mode(.named(args[1]))
        }
        guard args.count == 2, let setting = Setting.named(args[0]) else {
            throw PaperlikeError("Unknown command. See paperlike help.")
        }
        let raw = args[1]
        // A leading sign means "move by this much", so "light +10" differs from
        // "light 10". Int() accepts a leading "+", hence the explicit check.
        if raw.hasPrefix("+") || raw.hasPrefix("-"), let delta = Int(raw), delta != 0 {
            return .set(setting, .relative(delta))
        }
        guard let value = Int(raw), setting.bounds.contains(value) else {
            throw PaperlikeError("\(setting.name) expects a value from \(setting.bounds.lowerBound) to \(setting.bounds.upperBound), or a signed step such as +1.")
        }
        return .set(setting, .absolute(value))
    }

    public var register: UInt8? {
        switch self {
        case .refresh, .clear: return nil
        case .set(let setting, _): return setting.command
        case .light: return Setting.named("light-mode")?.command
        case .mode: return Setting.named("mode")?.command
        }
    }

    // Nil for `clear`: it has no wire form, so it can never become a write.
    public func frame(value: Int) -> Frame? {
        switch self {
        case .refresh: return Frame(0x03)
        case .set(let setting, _): return Frame(setting.command, UInt8(value))
        case .light: return Frame(register ?? 0x07, UInt8(value))
        case .mode: return Frame(register ?? 0x02, UInt8(value))
        case .clear: return nil
        }
    }

    // What observation mode keeps: it never opens the port, so only an action
    // that does without it is worth a shortcut there.
    public var needsUSB: Bool { self != .clear }

    // The command-line form, so a reply can name what it did.
    public var arguments: [String] {
        switch self {
        case .refresh: return ["refresh"]
        case .clear: return ["clear"]
        case .set(let setting, .absolute(let value)): return [setting.name, String(value)]
        case .set(let setting, .relative(let delta)): return [setting.name, delta > 0 ? "+\(delta)" : String(delta)]
        case .light(let power): return ["light", power.rawValue]
        case .mode(.next): return ["mode", "next"]
        case .mode(.named(let name)): return ["mode", name]
        }
    }

    // Rapid presses of one shortcut collapse into a single move: each exchange
    // reads, writes and reads back, so five presses become one round-trip
    // instead of five queued ones. Only relative moves of the same setting
    // merge; everything else keeps its order.
    public func merged(with next: Action) -> Action? {
        guard case .set(let setting, .relative(let first)) = self,
              case .set(let other, .relative(let second)) = next, setting == other else { return nil }
        return .set(setting, .relative(first + second))
    }

    public var isNoOp: Bool {
        if case .set(_, .relative(0)) = self { return true }
        return false
    }
}

public enum ProtocolIdentity {
    // These are the four MCU codes accepted by the installed official client.
    public static func isSupported(_ firmware: UInt8) -> Bool {
        [0x10, 0x11, 0x30, 0x31].contains(firmware)
    }
}
