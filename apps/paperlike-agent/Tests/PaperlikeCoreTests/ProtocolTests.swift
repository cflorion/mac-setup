import XCTest
import Darwin
@testable import PaperlikeCore

final class ProtocolTests: XCTestCase {
    func testPublishedWireCommands() throws {
        XCTAssertEqual(Frame(0x0a, 0x10).ascii, "5FF50A10000000000000A0FA")
        XCTAssertEqual(Frame(0x20, 1).ascii, "5FF52001000000000000A0FA")
        XCTAssertEqual(try Action.parse(["refresh"]).frame(value: 0).ascii, "5FF50300000000000000A0FA")
        XCTAssertEqual(try Action.parse(["contrast", "9"]).frame(value: 9).ascii, "5FF50109000000000000A0FA")
        XCTAssertEqual(try Action.parse(["speed", "5"]).frame(value: 5).ascii, "5FF50405000000000000A0FA")
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
        for args in [["contrast", "0"], ["contrast", "10"], ["speed", "6"], ["contrast", "+0"],
                     ["refresh", "1"], ["raw", "5FF5"], ["contrast", "foo"], ["contrast", "+foo"], []] {
            XCTAssertThrowsError(try Action.parse(args))
        }
        // A signed value is a relative adjustment, so "-1" is now valid where a
        // bare "-1" would still be out of bounds as an absolute value.
        XCTAssertEqual(try Action.parse(["contrast", "-1"]), .set(Setting.named("contrast")!, .relative(-1)))
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
        // The timeout is the failure path only: a query must return as soon as
        // its reply is parsed, not after waiting the timeout out.
        let started = ProcessInfo.processInfo.systemUptime
        XCTAssertEqual(try port.query(0x10, timeout: 2), 0x30)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 1)
        wait(for: [received], timeout: 2)
        XCTAssertThrowsError(try port.query(0x01, timeout: 0.05))
    }

    func testAQueryDroppedByTheMonitorIsSentAgain() throws {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 256)
        XCTAssertEqual(openpty(&master, &slave, &name, nil, nil), 0)
        defer { Darwin.close(master); Darwin.close(slave) }
        let port = try SerialPort(path: String(cString: name))
        let answered = expectation(description: "resent query answered")
        let masterFD = master
        DispatchQueue.global().async {
            // Right after a light switch the monitor ignores a query entirely;
            // only the resent one gets a reply.
            var total = 0
            var bytes = [UInt8](repeating: 0, count: 256)
            while total < 48 {
                var p = pollfd(fd: masterFD, events: Int16(POLLIN), revents: 0)
                guard poll(&p, 1, 1500) > 0 else { return }
                total += max(Darwin.read(masterFD, &bytes, bytes.count), 0)
            }
            let reply = "5FF5F00A070100000000A0FA"
            _ = reply.withCString { Darwin.write(masterFD, $0, reply.utf8.count) }
            answered.fulfill()
        }
        let started = ProcessInfo.processInfo.systemUptime
        XCTAssertEqual(try port.query(0x07, timeout: 1, attempt: 0.1), 1)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 0.5)
        wait(for: [answered], timeout: 2)
    }
}

final class SettingsTests: XCTestCase {
    func testEverySettingIsUniquelyNamedAndCommanded() {
        XCTAssertEqual(Set(Setting.all.map(\.name)).count, Setting.all.count)
        XCTAssertEqual(Set(Setting.all.map(\.command)).count, Setting.all.count)
        // 0x05 is the device's real-time clock and 0x13 is unidentified; neither
        // may become writable by accident.
        XCTAssertFalse(Setting.all.contains { [0x05, 0x13, 0x0a, 0x10, 0x20].contains($0.command) })
    }

    func testAbsoluteValuesAreBoundedAndRelativeOnesAreNot() throws {
        let light = Setting.named("light")!
        XCTAssertThrowsError(try Action.parse(["light", "101"]))
        XCTAssertThrowsError(try Action.parse(["contrast", "0"]))
        XCTAssertThrowsError(try Action.parse(["nope", "1"]))
        XCTAssertEqual(try Action.parse(["light", "+10"]), .set(light, .relative(10)))
        XCTAssertEqual(try Action.parse(["light", "-10"]), .set(light, .relative(-10)))
        XCTAssertEqual(try Action.parse(["light", "10"]), .set(light, .absolute(10)))
    }

