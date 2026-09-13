import AppKit
import IOKit
import Darwin

public struct Display: Codable {
    public let id: UInt32
    public let vendor: UInt32
    public let product: UInt32
    public let width: Int
    public let height: Int
    public var isDasung: Bool { vendor == 0x1263 }
}

// The outputs a screen clear paints. The display under the pointer, as for the
// HUD, when it is a DASUNG one: AeroSpace moves the pointer along with monitor
// focus, so that is the panel being worked on. From any other display, every
// DASUNG output — the shortcut was meant for e-ink, and guessing which panel
// is not worth it.
public enum ClearTarget {
    public static func displays(dasung: [UInt32], pointer: UInt32?) -> [UInt32] {
        if let pointer, dasung.contains(pointer) { return [pointer] }
        return dasung
    }
}

public struct SerialDevice: Codable, Equatable {
    public let path: String
    public let vendor: Int
    public let product: Int
    public var isCandidate: Bool { vendor == 0x1a86 && product == 0x7523 }
    public init(path: String, vendor: Int, product: Int) {
        self.path = path; self.vendor = vendor; self.product = product
    }
}

public struct Inventory: Codable {
    public let displays: [Display]
    public let serialDevices: [SerialDevice]
    public let competingApps: [String]

    public static func capture() -> Inventory {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        if count > 0 { CGGetOnlineDisplayList(count, &ids, &count) }
        let displays = ids.prefix(Int(count)).map {
            Display(id: $0, vendor: CGDisplayVendorNumber($0), product: CGDisplayModelNumber($0),
                    width: CGDisplayCopyDisplayMode($0)?.pixelWidth ?? CGDisplayPixelsWide($0),
                    height: CGDisplayCopyDisplayMode($0)?.pixelHeight ?? CGDisplayPixelsHigh($0))
        }
        var devices: [SerialDevice] = []
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOSerialBSDClient"), &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                guard let path = property(service, "IOCalloutDevice") as? String else { continue }
                var vendor = 0, product = 0
                var entry = service
                IOObjectRetain(entry)
                // USB identifiers belong to a parent, not the serial BSD node.
                for _ in 0..<20 {
                    if let v = property(entry, "idVendor") as? NSNumber,
                       let p = property(entry, "idProduct") as? NSNumber {
                        vendor = v.intValue; product = p.intValue; break
                    }
                    var parent: io_registry_entry_t = 0
                    guard IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS else { break }
                    IOObjectRelease(entry); entry = parent
                }
                IOObjectRelease(entry)
                if vendor != 0 { devices.append(SerialDevice(path: path, vendor: vendor, product: product)) }
            }
        }
        // NSWorkspace's application list follows its calling thread's run loop.
        // A hardware dispatch queue has no run loop: read on the main thread.
        let readApps = {
            NSWorkspace.shared.runningApplications.filter {
                !$0.isTerminated && kill($0.processIdentifier, 0) == 0 &&
                $0.bundleIdentifier != "com.user.paperlike-agent" &&
                ["paperlikeclient", "paperlikemenu", "inkcontrol"].contains(($0.localizedName ?? "").lowercased())
            }.map { $0.localizedName ?? "DASUNG client" }
        }
        let competitors = Thread.isMainThread ? readApps() : DispatchQueue.main.sync(execute: readApps)
        return Inventory(displays: displays, serialDevices: devices.sorted { $0.path < $1.path }, competingApps: competitors)
    }

    public func selectedDevice() throws -> SerialDevice {
        guard competingApps.isEmpty else {
            throw PaperlikeError("Waiting: quit \(competingApps.joined(separator: ", ")) to free the USB port.")
        }
        guard displays.contains(where: \.isDasung) else {
            throw PaperlikeError("Waiting for a DASUNG display (EDID 0x1263).")
        }
        let candidates = serialDevices.filter(\.isCandidate)
        guard candidates.count == 1 else {
            throw PaperlikeError(candidates.isEmpty
                ? "Display detected; USB control link missing. Check that the USB cable carries data."
                : "Several CH340 adapters detected, automatic selection refused: \(candidates.map(\.path).joined(separator: ", ")).")
        }
        return candidates[0]
    }

    private static func property(_ service: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

// A display's gamma table is host-side state and anything may write it:
// BetterDisplay's software brightness, calibration tools, night-shift utilities.
// On a backlit LCD a crushed table merely dims. On e-ink the grey levels *are*
// the image, so a ceiling below 1.0 collapses contrast and the panel renders
// vibrating black zones and muddy colour. Reported only, never corrected: the
// agent writes one property on one vendor's framebuffers, and taking on a
// contested second writer would undo that guarantee.
public struct GammaState: Codable {
    public let display: UInt32
    public let product: UInt32
    public let ceiling: Float
    public let maxDeviation: Float
    public var isLinear: Bool { maxDeviation < 0.01 }

    public static func capture() -> [GammaState] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.prefix(Int(count)).filter { CGDisplayVendorNumber($0) == 0x1263 }.compactMap { id in
            let capacity = CGDisplayGammaTableCapacity(id)
            guard capacity > 1 else { return nil }
            var red = [CGGammaValue](repeating: 0, count: Int(capacity))
            var green = red, blue = red
            var filled: UInt32 = 0
            guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &filled) == .success,
                  filled > 1 else { return nil }
            let last = Int(filled) - 1
            var deviation: Float = 0
            for i in 0...last {
                let ideal = Float(i) / Float(last)
                deviation = max(deviation, abs(red[i] - ideal), abs(green[i] - ideal), abs(blue[i] - ideal))
            }
            return GammaState(display: id, product: CGDisplayModelNumber(id),
                              ceiling: max(red[last], green[last], blue[last]), maxDeviation: deviation)
        }
    }
}

