import Foundation

// EDID identities of Paperlike outputs. The 253 and the 103 carry DASUNG's own
// manufacturer ID. The 13K's video goes through a Realtek scaler that reports
// Realtek's generic EDID (`RTK FHD`, product 447), so it is matched on vendor
// and product together — never on the Realtek vendor alone, which any monitor
// built on that scaler family shares.
public enum Panel {
    public static let dasungVendor: UInt32 = 0x1263
    public static let realtekVendor: UInt32 = 0x4a8b
    public static let paperlike13KProduct: UInt32 = 447

    public static func is13K(vendor: UInt32, product: UInt32) -> Bool {
        vendor == realtekVendor && product == paperlike13KProduct
    }

    public static func isPaperlike(vendor: UInt32, product: UInt32) -> Bool {
        vendor == dasungVendor || is13K(vendor: vendor, product: product)
    }
}

public struct PanelID: Hashable, Codable {
    public let vendor: UInt32
    public let product: UInt32
    public init(vendor: UInt32, product: UInt32) { self.vendor = vendor; self.product = product }
}

// Register 0x13 names the model. The official client reads it into
// `displayVersionMode` and looks it up in `DeviceDisplayNameForMode`; these are
// that table's entries, in its order. Read-only: it is never written.
public enum Model: Int, CaseIterable {
    case color13K = 1, mono13K = 2, paperlike103 = 3, mono253 = 4, color253 = 5

    public static let register: UInt8 = 0x13

    public var name: String {
        switch self {
        case .color13K: return "13K Color"
        case .mono13K: return "13K"
        case .paperlike103: return "103"
        case .mono253: return "253"
        case .color253: return "253 Color"
        }
    }

    // What `paperlike <monitor> …` accepts: the family, and the family with its
    // colour for when two of one family are connected at once.
    public var names: [String] {
        switch self {
        case .color13K: return ["13k", "13k-color"]
        case .mono13K: return ["13k", "13k-bw"]
        case .paperlike103: return ["103"]
        case .mono253: return ["253", "253-bw"]
        case .color253: return ["253", "253-color"]
        }
    }

    public static let allNames = Set(allCases.flatMap(\.names))

    // The only link between a USB control port and a screen: the model the
    // port reports, against the EDID the screen reports. USB topology cannot
    // provide it — video and USB take separate paths through a dock.
    public func drives(vendor: UInt32, product: UInt32) -> Bool {
        switch self {
        case .color13K, .mono13K: return Panel.is13K(vendor: vendor, product: product)
        case .paperlike103, .mono253, .color253: return vendor == Panel.dasungVendor
        }
    }

    public static func any(named name: String, drives display: Display) -> Bool {
        allCases.contains { $0.names.contains(name) && $0.drives(vendor: display.vendor, product: display.product) }
    }
}

// A CH340 that answered a supported MCU: one Paperlike under USB control.
public struct Monitor: Equatable {
    public let path: String
    public let firmware: UInt8
    public let modelCode: UInt8
    public init(path: String, firmware: UInt8, modelCode: UInt8) {
        self.path = path; self.firmware = firmware; self.modelCode = modelCode
    }

    public var model: Model? { Model(rawValue: Int(modelCode)) }
    public var name: String { model?.name ?? "Paperlike (model \(modelCode))" }
    // Per-monitor preferences, such as the light mode to restore, are kept
    // under this key: stable across ports, unlike the path.
    public var key: String { model?.names.last ?? "model-\(modelCode)" }
}

// A command line, optionally prefixed by the monitor it is meant for:
// `paperlike 13k light +10`. Without a prefix the agent picks one itself.
public struct Request: Equatable {
    public let monitor: String?
    public let arguments: [String]

    public init(_ args: [String]) {
        if let first = args.first?.lowercased(), Model.allNames.contains(first) {
            monitor = first; arguments = Array(args.dropFirst())
        } else {
            monitor = nil; arguments = args
        }
    }
}

public enum Targeting {
    // Which monitor a command acts on. Named, that one. Otherwise the Paperlike
    // under the pointer — AeroSpace moves the pointer with monitor focus, as
    // for `clear` and the HUD — and from any other screen the only one under
    // control. Several candidates are refused, never guessed between: a
    // brightness key landing on the wrong panel reads as a broken shortcut.
    public static func choose(_ monitors: [Monitor], named name: String?, pointer: Display?) throws -> Monitor {
        if let name {
            let matching = monitors.filter { $0.model?.names.contains(name) == true }
            guard matching.count == 1 else {
                throw matching.isEmpty
                    ? PaperlikeError("No “\(name)” Paperlike under USB control; connected: \(list(monitors)).", code: "unavailable")
                    : PaperlikeError("Several Paperlike answer to “\(name)”; name one: \(matching.map(\.key).joined(separator: ", ")).", code: "ambiguous")
            }
            return matching[0]
        }
        var candidates = monitors
        if let pointer, pointer.isPaperlike {
            // A monitor whose model is unknown cannot be ruled out.
            candidates = monitors.filter { $0.model?.drives(vendor: pointer.vendor, product: pointer.product) ?? true }
            guard !candidates.isEmpty else {
                throw PaperlikeError("The Paperlike under the pointer has no USB control link; connected: \(list(monitors)).", code: "unavailable")
            }
        }
        guard candidates.count == 1 else {
            throw PaperlikeError(candidates.isEmpty
                ? "No Paperlike under USB control."
                : "Several Paperlike under USB control (\(list(candidates))): move the pointer onto the one to adjust, or name it, for example “paperlike \(candidates[0].model?.names.first ?? "13k") light on”.",
                code: candidates.isEmpty ? "unavailable" : "ambiguous")
        }
        return candidates[0]
    }

    private static func list(_ monitors: [Monitor]) -> String {
        monitors.isEmpty ? "none" : monitors.map(\.name).joined(separator: ", ")
    }
}
