# PaperlikeAgent — POC natif macOS pour DASUNG

**Rôle principal : supprimer le tramage de macOS sur la dalle e-ink.** macOS
active `enableDither` sur chaque framebuffer ; sur e-ink cela se voit comme du
grain, des taches et une image sombre. L’agent remet cette propriété à `false`
sur les seules sorties DASUNG, à chaque cycle de deux secondes, car macOS la
restaure lors d’une reconnexion, d’un réveil ou d’un changement de mode. C’est
exactement ce que fait le client officiel avec son `disableDitheringTimer` — et
la raison pour laquelle fermer sa fenêtre par la croix ramenait le défaut.

Ce réglage est appliqué **quel que soit le mode** : c’est une écriture de
propriété IOKit sur le framebuffer, elle ne touche jamais au port USB. La dalle
interne est délibérément exclue, y supprimer le tramage produirait du banding.
Mécanisme, preuves et mesures : [RESEARCH.md](RESEARCH.md).

**Plusieurs écrans DASUNG.** Toutes les sorties dont le fabricant EDID est
`0x1263` sont traitées, chacune indépendamment : un Paperlike noir et blanc et
un Revo Color branchés ensemble sont couverts sans réglage. Ne pas les
identifier par leur `ProductName`, identique sur les deux ; utiliser
`SerialNumber` et `YearOfManufacture`.

**Branchement à chaud.** L’agent s’abonne à
`CGDisplayRegisterReconfigurationCallback` et ré-applique l’anti-tramage dès la
fin d’une reconfiguration, puis à 0,15 s, 0,4 s et 1 s — macOS pose parfois
`enableDither` juste après l’apparition du framebuffer. Le minuteur de deux
secondes reste le filet de sécurité si le callback est refusé, ce que
`paperlike status` signale par `reconfigurationCallbackRegistered: false`.

**Surveillance de la table gamma.** `paperlike status` expose un champ `gamma`
par sortie DASUNG (`ceiling`, `maxDeviation`), et l’agent journalise une erreur
dès qu’une table cesse d’être linéaire. C’est le réglage hôte le plus destructeur
pour de l’e-ink — un plafond sous `1.0` écrase tous les niveaux de gris, qui
*sont* l’image — et il est invisible dans les Réglages d’affichage. Cause
typique : la luminosité logicielle de BetterDisplay sur un écran sans contrôle
matériel. **Signalé, jamais corrigé** : l’agent n’écrit qu’une propriété, sur les
framebuffers d’un seul fabricant, et disputer la table gamma à un autre outil
défairait cette garantie.

**Veille écran et veille système sont deux cas distincts.** Éteindre un moniteur
ou le laisser s’endormir n’émet aucune notification `NSWorkspace` : l’agent ne se
met pas en pause, son minuteur continue et le rallumage est couvert par le
minuteur comme par le callback de reconfiguration. C’est le cas courant avec ces
écrans. Seule la veille du Mac émet `willSleep`/`didWake` : l’agent suspend alors
son minuteur, et `didWake` déclenche un cycle immédiat.

Un agent Swift sans icône dans le Dock, Cmd-Tab ou la barre des menus, qui ne
prend jamais le focus. Sa seule fenêtre est le HUD affiché brièvement après un
raccourci, en mode contrôle (voir plus bas). **Par défaut il applique l’anti-tramage et observe la présence du DASUNG
et de sa liaison USB, sans ouvrir le port.** Le mode contrôle, séparé, valide le
MCU, entretient la connexion et sert la CLI et les raccourcis globaux. Le
contrôle USB n’est pas nécessaire à l’anti-tramage : les deux modes l’appliquent.

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

Le mode par défaut peut coexister avec le client officiel et ne réserve aucun
raccourci ; les deux écrivent la même propriété avec la même valeur.
`paperlike status` expose `ditheringReasserts`, le nombre de fois où macOS a
remis le tramage et où l’agent l’a retiré. Après diagnostic et validation visuelle, `make paperlike-control`
active le contrôle USB au login. **L’agent réserve alors le port CH340 en
exclusivité : PaperLikeClient ne pourra plus l’ouvrir tant qu’il tourne.**
Revenir à l’anti-tramage seul, et rendre le port au client : `make paperlike`.

En mode contrôle, **Control + Option + Command + R** envoie une demande
d’effacement des rémanences depuis n’importe quelle application.
Cette combinaison n’inclut pas Maj et ne remplace donc pas Hyper+R.
L’agent utilise `RegisterEventHotKey` : il n’écoute pas les frappes et ne demande
pas de permission Accessibilité. Un conflit de raccourci est signalé dans
`paperlike status` (`refreshShortcut.registered: false`).

### Réglages de l'écran (mode contrôle)

Chaque réglage du client officiel est exposé, avec ses bornes. Une valeur signée
agit **relativement** (`paperlike light +10`), ce qui est ce dont un raccourci a
besoin. **Toute écriture est confirmée par relecture du registre** : sans
confirmation, la commande échoue au lieu de prétendre avoir abouti — c'est
précisément le mode de défaillance rencontré avec le client propriétaire.