public struct DitheringEnforcement: Codable {
    public let product: UInt32
    public let wasEnabled: Bool?
    public let result: Int32
    public var succeeded: Bool { result == KERN_SUCCESS }
}

public struct DitheringState: Codable {
    public let product: UInt32
    public let enabled: Bool?

    // macOS applies temporal dithering to the video output. An e-ink panel
    // renders that as grain, blotches and a darker image. Clearing the
    // framebuffer's `enableDither` is what the official client does on a timer
    // and what Stillcolor is sandbox-entitled for; macOS restores it on
    // display reconnect, wake and mode changes, so it has to be re-asserted.
    private static let framebufferClass = "IOMobileFramebufferAP"
    private static let ditherKey = "enableDither" as CFString

    public static func capture() -> [DitheringState] {
        withDasungFramebuffers { service, product in
            DitheringState(product: product, enabled: read(service))
        }
    }

    // Only DASUNG framebuffers are ever written. Dithering is wanted on the
    // built-in XDR panel; removing it there produces visible banding. The
    // DASUNG vendor match is the positive condition for writing, never the
    // absence of some other match.
    public static func disableOnDasung() -> [DitheringEnforcement] {
        withDasungFramebuffers { service, product in
            let current = read(service)
            guard current != false else { return nil }
            let result = IORegistryEntrySetCFProperty(service, ditherKey, kCFBooleanFalse)
            return DitheringEnforcement(product: product, wasEnabled: current, result: result)
        }
    }

    public static func requireDisabled(_ states: [DitheringState], products: Set<UInt32>) throws {
        guard !products.isEmpty, products.allSatisfy({ product in
            let matching = states.filter { $0.product == product }
            return !matching.isEmpty && matching.allSatisfy { $0.enabled == false }
        }) else {
            throw PaperlikeError("DASUNG anti-dithering state not confirmed; no 0x20 signal sent this cycle.")
        }
    }

    private static func read(_ service: io_registry_entry_t) -> Bool? {
        IORegistryEntryCreateCFProperty(service, ditherKey, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
    }

    // The iterator also yields the built-in panel and framebuffers with no
    // display attached; both are filtered out by the vendor match. Every
    // io_object_t is released here: this runs on the agent's two-second tick.
    private static func withDasungFramebuffers<T>(_ body: (io_registry_entry_t, UInt32) -> T?) -> [T] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(framebufferClass), &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [T] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let attributes = IORegistryEntryCreateCFProperty(service, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any]
            guard let product = attributes?["ProductAttributes"] as? [String: Any],
                  (product["LegacyManufacturerID"] as? NSNumber)?.uint32Value == 0x1263,
                  let id = (product["ProductID"] as? NSNumber)?.uint32Value else { continue }
            if let value = body(service, id) { result.append(value) }
        }
        return result
    }
}

