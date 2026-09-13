import AppKit
import PaperlikeCore

// Transient feedback after a shortcut, in the spirit of the macOS brightness
// HUD. Drawn for e-ink: opaque, pure text colours, no shadow, no animation —
// every fade frame would be one more partial refresh of the panel, and a
// shadow is a grey gradient the waveform renders as noise.
//
// The panel is non-activating and ignores the mouse: the agent never becomes
// the active application, so the focused window keeps the keyboard.
final class HUD {
    private static let size = NSSize(width: 300, height: 64)
    private static let margin: CGFloat = 16
    private static let duration = 1.6

    private let panel: NSPanel
    private let view = HUDView(frame: NSRect(origin: .zero, size: HUD.size))
    private var pendingHide: DispatchWorkItem?

    // Main thread only, like every AppKit call below.
    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: HUD.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = view
    }

    func show(_ reply: [String: Any]) {
        guard let content = HUDContent(reply: reply) else { return }
        view.content = content
        view.needsDisplay = true
        // The screen under the pointer, not NSScreen.main: with several
        // monitors the main screen follows the focused window, which AeroSpace
        // may have left on another display than the one being looked at.
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.maxX - HUD.size.width - HUD.margin,
                                     y: area.maxY - HUD.size.height - HUD.margin))
        panel.orderFrontRegardless()
        pendingHide?.cancel()
        let hide = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        pendingHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + HUD.duration, execute: hide)
    }
}

private final class HUDView: NSView {
    var content: HUDContent?

    override func draw(_ dirtyRect: NSRect) {
        guard let content else { return }
        // textColor/textBackgroundColor are opaque black and white (inverted in
        // Dark Mode); labelColor carries alpha and would land as grey on e-ink.
        let ink = NSColor.textColor, paper = NSColor.textBackgroundColor
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        paper.setFill(); outline.fill()
        outline.lineWidth = 2
        ink.setStroke(); outline.stroke()

        let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
        if let symbol = NSImage(systemSymbolName: content.symbol, accessibilityDescription: content.title)?
            .withSymbolConfiguration(configuration) {
            let box = NSRect(x: 14, y: (bounds.height - 30) / 2, width: 30, height: 30)
            let size = symbol.size
            symbol.draw(in: NSRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2,
                                   width: size.width, height: size.height))
        }

        let left: CGFloat = 56, right = bounds.width - 16
        let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                                    .foregroundColor: ink]
        let caption: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                                                      .foregroundColor: ink]
        let captionText = NSAttributedString(string: content.caption, attributes: caption)

        guard let gauge = content.gauge, gauge.segments > 0 else {
            NSAttributedString(string: content.title, attributes: title).draw(at: NSPoint(x: left, y: 34))
            captionText.draw(at: NSPoint(x: left, y: 14))
            return
        }
        NSAttributedString(string: content.title, attributes: title).draw(at: NSPoint(x: left, y: 34))
        captionText.draw(at: NSPoint(x: right - captionText.size().width, y: 34))

        // Empty segments are outlined rather than grey, for the same reason.
        let gap: CGFloat = 3
        let width = (right - left - gap * CGFloat(gauge.segments - 1)) / CGFloat(gauge.segments)
        for index in 0..<gauge.segments {
            let cell = NSRect(x: left + CGFloat(index) * (width + gap), y: 14, width: width, height: 10)
            let shape = NSBezierPath(roundedRect: cell.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            if index < gauge.filled { ink.setFill(); shape.fill() }
            shape.lineWidth = 1
            ink.setStroke(); shape.stroke()
        }
    }
}
