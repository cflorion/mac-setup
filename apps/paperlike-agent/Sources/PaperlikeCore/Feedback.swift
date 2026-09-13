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
        "contrast": ("Contrast", "circle.lefthalf.filled"),
        "light": ("Front light", "sun.max.fill"),
        "light-mode": ("Light mode", "lightbulb"),
        "light-temp": ("Temperature", "thermometer.medium"),
        "speed": ("Speed", "speedometer"),
        "mode": ("Mode", "doc.text.image"),
        "text-enhance": ("Text enhance", "textformat"),
    ]

    public init(symbol: String, title: String, caption: String, gauge: Gauge?) {
        self.symbol = symbol; self.title = title; self.caption = caption; self.gauge = gauge
    }

    public init?(reply: [String: Any]) {
        guard reply["ok"] as? Bool == true else {
            switch reply["code"] as? String {
            case "light-off":
                self.init(symbol: "lightbulb.slash", title: "Front light", caption: "Off", gauge: nil)
            case "unavailable":
                self.init(symbol: "cable.connector.slash", title: "Paperlike", caption: "Display unreachable", gauge: nil)
            case "ambiguous":
                self.init(symbol: "cursorarrow", title: "Paperlike", caption: "Point at the one to adjust", gauge: nil)
            default:
                self.init(symbol: "exclamationmark.triangle", title: "Paperlike", caption: "Failed — see paperlike status", gauge: nil)
            }
            return
        }
        // The flash is its own feedback, and a panel drawn right after it would
        // leave a fresh ghost on the area that was just cleared.
        if reply["action"] as? String == "clear" { return nil }
        if reply["action"] as? String == "refresh" {
            let acknowledged = reply["delivery"] as? String == "acknowledged_by_device"
            self.init(symbol: "sparkles", title: "Ghost Cleanup", caption: acknowledged ? "Cleared" : "Cleanup sent", gauge: nil)
            return
        }
        if reply["power"] as? String == "off" {
            // An empty gauge rather than none: after ↓ it shows the bottom of
            // the same scale the previous presses were moving along.
            let bounds = reply["bounds"] as? [Int]
            let gauge = bounds.flatMap { $0.count == 2 && $0[0] < $0[1] ? HUDContent.gauge(value: $0[0], lower: $0[0], upper: $0[1]) : nil }
            self.init(symbol: "lightbulb.slash", title: "Front light", caption: "Off", gauge: gauge)
            return
        }
        guard let name = reply["setting"] as? String, let shown = HUDContent.presentation[name],
              let value = reply["value"] as? Int, let bounds = reply["bounds"] as? [Int], bounds.count == 2,
              bounds[0] < bounds[1] else { return nil }
        let (lower, upper) = (bounds[0], bounds[1])
        var caption = (lower, upper) == (0, 100) ? "\(value)%" : "\(value) / \(upper)"
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
