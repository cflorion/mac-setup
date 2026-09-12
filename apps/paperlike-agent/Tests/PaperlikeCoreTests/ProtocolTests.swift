import XCTest
import Darwin
@testable import PaperlikeCore

final class ProtocolTests: XCTestCase {
    func testPublishedWireCommands() throws {
        XCTAssertEqual(Frame(0x0a, 0x10).ascii, "5FF50A10000000000000A0FA")
        XCTAssertEqual(Frame(0x20, 1).ascii, "5FF52001000000000000A0FA")
        XCTAssertEqual(try Action.parse(["refresh"]).frame.ascii, "5FF50300000000000000A0FA")
        XCTAssertEqual(try Action.parse(["contrast", "9"]).frame.ascii, "5FF50109000000000000A0FA")
        XCTAssertEqual(try Action.parse(["speed", "5"]).frame.ascii, "5FF50405000000000000A0FA")
    }

    func testParserSurvivesEveryUSBFragmentBoundary() {
        let wire = Array("5FF5000A103000000000A0FA".utf8)
        for split in 0...wire.count {
            var parser = FrameParser()
            let frames = parser.append(Data(wire.prefix(split))) + parser.append(Data(wire.dropFirst(split)))
            XCTAssertEqual(frames.count, 1, "split \(split)")
            XCTAssertEqual(frames.first?.registerValue(0x10), 0x30)
        }
    }

    func testNoiseMalformedFramesConcatenationAndLowercase() {
        var parser = FrameParser()
        let wire = "noise5FF5XX00000000000000A0FA5ff5000a103000000000a0fa\r\n5FF5F520000000000000A0FA"
        let frames = parser.append(Data(wire.utf8))
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].registerValue(0x10), 0x30)
        XCTAssertNil(frames[1].registerValue(0x10))
        XCTAssertEqual(frames[1].command, 0xf5)
    }

    func testUnrelatedAndEchoedMessagesAreNotQueryReplies() {
        var parser = FrameParser()
        let frames = parser.append(Data("5FF50A10000000000000A0FA5FF5000A010500000000A0FA".utf8))
        XCTAssertTrue(frames.allSatisfy { $0.registerValue(0x10) == nil })
    }

    func testOnlyTheMatchingAcknowledgementConfirmsRefresh() {
        var parser = FrameParser()
        let replies = parser.append(Data("5FF5F020000000000000A0FA5FF5F003000000000000A0FA".utf8))
        XCTAssertFalse(replies[0].acknowledges(Frame(3)))
        XCTAssertTrue(replies[1].acknowledges(Frame(3)))
    }

    func testBadCommandsNeverBecomeHardwareWrites() {
        for args in [["contrast", "0"], ["contrast", "10"], ["contrast", "-1"], ["speed", "6"],
                     ["refresh", "1"], ["raw", "5FF5"], ["contrast", "foo"], []] {
            XCTAssertThrowsError(try Action.parse(args))
        }
        XCTAssertFalse(ProtocolIdentity.isSupported(0))
        XCTAssertFalse(ProtocolIdentity.isSupported(0xff))
        XCTAssertTrue(ProtocolIdentity.isSupported(0x31))
    }

    func testSelectionRequiresDisplayUniqueUSBAndNoCompetitor() throws {
        let display = Display(id: 3, vendor: 0x1263, product: 0, width: 3200, height: 1800)
        let usb = SerialDevice(path: "/dev/cu.test", vendor: 0x1a86, product: 0x7523)
        XCTAssertEqual(try Inventory(displays: [display], serialDevices: [usb], competingApps: []).selectedDevice(), usb)
        XCTAssertThrowsError(try Inventory(displays: [], serialDevices: [usb], competingApps: []).selectedDevice())
        XCTAssertThrowsError(try Inventory(displays: [display], serialDevices: [], competingApps: []).selectedDevice())
        XCTAssertThrowsError(try Inventory(displays: [display], serialDevices: [usb, usb], competingApps: []).selectedDevice())
        XCTAssertThrowsError(try Inventory(displays: [display], serialDevices: [usb], competingApps: ["PaperLikeClient"]).selectedDevice())
    }

    func testMacHandshakeRequiresKnownDisabledDitheringOnEveryDasungOutput() throws {
        let disabled = DitheringState(product: 0, enabled: false)
        XCTAssertNoThrow(try DitheringState.requireDisabled([disabled], products: [0]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([], products: [0]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([disabled], products: [0, 9532]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([DitheringState(product: 0, enabled: true)], products: [0]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([DitheringState(product: 0, enabled: nil)], products: [0]))
    }

    func testSerialQueryThroughRealPseudoTerminal() throws {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 256)
        XCTAssertEqual(openpty(&master, &slave, &name, nil, nil), 0)
        defer { Darwin.close(master); Darwin.close(slave) }
        let port = try SerialPort(path: String(cString: name))
        let received = expectation(description: "firmware query on serial wire")
        let masterFD = master
        DispatchQueue.global().async {
            var p = pollfd(fd: masterFD, events: Int16(POLLIN), revents: 0)
            guard poll(&p, 1, 1500) > 0 else { return }
            var bytes = [UInt8](repeating: 0, count: 256)
            let count = Darwin.read(masterFD, &bytes, bytes.count)
            XCTAssertEqual(String(bytes: bytes.prefix(max(count, 0)), encoding: .ascii), "5FF50A10000000000000A0FA")
            // A ready notification and another register must not satisfy query.
            for part in ["5FF5F520000000000000A0FA5FF5000A010500000000A0FA5FF5000A", "103000000000A0FA"] {
                _ = part.withCString { Darwin.write(masterFD, $0, part.utf8.count) }
                usleep(10000)
            }
            received.fulfill()
        }
        XCTAssertEqual(try port.query(0x10, timeout: 0.2), 0x30)
        wait(for: [received], timeout: 2)
        XCTAssertThrowsError(try port.query(0x01, timeout: 0.05))
    }
}
