import Foundation

// What the HUD shows for one agent reply. Kept in Core and free of AppKit so the
// wording and the gauge arithmetic are tested; the agent only draws it. The
// reply is the one the action already produced — the HUD never costs a serial
// exchange of its own.
public struct HUDContent: Equatable {
    public let symbol: String
    public let title: String
    public let caption: String
    public let gauge: Gauge?

    public struct Gauge: Equatable {
        public let segments: Int
        public let filled: Int
    }

    private static let presentation: [String: (title: String, symbol: String)] = [
        "contrast": ("Contraste", "circle.lefthalf.filled"),
        "light": ("Lumière", "sun.max.fill"),
        "light-mode": ("Mode de lumière", "lightbulb"),
        "light-temp": ("Température", "thermometer.medium"),
        "speed": ("Vitesse", "speedometer"),
        "mode": ("Mode", "doc.text.image"),
        "text-enhance": ("Rehaussement", "textformat"),
    ]

    public init(symbol: String, title: String, caption: String, gauge: Gauge?) {
        self.symbol = symbol; self.title = title; self.caption = caption; self.gauge = gauge
    }

    public init?(reply: [String: Any]) {
        guard reply["ok"] as? Bool == true else {
            switch reply["code"] as? String {
            case "light-off":
                self.init(symbol: "lightbulb.slash", title: "Lumière", caption: "Éteinte", gauge: nil)
            case "unavailable":
                self.init(symbol: "cable.connector.slash", title: "Paperlike", caption: "Écran non joignable", gauge: nil)
            default:
                self.init(symbol: "exclamationmark.triangle", title: "Paperlike", caption: "Échec — paperlike status", gauge: nil)
            }
            return
        }
        if reply["action"] as? String == "refresh" {
            let acknowledged = reply["delivery"] as? String == "acknowledged_by_device"
            self.init(symbol: "sparkles", title: "Rémanences", caption: acknowledged ? "Effacées" : "Effacement envoyé", gauge: nil)
            return
        }
        if reply["power"] as? String == "off" {
            self.init(symbol: "lightbulb.slash", title: "Lumière", caption: "Éteinte", gauge: nil)
            return
        }
        guard let name = reply["setting"] as? String, let shown = HUDContent.presentation[name],
              let value = reply["value"] as? Int, let bounds = reply["bounds"] as? [Int], bounds.count == 2,
              bounds[0] < bounds[1] else { return nil }
        let (lower, upper) = (bounds[0], bounds[1])
        var caption = (lower, upper) == (0, 100) ? "\(value) %" : "\(value) / \(upper)"
        // The limit is spelled out because a full or empty bar alone does not
        // say whether another press would still do something.
        if value >= upper { caption += " · Max" } else if value <= lower { caption += " · Min" }
        self.init(symbol: shown.symbol, title: shown.title, caption: caption,
                  gauge: HUDContent.gauge(value: value, lower: lower, upper: upper))
    }

    // One segment per step when the range is short (contrast: 8 steps), so each
    // press moves exactly one segment; ten segments for percentages, matching
    // the ±10 shortcuts.
    public static func gauge(value: Int, lower: Int, upper: Int) -> Gauge {
        let span = upper - lower
        let segments = span <= 16 ? span : 10
        let fraction = Double(min(max(value, lower), upper) - lower) / Double(span)
        return Gauge(segments: segments, filled: Int((fraction * Double(segments)).rounded()))
    }
}
