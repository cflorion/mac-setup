import Foundation

public struct PaperlikeError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
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
// real-time clock, and 0x13 is unidentified. Neither is exposed for writing.
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
    }

    public static let all: [Setting] = [
        Setting(name: "contrast", command: 0x01, bounds: 1...9,
                summary: "Contraste (« Contrast Level » du client)", requires: nil),
        Setting(name: "mode", command: 0x02, bounds: 1...2,
                summary: "Mode d’affichage : 1 texte, 2 image", requires: nil),
        Setting(name: "speed", command: 0x04, bounds: 1...5,
                summary: "Vitesse de rafraîchissement : 1 lent et propre, 5 rapide", requires: nil),
        Setting(name: "light-mode", command: 0x07, bounds: 0...3,
                summary: "Lumière frontale : mode (0 éteinte)", requires: nil),
        Setting(name: "light-temp", command: 0x08, bounds: 0...100,
                summary: "Lumière frontale : température, 0 froide à 100 chaude", requires: nil),
        Setting(name: "light", command: 0x09, bounds: 0...100,
                summary: "Lumière frontale : luminosité", requires: Requirement(command: 0x07,
                    explanation: "la lumière frontale est éteinte ; l’allumer d’abord avec « paperlike light-mode 1 »")),
        Setting(name: "text-enhance", command: 0x12, bounds: 0...1,
                summary: "Rehaussement du texte : 0 désactivé, 1 activé", requires: nil),
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

public enum Action: Equatable {
    case refresh
    case set(Setting, Adjustment)

    public static func parse(_ args: [String]) throws -> Action {
        if args == ["refresh"] { return .refresh }
        guard args.count == 2, let setting = Setting.named(args[0]) else {
            throw PaperlikeError("Commande inconnue. Utiliser paperlike help.")
        }
        let raw = args[1]
        // A leading sign means "move by this much", so "light +10" differs from
        // "light 10". Int() accepts a leading "+", hence the explicit check.
        if raw.hasPrefix("+") || raw.hasPrefix("-"), let delta = Int(raw), delta != 0 {
            return .set(setting, .relative(delta))
        }
        guard let value = Int(raw), setting.bounds.contains(value) else {
            throw PaperlikeError("\(setting.name) attend une valeur de \(setting.bounds.lowerBound) à \(setting.bounds.upperBound), ou un écart signé comme +1.")
        }
        return .set(setting, .absolute(value))
    }

    public var register: UInt8? {
        switch self {
        case .refresh: return nil
        case .set(let setting, _): return setting.command
        }
    }

    public func frame(value: Int) -> Frame {
        switch self {
        case .refresh: return Frame(0x03)
        case .set(let setting, _): return Frame(setting.command, UInt8(value))
        }
    }
}

public enum ProtocolIdentity {
    // These are the four MCU codes accepted by the installed official client.
    public static func isSupported(_ firmware: UInt8) -> Bool {
        [0x10, 0x11, 0x30, 0x31].contains(firmware)
    }
}
