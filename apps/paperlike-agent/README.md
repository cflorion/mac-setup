# PaperlikeAgent — POC natif macOS pour DASUNG

**État de l’essai :** les commandes USB ont été confirmées par le moniteur ;
leur résultat visuel reste à valider. L’utilisateur précise que le même défaut
d’affichage existe avec le client officiel, depuis la fermeture de sa fenêtre
par la croix. La cause reste indéterminée. Le POC est conservé dans ce dossier,
arrêté et désactivé au login sur ce Mac ; le client officiel a été rétabli.
L’utilisateur prévoit un débranchement complet de l’écran avant de reprendre
le diagnostic. Voir [RESEARCH.md](RESEARCH.md) pour le suivi.

Un agent Swift sans fenêtre, sans icône dans le Dock, Cmd-Tab ou la barre des
menus. **Par défaut, il observe la présence du DASUNG et de sa liaison USB sans
ouvrir le port.** Un mode de contrôle expérimental séparé valide le MCU,
entretient la connexion et reçoit les commandes de la CLI ou du raccourci global.

Le matériel observé sur ce Mac est nommé **Paperlike253** par macOS : Color,
3200 × 1800, MCU `0x30`, interface CH340 `1a86:7523`. Le POC ne constitue pas
une validation de tous les modèles DASUNG. Voir [RESEARCH.md](RESEARCH.md).

## Installation et commandes

Depuis `~/code/mac-setup`, avec les outils de développement Apple installés :

```sh
make paperlike-test       # Tests sans envoyer de commande à un écran
make paperlike           # Compile, installe et démarre la détection au login
paperlike status
```

L’application est installée dans `~/Applications/PaperlikeAgent.app`.
La compilation est native pour le Mac utilisé, sans dépendance externe.
La signature ad hoc convient à cet usage local ; ce n’est pas une distribution
signée et notariée pour d’autres utilisateurs.

Le mode observation peut coexister avec le client officiel et ne réserve aucun
raccourci. Après diagnostic et validation visuelle, `make paperlike-control`
permet d’activer explicitement le contrôle USB expérimental au login.

En mode contrôle, **Control + Option + Command + R** envoie une demande
d’effacement des rémanences depuis n’importe quelle application.
Cette combinaison n’inclut pas Maj et ne remplace donc pas Hyper+R.
L’agent utilise `RegisterEventHotKey` : il n’écoute pas les frappes et ne demande
pas de permission Accessibilité. Un conflit de raccourci est signalé dans
`paperlike status` (`refreshShortcut.registered: false`).

```sh
paperlike detect         # Présence écran / USB, sans ouvrir le port
paperlike status         # Connexion, processus, raccourci, dernières réponses
paperlike query          # Relire MCU, contraste, mode et vitesse
paperlike refresh        # Effacement des rémanences
paperlike contrast 3     # Valeur de 1 à 9
paperlike speed 4        # Valeur de 1 à 5
```

Ces commandes s’utilisent aussi dans une action « Exécuter un script shell » de
Raccourcis ou un script Raycast. Si le PATH y est réduit, utiliser par exemple :

```sh
"$HOME/.local/bin/paperlike" refresh
```

La sortie est du JSON, avec un code de retour non nul en cas d’erreur. Pour un
réglage, `confirmed_by_readback` signifie que l’écran a renvoyé la valeur
demandée. Pour un effacement, `acknowledged_by_device` confirme sa réception,
pas son résultat visuel. `sent` signifie seulement que l’écriture a abouti.
`status.ok` concerne le diagnostic ; vérifier `state: connected` pour la liaison.

## Démarrage et retour au client officiel

Le LaunchAgent utilisateur est enregistré dans
`~/Library/LaunchAgents/com.user.paperlike-agent.plist`. Il démarre à **l’ouverture
de session**, sans terminal, et est relancé après un crash. Aucun service root
ni extension noyau n’est ajouté. `LSUIElement` et une politique d’activation
`prohibited` rendent l’application invisible. Le socket local et son verrou
empêchent deux instances de piloter simultanément l’écran.

Un LaunchAgent correspond au fonctionnement de ce dépôt de configuration.
Pour une application distribuée avec une interface de préférences, on choisirait
plutôt `SMAppService` (macOS 13+) pour gérer le login depuis l’application.
Le POC reste un module optionnel : `make install` / `make update` ne l’activent pas.

```sh
make paperlike-stop      # Arrête et désactive le lancement au login
open -a PaperLikeClient  # Retour au logiciel DASUNG
```

Pour reprendre l’observation, lancer `make paperlike` ; le client officiel peut
rester ouvert. Le remplacement expérimental suit la procédure de contrôle
décrite plus haut, après diagnostic et validation visuelle.
Pour retirer l’application et son LaunchAgent :

```sh
make paperlike-uninstall
```

Les sources, le cache de compilation et la commande du dépôt restent présents.
Si cette variante de l’écran dépend du keepalive, son image peut disparaître
quand tous les clients sont arrêtés ; rouvrir PaperLikeClient rétablit son rôle.

En mode contrôle, l’agent attend si PaperLikeClient, PaperlikeMenu ou InkControl est ouvert.
Désactiver « Launch at Startup » dans le client officiel lors du remplacement,
pour éviter qu’il prenne la main au prochain login. Il peut toujours être
rouvert manuellement. Aucune désinstallation du client DASUNG n’est nécessaire.

## Diagnostic et limites

- Un écran vidéo détecté ne prouve pas la liaison USB de contrôle. Le câble doit
  aussi transporter les données USB ; HDMI seul ne suffit pas.
- Sélection prudente : EDID DASUNG `0x1263`, un seul CH340 `1a86:7523`, puis une
  réponse MCU reconnue. Ce VID/PID est générique ; en présence d’autres CH340,
  le POC refuse de choisir. Il ne parcourt pas les autres ports série.
- Reconnexion toutes les deux secondes, fermeture du port pendant la veille,
  nouvelle identification au réveil. Les essais de veille/réveil, de débranchement
  physique et d’ouverture de session réelle restent à faire.
- Les opérations série sont sérialisées et bornées dans le temps. Les réponses
  USB fragmentées ou regroupées sont reconstituées. Une écriture suivie d’une
  réponse absente est rapportée comme non confirmée, jamais comme un succès.
- Le mode se lit, mais son changement n’est pas exposé : les tables diffèrent
  entre les générations. Le rétroéclairage et l’anti-dithering restent hors POC.
  Le POC ne modifie aucun réglage graphique global de macOS.
- Avant le message Mac `0x20/1`, le POC vérifie que `enableDither` est bien `No`
  pour les sorties DASUNG observées. Si cet état est absent ou activé, il refuse
  l’envoi. Cette vérification corrige une hypothèse du premier essai ; elle ne
  démontre pas à elle seule la cause du problème d’affichage signalé.
- Le raccourci est fixe dans cette première version. La CLI permet d’en définir
  d’autres dans les outils existants sans ajouter une fenêtre de réglages.

Les transitions et erreurs de connexion sont dans le journal unifié macOS :

```sh
log show --last 10m --predicate 'subsystem == "com.user.paperlike-agent"'
```

Le canal de commandes est un socket Unix réservé à l’utilisateur, dans
`~/Library/Application Support/PaperlikeAgent/`. Aucun serveur réseau, télémétrie
ou téléchargement n’est utilisé par l’application.