    func testRelativeAdjustmentsClampInsteadOfOverflowing() {
        let light = Setting.named("light")!
        XCTAssertEqual(Adjustment.relative(50).resolve(from: 95, within: light.bounds), 100)
        XCTAssertEqual(Adjustment.relative(-50).resolve(from: 5, within: light.bounds), 0)
        XCTAssertEqual(Adjustment.absolute(7).resolve(from: 1, within: light.bounds), 7)
    }

    func testFramesCarryTheDocumentedCommandBytes() throws {
        XCTAssertEqual(try Action.parse(["light", "20"]).frame(value: 20).ascii, "5FF50914000000000000A0FA")
        XCTAssertEqual(try Action.parse(["text-enhance", "1"]).frame(value: 1).ascii, "5FF51201000000000000A0FA")
    }

    func testConfigurationRejectsUnusableBindingsAndKeepsWorkingOnes() throws {
        XCTAssertThrowsError(try Configuration.binding(keys: "r", action: ["refresh"]))
        XCTAssertThrowsError(try Configuration.binding(keys: "ctrl+alt+cmd+r", action: ["fly"]))
        XCTAssertThrowsError(try Configuration.binding(keys: "ctrl+alt+cmd", action: ["refresh"]))
        let ok = try Configuration.binding(keys: "ctrl+alt+cmd+up", action: ["light", "+10"])
        XCTAssertEqual(ok.describedAction, "light +10")
        XCTAssertNotEqual(ok.modifiers, 0)
    }

    func testDefaultHotkeysAllParse() {
        for (keys, action) in Configuration.defaultHotkeys {
            XCTAssertNoThrow(try Configuration.binding(keys: keys, action: action), "\(keys)")
        }
    }

    func testAMissingConfigurationFileYieldsDefaultsWithoutProblems() {
        let config = Configuration.load(from: "/nonexistent/paperlike.json")
        XCTAssertEqual(config.hotkeys.count, Configuration.defaultHotkeys.count)
        XCTAssertTrue(config.problems.isEmpty)
    }

    func testTheHUDCanBeTurnedOffWithoutLosingTheDefaultShortcuts() throws {
        let path = NSTemporaryDirectory() + "paperlike-nohud.json"
        try #"{ "hud": false }"#.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        let config = Configuration.load(from: path)
        XCTAssertFalse(config.hud)
        XCTAssertEqual(config.hotkeys.count, Configuration.defaultHotkeys.count)
        XCTAssertTrue(config.problems.isEmpty)
        XCTAssertTrue(Configuration.load(from: "/nonexistent/paperlike.json").hud)
    }

    func testAnUnparseableConfigurationStillYieldsWorkingDefaults() throws {
        let path = NSTemporaryDirectory() + "paperlike-broken.json"
        try "{ not json".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        let config = Configuration.load(from: path)
        XCTAssertEqual(config.hotkeys.count, Configuration.defaultHotkeys.count)
        XCTAssertFalse(config.problems.isEmpty)
    }
}

final class LightAndShortcutTests: XCTestCase {
    func testLightPowerParsesAndEveryActionRoundTrips() throws {
        XCTAssertEqual(try Action.parse(["light", "toggle"]), .light(.toggle))
        XCTAssertEqual(try Action.parse(["light", "on"]), .light(.on))
        XCTAssertThrowsError(try Action.parse(["light", "maybe"]))
        XCTAssertThrowsError(try Action.parse(["light-mode", "toggle"]))
        for args in [["refresh"], ["light", "off"], ["contrast", "+1"], ["light", "-10"], ["speed", "3"]] {
            XCTAssertEqual(try Action.parse(args).arguments, args)
        }
        XCTAssertEqual(Setting.named("light")?.requires?.code, "light-off")
    }

