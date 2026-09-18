import XCTest
import Darwin
import Carbon.HIToolbox
@testable import PaperlikeCore

final class ProtocolTests: XCTestCase {
    func testPublishedWireCommands() throws {
        XCTAssertEqual(Frame(0x0a, 0x10).ascii, "5FF50A10000000000000A0FA")
        XCTAssertEqual(Frame(0x20, 1).ascii, "5FF52001000000000000A0FA")
        XCTAssertEqual(try Action.parse(["refresh"]).frame(value: 0)?.ascii, "5FF50300000000000000A0FA")
        XCTAssertEqual(try Action.parse(["contrast", "9"]).frame(value: 9)?.ascii, "5FF50109000000000000A0FA")
        XCTAssertEqual(try Action.parse(["speed", "5"]).frame(value: 5)?.ascii, "5FF50405000000000000A0FA")
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

    // Two monitors mean two CH340 adapters: every one is a candidate, and the
    // MCU reply — not the adapter count — decides which ones are a Paperlike.
    func testEveryCH340IsACandidateOnceAPaperlikeIsOnScreen() throws {
        let display = Display(id: 3, vendor: 0x1263, product: 0, width: 3200, height: 1800)
        let k13 = Display(id: 2, vendor: 0x4a8b, product: 447, width: 3200, height: 2400)
        let otherRealtek = Display(id: 4, vendor: 0x4a8b, product: 446, width: 1920, height: 1080)
        let usb = SerialDevice(path: "/dev/cu.test", vendor: 0x1a86, product: 0x7523)
        let second = SerialDevice(path: "/dev/cu.second", vendor: 0x1a86, product: 0x7523)
        let other = SerialDevice(path: "/dev/cu.other", vendor: 0x0403, product: 0x6001)
        XCTAssertEqual(try Inventory(displays: [display], serialDevices: [usb], competingApps: []).controlCandidates(), [usb])
        XCTAssertEqual(try Inventory(displays: [display, k13], serialDevices: [usb, other, second], competingApps: []).controlCandidates(), [usb, second])
        XCTAssertEqual(try Inventory(displays: [k13], serialDevices: [usb], competingApps: []).controlCandidates(), [usb])
        XCTAssertThrowsError(try Inventory(displays: [], serialDevices: [usb], competingApps: []).controlCandidates())
        XCTAssertThrowsError(try Inventory(displays: [otherRealtek], serialDevices: [usb], competingApps: []).controlCandidates())
        XCTAssertThrowsError(try Inventory(displays: [display], serialDevices: [other], competingApps: []).controlCandidates())
        XCTAssertThrowsError(try Inventory(displays: [display], serialDevices: [usb], competingApps: ["PaperLikeClient"]).controlCandidates())
    }

    func testMacHandshakeRequiresKnownDisabledDitheringOnEveryPaperlikeOutput() throws {
        let p253 = PanelID(vendor: 0x1263, product: 0), k13 = PanelID(vendor: 0x4a8b, product: 447)
        let disabled = DitheringState(vendor: 0x1263, product: 0, enabled: false)
        XCTAssertNoThrow(try DitheringState.requireDisabled([disabled], panels: [p253]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([], panels: [p253]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([disabled], panels: [p253, PanelID(vendor: 0x1263, product: 9532)]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([DitheringState(vendor: 0x1263, product: 0, enabled: true)], panels: [p253]))
        XCTAssertThrowsError(try DitheringState.requireDisabled([DitheringState(vendor: 0x1263, product: 0, enabled: nil)], panels: [p253]))
        // The 13K counts like any other output: a dithered 13K blocks the signal.
        XCTAssertThrowsError(try DitheringState.requireDisabled([disabled, DitheringState(vendor: 0x4a8b, product: 447, enabled: true)], panels: [p253, k13]))
        XCTAssertNoThrow(try DitheringState.requireDisabled([disabled, DitheringState(vendor: 0x4a8b, product: 447, enabled: false)], panels: [p253, k13]))
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
        XCTAssertEqual(Model.register, 0x13)
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
        XCTAssertEqual(try Action.parse(["light", "20"]).frame(value: 20)?.ascii, "5FF50914000000000000A0FA")
        XCTAssertEqual(try Action.parse(["text-enhance", "1"]).frame(value: 1)?.ascii, "5FF51201000000000000A0FA")
    }

    func testConfigurationRejectsUnusableBindingsAndKeepsWorkingOnes() throws {
        XCTAssertThrowsError(try Configuration.binding(keys: "r", action: ["refresh"]))
        XCTAssertThrowsError(try Configuration.binding(keys: "ctrl+alt+cmd+r", action: ["fly"]))
        XCTAssertThrowsError(try Configuration.binding(keys: "ctrl+alt+cmd", action: ["refresh"]))
        let ok = try Configuration.binding(keys: "ctrl+alt+cmd+up", action: ["light", "+10"])
        XCTAssertEqual(ok.describedAction, "light +10")
        XCTAssertNotEqual(ok.modifiers, 0)
    }

    // The M key on AZERTY is the ANSI semicolon position; ANSI M types a comma.
    func testModeShortcutSitsOnTheAZERTYMKey() throws {
        let binding = try Configuration.binding(keys: "ctrl+alt+cmd+semicolon", action: ["mode", "next"])
        XCTAssertEqual(binding.keyCode, UInt32(kVK_ANSI_Semicolon))
        XCTAssertEqual(binding.parsed, .mode(.next))
        XCTAssertTrue(Configuration.defaultHotkeys.contains { $0.0 == "ctrl+alt+cmd+semicolon" && $0.1 == ["mode", "next"] })
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
        for args in [["refresh"], ["clear"], ["light", "off"], ["contrast", "+1"], ["light", "-10"], ["speed", "3"]] {
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

final class ScreenClearTests: XCTestCase {
    // Clear is drawn by the Mac: nothing about it may ever reach the serial port.
    func testClearHasNoWireFormAndNeedsNoUSB() throws {
        let clear = try Action.parse(["clear"])
        XCTAssertEqual(clear, .clear)
        XCTAssertNil(clear.frame(value: 0))
        XCTAssertNil(clear.register)
        XCTAssertFalse(clear.needsUSB)
        XCTAssertNil(clear.merged(with: clear))
        XCTAssertThrowsError(try Action.parse(["clear", "1"]))
        for args in [["refresh"], ["light", "toggle"], ["contrast", "+1"], ["speed", "3"]] {
            XCTAssertTrue(try Action.parse(args).needsUSB, "\(args)")
        }
    }

    func testClearTargetsThePanelUnderThePointerElseEveryPanel() {
        XCTAssertEqual(ClearTarget.displays(paperlike: [2, 5], pointer: 5), [5])
        XCTAssertEqual(ClearTarget.displays(paperlike: [2, 5], pointer: 1), [2, 5])
        XCTAssertEqual(ClearTarget.displays(paperlike: [2, 5], pointer: nil), [2, 5])
        XCTAssertEqual(ClearTarget.displays(paperlike: [], pointer: 1), [])
    }

    func testObservationModeKeepsOnlyTheShortcutsThatNeedNoUSB() {
        let config = Configuration.load(from: "/nonexistent/paperlike.json")
        XCTAssertEqual(config.activeHotkeys(controlEnabled: true).count, Configuration.defaultHotkeys.count)
        XCTAssertEqual(config.activeHotkeys(controlEnabled: false).map(\.describedAction), ["clear"])
    }

    func testNoHUDFollowsASuccessfulClearButAFailureStillShows() {
        XCTAssertNil(HUDContent(reply: ["ok": true, "action": "clear", "delivery": "drawn"]))
        XCTAssertEqual(HUDContent(reply: ["ok": false, "action": "clear", "error": "…"])?.symbol, "exclamationmark.triangle")
    }
}

final class DisplayModeTests: XCTestCase {
    // The values come from the official client's per-model tables; the same
    // name is not the same number on every model.
    func testEachModelCyclesThroughItsOwnFourModes() throws {
        for model in Model.allCases {
            let modes = DisplayMode.modes(of: model)
            XCTAssertEqual(modes.count, model == .mono253 ? 3 : 4, "\(model)")
            XCTAssertEqual(Set(modes.map(\.value)).count, modes.count, "\(model)")
            var value = modes[0].readBack
            var seen: [Int] = []
            for _ in modes {
                value = try DisplayMode.choose(.next, current: value, among: modes).readBack
                seen.append(value)
            }
            XCTAssertEqual(Set(seen), Set(modes.map(\.readBack)), "\(model)")
            XCTAssertEqual(value, modes[0].readBack, "\(model)")
        }
        XCTAssertEqual(DisplayMode.modes(of: .color253).map(\.value), [3, 4, 5, 2])
        XCTAssertEqual(DisplayMode.modes(of: .mono253).map(\.value), [3, 4, 2])
        XCTAssertEqual(DisplayMode.modes(of: .color13K).map(\.value), [6, 2, 3, 7])
        XCTAssertEqual(DisplayMode.modes(of: .paperlike103).map(\.value), [5, 2, 3, 7])
    }

    func testAnUnknownValueRestartsAtTheFirstModeAndNamesAreChecked() throws {
        let modes = DisplayMode.modes(of: .color253)
        XCTAssertEqual(try DisplayMode.choose(.next, current: 2, among: modes).name, "image")
        XCTAssertEqual(try DisplayMode.choose(.next, current: 0, among: modes).name, "image")
        XCTAssertEqual(try DisplayMode.choose(.named("text"), current: 3, among: modes).value, 2)
        // The 13K reports web, written as 6, as 1: the cycle must not stall there.
        let k13 = DisplayMode.modes(of: .color13K)
        XCTAssertEqual(try DisplayMode.choose(.next, current: 7, among: k13).value, 6)
        XCTAssertEqual(try DisplayMode.choose(.next, current: 1, among: k13).name, "text")
        XCTAssertThrowsError(try DisplayMode.choose(.named("auto"), current: 3, among: modes))
    }

    func testModeIsChosenByNameNeverByNumber() throws {
        XCTAssertEqual(try Action.parse(["mode", "next"]), .mode(.next))
        XCTAssertEqual(try Action.parse(["mode", "text"]), .mode(.named("text")))
        for raw in ["1", "2", "+1", "fly"] { XCTAssertThrowsError(try Action.parse(["mode", raw]), raw) }
        XCTAssertEqual(Action.mode(.next).frame(value: 4), Frame(0x02, 4))
        XCTAssertNil(Action.mode(.next).merged(with: .mode(.next)))
    }

    func testTheHUDNamesTheModeAndItsPlaceInTheCycle() {
        let hud = HUDContent(reply: ["ok": true, "setting": "mode", "value": 4, "bounds": [2, 7],
                                     "mode": "active", "modes": ["image", "active", "web", "text"]])
        XCTAssertEqual(hud?.title, "Mode")
        XCTAssertEqual(hud?.caption, "Active")
        XCTAssertNil(hud?.gauge)
        XCTAssertEqual(hud?.choices, HUDContent.Choices(names: ["Image", "Active", "Web", "Text"], selected: 1))
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
        XCTAssertEqual(HUDContent(reply: ["ok": false, "code": "ambiguous", "error": "…"])?.caption, "Point at the one to adjust")
    }
}

final class MonitorTests: XCTestCase {
    private let k13 = Monitor(path: "/dev/cu.usbserial-1120", firmware: 0x31, modelCode: 1)
    private let p253 = Monitor(path: "/dev/cu.usbserial-2115410", firmware: 0x30, modelCode: 5)
    private let k13Screen = Display(id: 2, vendor: 0x4a8b, product: 447, width: 3200, height: 2400)
    private let p253Screen = Display(id: 5, vendor: 0x1263, product: 0x253c, width: 3200, height: 1800)
    private let mono253Screen = Display(id: 6, vendor: 0x1263, product: 0, width: 3840, height: 2160)
    private let builtIn = Display(id: 1, vendor: 0x610, product: 41038, width: 3024, height: 1964)

    // The client's `DeviceDisplayNameForMode` table, indexed by register 0x13.
    func testModelRegisterFollowsTheClientTable() {
        XCTAssertEqual(Model.allCases.map(\.rawValue), [1, 2, 3, 4, 5])
        XCTAssertEqual(k13.name, "13K Color")
        XCTAssertEqual(p253.name, "253 Color")
        XCTAssertEqual(Model(rawValue: 2)?.name, "13K")
        XCTAssertEqual(Model(rawValue: 4)?.name, "253")
        XCTAssertNil(Monitor(path: "x", firmware: 0x30, modelCode: 9).model)
        XCTAssertEqual(Monitor(path: "x", firmware: 0x30, modelCode: 9).name, "Paperlike (model 9)")
        XCTAssertEqual(k13.key, "13k-color")
    }

    func testThe13KIsMatchedOnItsScalerEDIDNeverOnTheRealtekVendorAlone() {
        XCTAssertTrue(k13Screen.isPaperlike)
        XCTAssertTrue(p253Screen.isPaperlike)
        XCTAssertTrue(Display(id: 9, vendor: 0x1263, product: 9532, width: 0, height: 0).isPaperlike)
        XCTAssertFalse(Display(id: 9, vendor: 0x4a8b, product: 446, width: 0, height: 0).isPaperlike)
        XCTAssertFalse(builtIn.isPaperlike)
        XCTAssertTrue(Model.color13K.drives(vendor: 0x4a8b, product: 447))
        XCTAssertFalse(Model.color13K.drives(vendor: 0x1263, product: 0))
        XCTAssertTrue(Model.color253.drives(vendor: 0x1263, product: 0x253c))
        XCTAssertFalse(Model.color253.drives(vendor: 0x1263, product: 0))
        XCTAssertTrue(Model.mono253.drives(vendor: 0x1263, product: 0))
        XCTAssertFalse(Model.mono253.drives(vendor: 0x1263, product: 0x253c))
        XCTAssertFalse(Model.color253.drives(vendor: 0x4a8b, product: 447))
        XCTAssertTrue(Model.any(named: "13k", drives: k13Screen))
        XCTAssertFalse(Model.any(named: "253", drives: k13Screen))
    }

    // The black-and-white 253's MCU leaves 0x13 unanswered. Unknown, its link
    // could not be ruled out on the Color's screen, and every shortcut there
    // was refused as ambiguous; paired by elimination, each screen gets its own.
    func testAMonitorWithoutAModelIsPairedByElimination() throws {
        let color = Monitor(path: "/dev/cu.usbserial-2115410", firmware: 0x30, modelCode: 5)
        let mono = Monitor(path: "/dev/cu.usbserial-2112410", firmware: 0x10, modelCode: 0)
        let colorScreen = Display(id: 3, vendor: 0x1263, product: 0x253c, width: 3200, height: 1800)
        let monoScreen = Display(id: 2, vendor: 0x1263, product: 0, width: 3200, height: 1800)
        let screens = [colorScreen, monoScreen, builtIn]
        let monitors = Monitor.inferModels([color, mono], screens: screens)
        XCTAssertEqual(monitors[1].model, .mono253)
        XCTAssertEqual(monitors[0], color)
        XCTAssertEqual(try Targeting.choose(monitors, named: nil, pointer: colorScreen, screens: screens).path, color.path)
        XCTAssertEqual(try Targeting.choose(monitors, named: nil, pointer: monoScreen, screens: screens).path, mono.path)
        XCTAssertEqual(try Targeting.choose(monitors, named: "253-bw", pointer: nil, screens: screens).path, mono.path)
        // Two screens left unclaimed, or a product never observed: no guess.
        XCTAssertNil(Monitor.inferModels([mono], screens: screens)[0].model)
        // Its USB cable plugged in without its screen: no screen left to pair
        // it with, and it must not shadow the 13K or the Color on theirs.
        let k13 = Monitor(path: "/dev/cu.usbserial-120", firmware: 0x31, modelCode: 1)
        let k13Screen = Display(id: 2, vendor: 0x4a8b, product: 447, width: 2800, height: 2100)
        let unplugged = [k13Screen, colorScreen, builtIn]
        let alone = Monitor.inferModels([k13, mono, color], screens: unplugged)
        XCTAssertNil(alone[1].model)
        XCTAssertEqual(try Targeting.choose(alone, named: nil, pointer: k13Screen, screens: unplugged).path, k13.path)
        XCTAssertEqual(try Targeting.choose(alone, named: nil, pointer: colorScreen, screens: unplugged).path, color.path)
        XCTAssertThrowsError(try Targeting.choose(alone, named: nil, pointer: builtIn, screens: unplugged))
        XCTAssertEqual(try Targeting.choose([k13, mono], named: nil, pointer: builtIn, screens: [k13Screen, builtIn]).path, k13.path)
        let other = Display(id: 5, vendor: 0x1263, product: 0x103, width: 1872, height: 1404)
        XCTAssertNil(Monitor.inferModels([color, mono], screens: [colorScreen, other])[1].model)
    }

    func testAMonitorNameMayPrefixAnyCommand() throws {
        XCTAssertEqual(Request(["13k", "light", "+10"]), Request(["13K", "light", "+10"]))
        XCTAssertEqual(Request(["13k", "light", "+10"]).monitor, "13k")
        XCTAssertEqual(Request(["13k", "light", "+10"]).arguments, ["light", "+10"])
        XCTAssertEqual(Request(["253-color", "refresh"]).monitor, "253-color")
        XCTAssertNil(Request(["light", "on"]).monitor)
        XCTAssertEqual(Request(["status"]).arguments, ["status"])
        let binding = try Configuration.binding(keys: "ctrl+alt+cmd+1", action: ["13k", "light", "toggle"])
        XCTAssertEqual(binding.monitor, "13k")
        XCTAssertEqual(binding.parsed, .light(.toggle))
        XCTAssertEqual(binding.describedAction, "13k light toggle")
        XCTAssertNil(try Configuration.binding(keys: "ctrl+alt+cmd+l", action: ["light", "toggle"]).monitor)
    }

    func testTheMonitorUnderThePointerIsChosenAndNoneIsGuessed() throws {
        let both = [k13, p253]
        XCTAssertEqual(try Targeting.choose(both, named: nil, pointer: k13Screen), k13)
        XCTAssertEqual(try Targeting.choose(both, named: nil, pointer: p253Screen), p253)
        // From another screen, two candidates are refused, never guessed.
        XCTAssertThrowsError(try Targeting.choose(both, named: nil, pointer: builtIn)) {
            XCTAssertEqual(($0 as? PaperlikeError)?.code, "ambiguous")
        }
        XCTAssertThrowsError(try Targeting.choose(both, named: nil, pointer: nil))
        // Alone, it is the one, wherever the pointer is — except on a
        // Paperlike it does not drive: that one simply has no USB link.
        XCTAssertEqual(try Targeting.choose([k13], named: nil, pointer: builtIn), k13)
        XCTAssertThrowsError(try Targeting.choose([k13], named: nil, pointer: p253Screen)) {
            XCTAssertEqual(($0 as? PaperlikeError)?.code, "unavailable")
        }
        XCTAssertThrowsError(try Targeting.choose([], named: nil, pointer: builtIn))
    }

    func testANamedMonitorWinsOverThePointer() throws {
        XCTAssertEqual(try Targeting.choose([k13, p253], named: "13k", pointer: p253Screen), k13)
        XCTAssertEqual(try Targeting.choose([k13, p253], named: "253-color", pointer: nil), p253)
        XCTAssertThrowsError(try Targeting.choose([k13, p253], named: "253-bw", pointer: nil)) {
            XCTAssertEqual(($0 as? PaperlikeError)?.code, "unavailable")
        }
        let mono253 = Monitor(path: "/dev/cu.usbserial-9", firmware: 0x10, modelCode: 4)
        XCTAssertThrowsError(try Targeting.choose([p253, mono253], named: "253", pointer: nil)) {
            XCTAssertEqual(($0 as? PaperlikeError)?.code, "ambiguous")
        }
        XCTAssertEqual(try Targeting.choose([p253, mono253], named: "253-bw", pointer: nil), mono253)
    }

    // An unknown model is a candidate only on a screen no known one drives:
    // a known pairing always wins over a link that cannot say which it is.
    func testAMonitorOfUnknownModelOnlyTakesAScreenNoKnownOneDrives() throws {
        let unknown = Monitor(path: "/dev/cu.usbserial-7", firmware: 0x30, modelCode: 0)
        XCTAssertEqual(try Targeting.choose([k13, unknown], named: nil, pointer: p253Screen), unknown)
        XCTAssertEqual(try Targeting.choose([p253, unknown], named: nil, pointer: p253Screen), p253)
    }

    // Observed: the black-and-white 253 on screen, only the Color's USB cable
    // plugged in. The Color's link must not take commands aimed at that screen.
    func testAColor253LinkIsNeverPairedWithTheBlackAndWhite253Screen() {
        XCTAssertThrowsError(try Targeting.choose([k13, p253], named: nil, pointer: mono253Screen)) {
            XCTAssertEqual(($0 as? PaperlikeError)?.code, "unavailable")
        }
    }

    // Observed after unplugging that 253: the Color's cable alone stays on the
    // dock. From the built-in panel, a shortcut goes to the 13K, the one
    // Paperlike actually on screen.
    func testFromAnotherScreenALinkWithoutItsScreenIsSetAside() throws {
        XCTAssertEqual(try Targeting.choose([k13, p253], named: nil, pointer: builtIn, screens: [builtIn, k13Screen]), k13)
        XCTAssertEqual(try Targeting.choose([k13, p253], named: nil, pointer: builtIn, screens: [builtIn, k13Screen, mono253Screen]), k13)
        XCTAssertThrowsError(try Targeting.choose([k13, p253], named: nil, pointer: builtIn, screens: [builtIn, k13Screen, p253Screen]))
        // No Paperlike screen at all: every link stays a candidate.
        XCTAssertEqual(try Targeting.choose([p253], named: nil, pointer: builtIn, screens: [builtIn]), p253)
        // A name still reaches a link without a screen.
        XCTAssertEqual(try Targeting.choose([k13, p253], named: "253", pointer: builtIn, screens: [builtIn, k13Screen]), p253)
    }
}
