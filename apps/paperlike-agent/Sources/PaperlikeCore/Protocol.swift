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

public enum Action: Equatable {
    case refresh, contrast(Int), speed(Int)

    public static func parse(_ args: [String]) throws -> Action {
        switch args.first {
        case "refresh" where args.count == 1: return .refresh
        case "contrast" where args.count == 2:
            guard let value = Int(args[1]), (1...9).contains(value) else {
                throw PaperlikeError("Le contraste doit être compris entre 1 et 9.")
            }
            return .contrast(value)
        case "speed" where args.count == 2:
            guard let value = Int(args[1]), (1...5).contains(value) else {
                throw PaperlikeError("La vitesse doit être comprise entre 1 et 5.")
            }
            return .speed(value)
        default: throw PaperlikeError("Commande inconnue. Utiliser paperlike help.")
        }
    }

    public var frame: Frame {
        switch self {
        case .refresh: return Frame(0x03)
        case .contrast(let value): return Frame(0x01, UInt8(value))
        case .speed(let value): return Frame(0x04, UInt8(value))
        }
    }
    public var register: UInt8? {
        switch self {
        case .refresh: return nil
        case .contrast: return 0x01
        case .speed: return 0x04
        }
    }
}

public enum ProtocolIdentity {
    // These are the four MCU codes accepted by the installed official client.
    public static func isSupported(_ firmware: UInt8) -> Bool {
        [0x10, 0x11, 0x30, 0x31].contains(firmware)
    }
}