    func testBrightnessKeysSwitchTheLightOnAndOff() {
        let bounds = Setting.named("light")!.bounds
        // ↑ from off lights it at the first step, whatever level is stored.
        XCTAssertEqual(FrontLight.step(isOn: false, level: 0, by: .relative(10), within: bounds), .switchOn(10))
        XCTAssertEqual(FrontLight.step(isOn: true, level: 40, by: .relative(10), within: bounds), .setLevel(50))
        // ↓ to the bottom really switches it off, including a light lit at zero.
        XCTAssertEqual(FrontLight.step(isOn: true, level: 10, by: .relative(-10), within: bounds), .switchOff)
        XCTAssertEqual(FrontLight.step(isOn: true, level: 5, by: .relative(-10), within: bounds), .switchOff)
        XCTAssertEqual(FrontLight.step(isOn: true, level: 0, by: .relative(-10), within: bounds), .switchOff)
        XCTAssertEqual(FrontLight.step(isOn: false, level: 0, by: .relative(-10), within: bounds), .stay(0))
        XCTAssertEqual(FrontLight.step(isOn: true, level: 100, by: .relative(10), within: bounds), .stay(100))
        // Absolute values follow the same rule: 0 is off, anything else is on.
        XCTAssertEqual(FrontLight.step(isOn: true, level: 40, by: .absolute(0), within: bounds), .switchOff)
        XCTAssertEqual(FrontLight.step(isOn: false, level: 0, by: .absolute(30), within: bounds), .switchOn(30))
    }

    func testRapidRelativePressesMergeAndOppositeOnesCancel() throws {
        let up = try Action.parse(["light", "+10"]), down = try Action.parse(["light", "-10"])
        XCTAssertEqual(up.merged(with: up), .set(Setting.named("light")!, .relative(20)))
        XCTAssertEqual(up.merged(with: down)?.isNoOp, true)
        XCTAssertNil(up.merged(with: try Action.parse(["contrast", "+1"])))
        XCTAssertNil(up.merged(with: .light(.toggle)))
        XCTAssertNil(try Action.parse(["light", "10"]).merged(with: up))
        XCTAssertFalse(up.isNoOp)
    }
}

final class HUDContentTests: XCTestCase {
    func testLimitsAreSpelledOutAndEachPressMovesOneSegment() {
        let top = HUDContent(reply: ["ok": true, "setting": "contrast", "value": 9, "bounds": [1, 9]])
        XCTAssertEqual(top?.caption, "9 / 9 · Max")
        XCTAssertEqual(top?.gauge, HUDContent.Gauge(segments: 8, filled: 8))
        let bottom = HUDContent(reply: ["ok": true, "setting": "contrast", "value": 1, "bounds": [1, 9]])
        XCTAssertEqual(bottom?.caption, "1 / 9 · Min")
        XCTAssertEqual(bottom?.gauge?.filled, 0)
        let light = HUDContent(reply: ["ok": true, "setting": "light", "value": 40, "bounds": [0, 100]])
        XCTAssertEqual(light?.caption, "40%")
        XCTAssertEqual(light?.gauge, HUDContent.Gauge(segments: 10, filled: 4))
        XCTAssertEqual(HUDContent(reply: ["ok": true, "setting": "light", "value": 100, "bounds": [0, 100]])?.caption, "100% · Max")
    }

    func testLightStatesAndFailuresAreWordedForTheScreen() {
        let off = HUDContent(reply: ["ok": true, "setting": "light", "power": "off", "bounds": [0, 100]])
        XCTAssertEqual(off?.caption, "Off")
        XCTAssertEqual(off?.gauge, HUDContent.Gauge(segments: 10, filled: 0))
        XCTAssertEqual(HUDContent(reply: ["ok": false, "code": "light-off", "error": "…"])?.caption, "Off")
        XCTAssertEqual(HUDContent(reply: ["ok": false, "error": "…"])?.symbol, "exclamationmark.triangle")
        XCTAssertEqual(HUDContent(reply: ["ok": true, "action": "refresh", "delivery": "sent"])?.caption, "Cleanup sent")
        // A reply the HUD cannot describe shows nothing rather than a guess.
        XCTAssertNil(HUDContent(reply: ["ok": true, "registers": [String: Int]()]))
    }
}
