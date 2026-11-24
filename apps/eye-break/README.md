# EyeBreak

Petite app de barre de menus pour reposer les yeux (règle 20-20-20) : toutes les
20 minutes, un écran noir plein écran demande de regarder au loin pendant 20 secondes.

## Installer

```sh
make eye-break
```

Compile `EyeBreak.swift` avec `swiftc` (Command Line Tools suffisent), installe
`~/Applications/EyeBreak.app` et la lance à chaque connexion (LaunchAgent
`com.user.eye-break`).

## Utilisation

- L'icône 👁 dans la barre de menus affiche les minutes avant la prochaine pause.
- Pendant la pause : **Échap** ou *Passer* pour sauter, *Dans 5 min* pour repousser.
  Un son (Glass) signale la fin.
- Menu : pause immédiate, suspendre 1 h ou jusqu'à reprise, intervalle
  (10 à 60 min), durée de la pause (20 s à 5 min).
- Veille, verrouillage ou 60 s sans clavier/souris comptent comme une pause : le
  compteur repart à zéro.

## Désinstaller

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.eye-break.plist
```

puis supprimer `~/Applications/EyeBreak.app` et le plist.
