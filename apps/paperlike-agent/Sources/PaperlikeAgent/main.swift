import AppKit
import PaperlikeCore

let help = """
PaperlikeAgent — contrôleur DASUNG sans fenêtre

  paperlike status          État de l’agent et de la connexion USB (JSON)
  paperlike detect          Inventaire sans ouvrir le port USB
  paperlike query           Relire les réglages de l’écran
  paperlike refresh         Effacer les rémanences
  paperlike contrast 1..9   Régler le contraste, puis relire la valeur
  paperlike speed 1..5      Régler la vitesse, puis relire la valeur

Par défaut, le POC observe les connexions sans ouvrir le port USB.
Contrôle expérimental : make paperlike-control (affichage à revalider).
En mode contrôle : Control+Option+Command+R pour effacer les rémanences.

Installation/démarrage : make paperlike
Arrêt et désactivation au login : make paperlike-stop
Désinstallation : make paperlike-uninstall
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
        let agent = Agent(controlEnabled: controlEnabled)
        let socket = LocalSocket()
        try socket.serve { agent.request($0) }
        let center = NSWorkspace.shared.notificationCenter
        let sleep = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in agent.sleep(true) }
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in agent.sleep(false) }
        agent.start()
        let hotkey = controlEnabled ? HotKey(agent: agent) : nil
        withExtendedLifetime((agent, socket, sleep, wake, hotkey)) { application.run() }
    } else if args == ["help"] || args == ["--help"] {
        print(help)
    } else if args == ["detect"] {
        let data = try JSONEncoder().encode(Inventory.capture())
        try output(JSONSerialization.jsonObject(with: data))
    } else {
        if args != ["status"] && args != ["query"] { _ = try Action.parse(args) }
        let reply = try LocalSocket.request(args)
        try output(reply)
        if reply["ok"] as? Bool != true { exit(1) }
    }
} catch {
    try? output(["ok": false, "error": String(describing: error)])
    exit(1)
}
