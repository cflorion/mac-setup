import Carbon.HIToolbox
import Foundation

// Optional configuration, read once at startup from
// ~/.config/paperlike/config.json. There is no watcher and no reload: the agent
// stays a background process with no UI, and a keybinding is not worth a file
// descriptor held for the session's lifetime. An absent or unreadable file is
// normal and yields the defaults below.
public struct HotKeyBinding: Equatable {
    public let keys: String
    public let action: [String]
    public let parsed: Action
    public let keyCode: UInt32
    public let modifiers: UInt32

    public var describedAction: String { action.joined(separator: " ") }
}

public struct Configuration {
    public let hotkeys: [HotKeyBinding]
    // The on-screen feedback after a shortcut. On by default; `"hud": false`
    // brings back a strictly windowless agent.
    public let hud: Bool
    public let problems: [String]

    public static let path = NSString(string: "~/.config/paperlike/config.json").expandingTildeInPath

    // Control+Option+Command is "Meh": it excludes Shift, so Hyper shortcuts stay
    // free. Arrows are used for the adjustments because their key codes do not
    // move between keyboard layouts — on AZERTY a letter-based default would land
    // on a different physical key than the one printed in the documentation.
    // R, L and C sit at the same place on AZERTY and QWERTY.
    public static let defaultHotkeys: [(String, [String])] = [
        ("ctrl+alt+cmd+r", ["refresh"]),
        ("ctrl+alt+cmd+c", ["clear"]),
        ("ctrl+alt+cmd+l", ["light", "toggle"]),
        ("ctrl+alt+cmd+up", ["light", "+10"]),
        ("ctrl+alt+cmd+down", ["light", "-10"]),
        ("ctrl+alt+cmd+right", ["contrast", "+1"]),
        ("ctrl+alt+cmd+left", ["contrast", "-1"]),
    ]

    public static func load(from path: String = Configuration.path) -> Configuration {
        guard let data = FileManager.default.contents(atPath: path) else { return fallback([]) }
        do {
            let file = try JSONDecoder().decode(File.self, from: data)
            let hud = file.hud ?? true
            guard let entries = file.hotkeys, !entries.isEmpty else { return fallback([], hud: hud) }
            var bindings: [HotKeyBinding] = []
            var problems: [String] = []
            for entry in entries {
                do { bindings.append(try binding(keys: entry.keys, action: entry.action)) }
                catch { problems.append("\(entry.keys): \(error)") }
            }
            // A broken keybinding must never stop the agent: its one essential job
            // is keeping dithering off, and that has nothing to do with this file.
            return bindings.isEmpty ? fallback(problems, hud: hud) : Configuration(hotkeys: bindings, hud: hud, problems: problems)
        } catch {
            return fallback(["\(path) unreadable, defaults applied: \(error)"])
        }
    }

    // Observation mode never opens the USB port, so a shortcut that needs it
    // would only ever fail there; the ones that do without it stay.
    public func activeHotkeys(controlEnabled: Bool) -> [HotKeyBinding] {
        controlEnabled ? hotkeys : hotkeys.filter { !$0.parsed.needsUSB }
    }

    private static func fallback(_ problems: [String], hud: Bool = true) -> Configuration {
        Configuration(hotkeys: defaultHotkeys.compactMap { try? binding(keys: $0.0, action: $0.1) },
                      hud: hud, problems: problems)
    }

    public static func binding(keys: String, action: [String]) throws -> HotKeyBinding {
        guard let parsed = try? Action.parse(action) else {
            throw PaperlikeError("unknown action “\(action.joined(separator: " "))”")
        }
        var modifiers: UInt32 = 0
        var code: UInt32?
        for part in keys.lowercased().split(separator: "+").map(String.init) {
            switch part {
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            case "alt", "opt", "option": modifiers |= UInt32(optionKey)
            case "cmd", "command": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            default:
                guard code == nil, let resolved = keyCodes[part] else {
                    throw PaperlikeError("unknown or duplicate key “\(part)”")
                }
                code = resolved
            }
        }
        guard let code else { throw PaperlikeError("no key in “\(keys)”") }
        guard modifiers != 0 else { throw PaperlikeError("“\(keys)” has no modifier") }
        return HotKeyBinding(keys: keys, action: action, parsed: parsed, keyCode: code, modifiers: modifiers)
    }

    private struct File: Decodable {
        struct Entry: Decodable { let keys: String; let action: [String] }
        let hotkeys: [Entry]?
        let hud: Bool?
    }

    static let keyCodes: [String: UInt32] = {
        var map: [String: UInt32] = [
            "up": UInt32(kVK_UpArrow), "down": UInt32(kVK_DownArrow),
            "left": UInt32(kVK_LeftArrow), "right": UInt32(kVK_RightArrow),
            "space": UInt32(kVK_Space), "return": UInt32(kVK_Return),
            "pageup": UInt32(kVK_PageUp), "pagedown": UInt32(kVK_PageDown),
        ]
        let letters: [(String, Int)] = [
            ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D),
            ("e", kVK_ANSI_E), ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H),
            ("i", kVK_ANSI_I), ("j", kVK_ANSI_J), ("k", kVK_ANSI_K), ("l", kVK_ANSI_L),
            ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O), ("p", kVK_ANSI_P),
            ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
            ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X),
            ("y", kVK_ANSI_Y), ("z", kVK_ANSI_Z),
        ]
        // ANSI key codes are positional: "r" is the key at the ANSI R position,
        // whatever that key prints on the user's layout.
        for (name, code) in letters { map[name] = UInt32(code) }
        for (index, code) in [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                              kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0].enumerated() {
            map[String((index + 1) % 10)] = UInt32(code)
        }
        return map
    }()
}
