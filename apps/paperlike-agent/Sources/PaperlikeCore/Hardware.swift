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
            }.map { $0.localizedName ?? "Client DASUNG" }
        }
        let competitors = Thread.isMainThread ? readApps() : DispatchQueue.main.sync(execute: readApps)
        return Inventory(displays: displays, serialDevices: devices.sorted { $0.path < $1.path }, competingApps: competitors)
    }

    public func selectedDevice() throws -> SerialDevice {
        guard competingApps.isEmpty else {
            throw PaperlikeError("En attente : quitter \(competingApps.joined(separator: ", ")) pour libérer le port USB.")
        }
        guard displays.contains(where: \.isDasung) else {
            throw PaperlikeError("En attente d’un écran DASUNG (EDID 0x1263).")
        }
        let candidates = serialDevices.filter(\.isCandidate)
        guard candidates.count == 1 else {
            throw PaperlikeError(candidates.isEmpty
                ? "Écran détecté ; liaison USB de contrôle absente. Vérifier le câble USB de données."
                : "Plusieurs adaptateurs CH340 détectés ; sélection automatique refusée.")
        }
        return candidates[0]
    }

    private static func property(_ service: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

public struct DitheringState: Codable {
    public let product: UInt32
    public let enabled: Bool?

    public static func capture() -> [DitheringState] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOMobileFramebuffer"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [DitheringState] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let attributes = IORegistryEntryCreateCFProperty(service, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any]
            guard let product = attributes?["ProductAttributes"] as? [String: Any],
                  (product["LegacyManufacturerID"] as? NSNumber)?.uint32Value == 0x1263,
                  let id = (product["ProductID"] as? NSNumber)?.uint32Value else { continue }
            let enabled = IORegistryEntryCreateCFProperty(service, "enableDither" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
            result.append(DitheringState(product: id, enabled: enabled))
        }
        return result
    }

    public static func requireDisabled(_ states: [DitheringState], products: Set<UInt32>) throws {
        guard !products.isEmpty, products.allSatisfy({ product in
            let matching = states.filter { $0.product == product }
            return !matching.isEmpty && matching.allSatisfy { $0.enabled == false }
        }) else {
            throw PaperlikeError("État anti-dithering DASUNG non confirmé. Aucun signal 0x20 envoyé ; conserver le client officiel ou vérifier BetterDisplay/Stillcolor.")
        }
    }
}

public final class SerialPort {
    private let fd: Int32
    private var original = termios()
    private var parser = FrameParser()
    public private(set) var lastFrames: [String] = []

    public init(path: String) throws {
        fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw PaperlikeError("Ouverture du port USB : \(String(cString: strerror(errno)))") }
        guard ioctl(fd, TIOCEXCL) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Impossible de réserver le port USB.")
        }
        guard tcgetattr(fd, &original) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Lecture des paramètres du port impossible.")
        }
        var settings = original
        cfmakeraw(&settings)
        cfsetspeed(&settings, speed_t(B115200))
        settings.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE | CRTSCTS)
        settings.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
        // Do not lower modem-control lines on close or reset the monitor.
        settings.c_cflag &= ~tcflag_t(HUPCL)
        guard tcsetattr(fd, TCSANOW, &settings) == 0 else {
            Darwin.close(fd); throw PaperlikeError("Configuration 115200 8N1 impossible.")
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

    public func readFrames(timeout: TimeInterval) throws -> [Frame] {
        var frames: [Frame] = []
        let end = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            let remaining = end - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 { break }
            var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let result = poll(&p, 1, Int32(max(1, remaining * 1000)))
            if result < 0 && errno == EINTR { continue }
            if result < 0 || (p.revents & Int16(POLLERR | POLLHUP | POLLNVAL)) != 0 {
                throw PaperlikeError("Liaison USB interrompue.")
            }
            if result == 0 { break }
            var buffer = [UInt8](repeating: 0, count: 1024)
            let size = Darwin.read(fd, &buffer, buffer.count)
            if size < 0 && [EAGAIN, EINTR].contains(errno) { continue }
            guard size > 0 else { throw PaperlikeError("Liaison USB fermée.") }
            let received = parser.append(Data(buffer.prefix(size)))
            frames += received
            lastFrames = Array((lastFrames + received.map(\.ascii)).suffix(12))
        } while true
        return frames
    }

    public func query(_ register: UInt8, timeout: TimeInterval = 0.6) throws -> UInt8 {
        // Drain complete replies before sending, so an earlier response cannot
        // be mistaken for confirmation of a newly requested setting.
        _ = try readFrames(timeout: 0.01)
        parser = FrameParser()
        try send(Frame(0x0a, register))
        let frames = try readFrames(timeout: timeout)
        guard let value = frames.compactMap({ $0.registerValue(register) }).last else {
            throw PaperlikeError(String(format: "Aucune réponse valide au registre 0x%02X.", register))
        }
        return value
    }
}

public func writeAll(fd: Int32, data: Data, timeout: TimeInterval) throws {
    let end = ProcessInfo.processInfo.systemUptime + timeout
    var offset = 0
    try data.withUnsafeBytes { bytes in
        while offset < bytes.count {
            let remaining = end - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw PaperlikeError("Délai d’écriture dépassé.") }
            var p = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let ready = poll(&p, 1, Int32(max(1, remaining * 1000)))
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0, (p.revents & Int16(POLLOUT)) != 0 else { throw PaperlikeError("Écriture impossible.") }
            let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0 && [EAGAIN, EINTR].contains(errno) { continue }
            guard count > 0 else { throw PaperlikeError("Écriture USB/socket interrompue.") }
            offset += count
        }
    }
}
