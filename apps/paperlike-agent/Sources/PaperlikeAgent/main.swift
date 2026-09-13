import AppKit
import PaperlikeCore

let help = """
PaperlikeAgent — contrôleur DASUNG en arrière-plan

  paperlike status            État de l’agent, écrans, gamma, raccourcis (JSON)
  paperlike detect            Inventaire sans ouvrir le port USB
  paperlike query             Relire tous les réglages connus de l’écran
  paperlike read 09           Lire un registre brut, en hexadécimal

  paperlike refresh           Effacer les rémanences (« Ghost Cleanup »)
  paperlike light on|off|toggle  Allumer ou éteindre la lumière frontale
\(Setting.all.map { "  paperlike \($0.name.padding(toLength: 12, withPad: " ", startingAt: 0)) \($0.bounds.lowerBound)..\($0.bounds.upperBound)\(String(repeating: " ", count: max(0, 7 - "\($0.bounds.lowerBound)..\($0.bounds.upperBound)".count)))\($0.summary)" }.joined(separator: "\n"))

Une valeur signée agit relativement : « paperlike light +10 » monte de dix.
Toute écriture est confirmée par relecture du registre ; sans confirmation,
la commande échoue plutôt que de prétendre avoir abouti.

La luminosité frontale se comporte comme une touche de luminosité : 0 éteint
la lumière, une valeur positive l’allume (« light +10 » depuis éteinte : 10 %).
« paperlike light on » rétablit le dernier niveau ; s’il vaut 0, 20.

L’agent retire en permanence le tramage macOS des sorties DASUNG ; c’est sa
fonction principale et elle ne demande pas le port USB.
Réglages et raccourcis : make paperlike-control (l’agent garde alors le port
CH340, PaperLikeClient ne pourra plus l’ouvrir).

Raccourcis par défaut en mode contrôle (Control+Option+Command) :
\(Configuration.defaultHotkeys.map { "  \($0.0.padding(toLength: 20, withPad: " ", startingAt: 0)) \($0.1.joined(separator: " "))" }.joined(separator: "\n"))

Personnalisation facultative, lue au démarrage :
  \(Configuration.path)
  {"hotkeys":[{"keys":"ctrl+alt+cmd+up","action":["light","+10"]}]}
  {"hud":false}   Désactiver l’affichage à l’écran après un raccourci
Fichier absent ou illisible : les valeurs par défaut s’appliquent et l’agent
démarre quand même — l’anti-tramage ne dépend jamais de ce fichier.

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
        let configuration = Configuration.load()
        // The HUD only ever reports a shortcut's result, so it exists only
        // where shortcuts do. Anti-dithering never depends on it.
        let hud = controlEnabled && configuration.hud ? HUD() : nil
        let agent = Agent(controlEnabled: controlEnabled, hudEnabled: hud != nil,
                          configurationProblems: configuration.problems)
        let socket = LocalSocket()
        try socket.serve { agent.request($0) }
        let center = NSWorkspace.shared.notificationCenter
        let sleep = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in agent.sleep(true) }
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in agent.sleep(false) }
        agent.start()
        let hotkey = controlEnabled ? HotKeyCenter(agent: agent, hud: hud, bindings: configuration.hotkeys) : nil
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
