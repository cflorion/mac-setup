import AppKit
import PaperlikeCore

// Transient feedback after a shortcut, in the spirit of the macOS brightness
// HUD. Drawn for e-ink, black-and-white and colour alike: opaque, pure ink and
// paper, no shadow, no animation — every fade frame would be one more partial
// refresh of the panel, and a shadow is a grey gradient the waveform renders as
// noise. No accent colour either: on a colour e-paper filter it lands as a
// washed-out tint with less contrast than black. Strokes are thick and the
// type large and heavy, because a colour filter halves the effective
// resolution and a thin line comes out broken.
//
// The panel is non-activating and ignores the mouse: the agent never becomes
// the active application, so the focused window keeps the keyboard.
final class HUD {
    private static let size = NSSize(width: 360, height: 84)
    private static let margin: CGFloat = 16
    // Long enough to read once the panel has settled: at a slow refresh speed
    // the HUD itself takes a noticeable part of a second to appear.
    private static let duration = 2.0

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

    private static let inset: CGFloat = 18
    private static let textLeft: CGFloat = 66

    override func draw(_ dirtyRect: NSRect) {
        guard let content, let context = NSGraphicsContext.current else { return }
        // textColor/textBackgroundColor are opaque black and white (inverted in
        // Dark Mode); labelColor carries alpha and would land as grey on e-ink.
        let ink = NSColor.textColor, paper = NSColor.textBackgroundColor
        // Geometry is drawn without antialiasing: an antialiased edge is a
        // one-pixel grey fringe, which e-ink renders as speckle around every
        // shape. Text keeps it; glyphs without it are harder to read.
        context.shouldAntialias = false
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 8, yRadius: 8)
        paper.setFill(); outline.fill()
        outline.lineWidth = 3
        ink.setStroke(); outline.stroke()
        context.shouldAntialias = true

        let configuration = NSImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
        if let symbol = NSImage(systemSymbolName: content.symbol, accessibilityDescription: content.title)?
            .withSymbolConfiguration(configuration) {
            let box = NSRect(x: HUDView.inset, y: (bounds.height - 36) / 2, width: 36, height: 36)
            let size = symbol.size
            symbol.draw(in: NSRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2,
                                   width: size.width, height: size.height))
        }

        let left = HUDView.textLeft, right = bounds.width - HUDView.inset
        let title = NSAttributedString(string: content.title, attributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: ink])
        let caption = NSAttributedString(string: content.caption, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold), .foregroundColor: ink])
        let top: CGFloat = 48, bottom: CGFloat = 16

        if let choices = content.choices, !choices.names.isEmpty {
            title.draw(at: NSPoint(x: left, y: top))
            drawChoices(choices, in: NSRect(x: left, y: bottom, width: right - left, height: 24), ink: ink, paper: paper)
            return
        }
        guard let gauge = content.gauge, gauge.segments > 0 else {
            title.draw(at: NSPoint(x: left, y: top))
            caption.draw(at: NSPoint(x: left, y: bottom + 2))
            return
        }
        title.draw(at: NSPoint(x: left, y: top))
        caption.draw(at: NSPoint(x: right - caption.size().width, y: top))

        // Empty segments are outlined rather than grey, for the same reason.
        context.shouldAntialias = false
        let gap: CGFloat = 4
        let width = ((right - left - gap * CGFloat(gauge.segments - 1)) / CGFloat(gauge.segments)).rounded(.down)
        for index in 0..<gauge.segments {
            let cell = NSRect(x: left + CGFloat(index) * (width + gap), y: bottom, width: width, height: 16)
            let shape = NSBezierPath(rect: cell.insetBy(dx: 1, dy: 1))
            if index < gauge.filled { ink.setFill(); shape.fill() }
            shape.lineWidth = 2
            ink.setStroke(); shape.stroke()
        }
        context.shouldAntialias = true
    }

    // One cell per option, the current one inverted: black on white would be
    // the only difference a grey-free panel can show at a glance.
    private func drawChoices(_ choices: HUDContent.Choices, in area: NSRect, ink: NSColor, paper: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        let count = CGFloat(choices.names.count), gap: CGFloat = 4
        let width = ((area.width - gap * (count - 1)) / count).rounded(.down)
        for (index, name) in choices.names.enumerated() {
            let cell = NSRect(x: area.minX + CGFloat(index) * (width + gap), y: area.minY, width: width, height: area.height)
            let selected = index == choices.selected
            context.shouldAntialias = false
            let shape = NSBezierPath(rect: cell.insetBy(dx: 1, dy: 1))
            if selected { ink.setFill(); shape.fill() }
            shape.lineWidth = 2
            ink.setStroke(); shape.stroke()
            context.shouldAntialias = true
            let label = NSAttributedString(string: name, attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: selected ? .bold : .semibold),
                .foregroundColor: selected ? paper : ink])
            let size = label.size()
            label.draw(at: NSPoint(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2))
        }
    }
}