public final class SerialPort {
    private let fd: Int32
    private var original = termios()
    private var parser = FrameParser()
    public private(set) var lastFrames: [String] = []

    public init(path: String) throws {
        fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw PaperlikeError("Opening the USB port: \(String(cString: strerror(errno)))") }
        guard ioctl(fd, TIOCEXCL) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Cannot reserve the USB port.")
        }
        guard tcgetattr(fd, &original) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Cannot read the port settings.")
        }
        var settings = original
        cfmakeraw(&settings)
        cfsetspeed(&settings, speed_t(B115200))
        settings.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE | CRTSCTS)
        settings.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
        // Do not lower modem-control lines on close or reset the monitor.
        settings.c_cflag &= ~tcflag_t(HUPCL)
        guard tcsetattr(fd, TCSANOW, &settings) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Cannot configure 115200 8N1.")
        }
    }

    deinit {
        tcsetattr(fd, TCSANOW, &original)
        _ = ioctl(fd, TIOCNXCL)
        Darwin.close(fd)
    }

    public func send(_ frame: Frame) throws {
        try writeAll(fd: fd, data: Data(frame.ascii.utf8), timeout: 0.5)
    }

    // Reads until `timeout`, or as soon as `done` accepts what has arrived. The
    // timeout is the failure path only: waiting it out after the awaited reply
    // cost every query its full 0.6 s, about two seconds per hotkey press.
    public func readFrames(timeout: TimeInterval, until done: ([Frame]) -> Bool = { _ in false }) throws -> [Frame] {
        var frames: [Frame] = []
        let end = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            if done(frames) { break }
            let remaining = end - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 { break }
            var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let result = poll(&p, 1, Int32(max(1, remaining * 1000)))
            if result < 0 && errno == EINTR { continue }
            if result < 0 || (p.revents & Int16(POLLERR | POLLHUP | POLLNVAL)) != 0 {
                throw PaperlikeError("USB link interrupted.")
            }
            if result == 0 { break }
            var buffer = [UInt8](repeating: 0, count: 1024)
            let size = Darwin.read(fd, &buffer, buffer.count)
            if size < 0 && [EAGAIN, EINTR].contains(errno) { continue }
            guard size > 0 else { throw PaperlikeError("USB link closed.") }
            let received = parser.append(Data(buffer.prefix(size)))
            frames += received
            lastFrames = Array((lastFrames + received.map(\.ascii)).suffix(12))
        } while true
        return frames
    }

    // The request is re-sent every `attempt` until `timeout`. Right after a
    // light switch the monitor drops a query outright — no late reply, while
    // the same read 50 ms later answers — so one long wait only fails slowly.
    public func query(_ register: UInt8, timeout: TimeInterval = 0.6, attempt: TimeInterval = 0.2) throws -> UInt8 {
        // Drain complete replies before sending, so an earlier response cannot
        // be mistaken for confirmation of a newly requested setting. Replies
        // to this query's own earlier attempts remain valid and are kept.
        _ = try readFrames(timeout: 0.01)
        parser = FrameParser()
        let end = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            try send(Frame(0x0a, register))
            let window = max(0.001, min(attempt, end - ProcessInfo.processInfo.systemUptime))
            let frames = try readFrames(timeout: window) { $0.contains { $0.registerValue(register) != nil } }
            if let value = frames.compactMap({ $0.registerValue(register) }).last { return value }
        } while ProcessInfo.processInfo.systemUptime < end
        throw PaperlikeError(String(format: "No valid reply for register 0x%02X.", register))
    }
}

public func writeAll(fd: Int32, data: Data, timeout: TimeInterval) throws {
    let end = ProcessInfo.processInfo.systemUptime + timeout
    var offset = 0
    try data.withUnsafeBytes { bytes in
        while offset < bytes.count {
            let remaining = end - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw PaperlikeError("Write timed out.") }
            var p = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let ready = poll(&p, 1, Int32(max(1, remaining * 1000)))
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0, (p.revents & Int16(POLLOUT)) != 0 else { throw PaperlikeError("Cannot write.") }
            let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0 && [EAGAIN, EINTR].contains(errno) { continue }
            guard count > 0 else { throw PaperlikeError("USB/socket write interrupted.") }
            offset += count
        }
    }
}
