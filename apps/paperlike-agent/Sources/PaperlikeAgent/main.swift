import AppKit
import PaperlikeCore

let help = """
PaperlikeAgent — background controller for DASUNG e-ink displays

  paperlike status            Agent state, displays, gamma, shortcuts (JSON)
  paperlike detect            Inventory without opening the USB port
  paperlike query             Read back every known display setting
  paperlike read 09           Read a raw register, in hexadecimal

  paperlike refresh           Clear ghosting (“Ghost Cleanup”), over USB
  paperlike clear             Clear ghosting by flashing the panel black then
                              white; drawn by the Mac, no USB needed
  paperlike light on|off|toggle  Switch the front light on or off
\(Setting.all.map { "  paperlike \($0.name.padding(toLength: 12, withPad: " ", startingAt: 0)) \($0.bounds.lowerBound)..\($0.bounds.upperBound)\(String(repeating: " ", count: max(0, 7 - "\($0.bounds.lowerBound)..\($0.bounds.upperBound)".count)))\($0.summary)" }.joined(separator: "\n"))

A signed value is relative: “paperlike light +10” goes up by ten.
Every write is confirmed by reading the register back; without that
confirmation the command fails rather than claim success.

Front-light brightness works like a brightness key: 0 switches the light
off, a positive value switches it on (“light +10” from off: 10%).
“paperlike light on” restores the last level; if that level is 0, 20.

The agent continuously removes macOS dithering from DASUNG outputs; that is
its main job and it does not need the USB port.
Settings and their shortcuts: make paperlike-control (the agent then holds
the CH340 port, and PaperLikeClient can no longer open it).

Default shortcuts (Control+Option+Command); without control mode, only
clear is registered:
\(Configuration.defaultHotkeys.map { "  \($0.0.padding(toLength: 20, withPad: " ", startingAt: 0)) \($0.1.joined(separator: " "))" }.joined(separator: "\n"))

Optional customization, read at startup:
  \(Configuration.path)
  {"hotkeys":[{"keys":"ctrl+alt+cmd+up","action":["light","+10"]}]}
  {"hud":false}   Turn off the on-screen display after a shortcut
Missing or unreadable file: the defaults apply and the agent starts
anyway — anti-dithering never depends on this file.

Install and start: make paperlike
Stop and disable at login: make paperlike-stop
Uninstall: make paperlike-uninstall
"""

func output(_ value: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
}

signal(SIGPIPE, SIG_IGN)
let args = Array(CommandLine.arguments.dropFirst())
do {
    if args == ["--agent"] || args == ["--agent", "--control"] || args.isEmpty {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let controlEnabled = args.contains("--control")
        let configuration = Configuration.load()
        let bindings = configuration.activeHotkeys(controlEnabled: controlEnabled)
        // The HUD only ever reports a shortcut's result, so it exists only
        // where shortcuts do. Anti-dithering never depends on it.
        let hud = !bindings.isEmpty && configuration.hud ? HUD() : nil
        let agent = Agent(controlEnabled: controlEnabled, hudEnabled: hud != nil,
                          configurationProblems: configuration.problems)
        let socket = LocalSocket()
        try socket.serve { agent.request($0) }
        let center = NSWorkspace.shared.notificationCenter
        let sleep = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in agent.sleep(true) }
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in agent.sleep(false) }
        agent.start()
        let hotkey = bindings.isEmpty ? nil : HotKeyCenter(agent: agent, hud: hud, bindings: bindings)
        withExtendedLifetime((agent, socket, sleep, wake, hotkey, hud)) { application.run() }
    } else if args == ["help"] || args == ["--help"] {
        print(help)
    } else if args == ["detect"] {
        let data = try JSONEncoder().encode(Inventory.capture())
        try output(JSONSerialization.jsonObject(with: data))
    } else {
        let passthrough = args == ["status"] || args == ["query"] || (args.count == 2 && args[0] == "read")
        if !passthrough { _ = try Action.parse(args) }
        let reply = try LocalSocket.request(args)
        try output(reply)
        if reply["ok"] as? Bool != true { exit(1) }
    }
} catch {
    try? output(["ok": false, "error": String(describing: error)])
    exit(1)
}