| Commande | Bornes | Réglage |
| --- | --- | --- |
| `paperlike contrast` | 1–9 | Contraste |
| `paperlike mode` | 1–2 | Texte / image |
| `paperlike speed` | 1–5 | Vitesse de rafraîchissement |
| `paperlike light on\|off\|toggle` | — | Lumière frontale : allumer / éteindre |
| `paperlike light-mode` | 0–3 | Lumière frontale : 0 éteinte |
| `paperlike light` | 0–100 | Lumière frontale : luminosité |
| `paperlike light-temp` | 0–100 | Lumière frontale : température |
| `paperlike text-enhance` | 0–1 | Rehaussement du texte |
| `paperlike refresh` | — | Ghost Cleanup |
| `paperlike read 09` | — | Lire un registre brut (diagnostic) |

La luminosité frontale n'est acceptée **que si la lumière est allumée** : sinon le
moniteur ignore l'écriture sans rien dire. L'agent le détecte et le signale.
`paperlike light on` rétablit le dernier mode de lumière utilisé, retenu entre
deux redémarrages de l'agent ; pour en choisir un, `paperlike light-mode 1..3`
une fois. Si la luminosité vaut alors 0, elle est remontée à 20 pour que
l'allumage se voie.

Un réglage prend environ 0,1 s : lecture, écriture, relecture ; allumer ou
éteindre la lumière un peu plus, le moniteur ignorant la relecture qui suit
aussitôt, renvoyée alors 0,2 s plus tard. Les appuis rapprochés sur un même
raccourci sont fusionnés en une seule écriture.

### Raccourcis clavier

Actifs en mode contrôle, sur Control+Option+Command (« Meh », sans Maj, donc
Hyper reste libre). Les flèches sont choisies exprès : leurs codes ne changent
pas d'une disposition à l'autre, ce qu'une lettre ne garantit pas sur AZERTY.

| Raccourci | Action |
| --- | --- |
| `Ctrl+Opt+Cmd+R` | Ghost Cleanup |
| `Ctrl+Opt+Cmd+L` | Allumer / éteindre la lumière frontale |
| `Ctrl+Opt+Cmd+↑ / ↓` | Luminosité frontale ±10 |
| `Ctrl+Opt+Cmd+→ / ←` | Contraste ±1 |

`L` occupe la même place en AZERTY et en QWERTY. `paperlike status` liste
chaque raccourci avec son état d'enregistrement : un raccourci déjà pris par une
autre application échoue silencieusement sinon.

### HUD

Après chaque raccourci, un petit panneau apparaît 1,6 s en haut à droite de
l'écran sous le pointeur, comme celui de la luminosité de macOS : réglage,
valeur (`40 %`, `3 / 9`), jauge à un segment par cran, et **`Max` / `Min`**
en butée. Il n'affiche que la réponse de la commande qui vient d'aboutir, sans
échange série supplémentaire.

Il est dessiné pour l'e-ink : opaque, noir sur blanc, sans ombre ni animation
— chaque image d'un fondu serait un rafraîchissement partiel de plus. Sur la
dalle, son apparition et sa disparition coûtent tout de même deux petits
rafraîchissements, et peuvent laisser une rémanence que Ctrl+Opt+Cmd+R efface.
Le panneau n'est pas activant et ignore la souris : le focus reste à la fenêtre
en cours. `"hud": false` dans la configuration le supprime.

### Personnalisation facultative

Fichier lu **une fois au démarrage**, absent par défaut :
`~/.config/paperlike/config.json`

```json
{ "hotkeys": [
    { "keys": "ctrl+alt+cmd+up", "action": ["light", "+10"] },
    { "keys": "ctrl+alt+cmd+t",  "action": ["text-enhance", "1"] }
  ],
  "hud": true }
```

Pas de surveillance de fichier, pas de rechargement, pas de fenêtre de
réglages : l'agent reste un processus d'arrière-plan. Un fichier absent ou illisible
donne les valeurs par défaut et **l'agent démarre quand même** — l'anti-tramage,
sa seule fonction essentielle, ne dépend jamais de ce fichier. Les erreurs de
configuration apparaissent dans `paperlike status`.

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
`prohibited` tiennent l’application hors du Dock et de Cmd-Tab ; `paperlike
status` vérifie `takesFocus: false`. Le socket local et son verrou
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
- Les opérations série sont sérialisées et bornées dans le temps ; une lecture
  rend la main dès que sa réponse arrive, le délai ne sert qu’en cas d’échec.
  Les réponses USB fragmentées ou regroupées sont reconstituées. Une écriture suivie d’une
  réponse absente est rapportée comme non confirmée, jamais comme un succès.
- Le mode se lit, mais son changement n’est pas exposé : les tables diffèrent
  entre les générations. Le rétroéclairage et l’anti-dithering restent hors POC.
  Le POC ne modifie aucun réglage graphique global de macOS.
- Avant le message Mac `0x20/1`, le POC vérifie que `enableDither` est bien `No`
  pour les sorties DASUNG observées. Si cet état est absent ou activé, il refuse
  l’envoi. Cette vérification corrige une hypothèse du premier essai ; elle ne
  démontre pas à elle seule la cause du problème d’affichage signalé.
- Les raccourcis se redéfinissent dans `~/.config/paperlike/config.json`, relu
  seulement au démarrage de l’agent (`make paperlike-control` pour le relancer).

Les transitions et erreurs de connexion sont dans le journal unifié macOS :

```sh
log show --last 10m --predicate 'subsystem == "com.user.paperlike-agent"'
```

Le canal de commandes est un socket Unix réservé à l’utilisateur, dans
`~/Library/Application Support/PaperlikeAgent/`. Aucun serveur réseau, télémétrie
ou téléchargement n’est utilisé par l’application.
