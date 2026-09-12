# Recherche et preuves — 12 septembre 2026

## État après le retour utilisateur

L’utilisateur a signalé un **problème d’affichage** après l’essai. Le POC a été
arrêté, son démarrage au login désactivé, et PaperLikeClient relancé. Le port USB
a bien été repris par le client officiel. La nature du défaut visuel reste à
préciser : les preuves d’échange USB ci-dessous ne valident pas le rendu physique.

**Précision ultérieure de l’utilisateur, le 12 septembre 2026 :** le même défaut
existe avec le client officiel. D’après son récit, l’affichage fonctionnait
jusqu’à la fermeture de la fenêtre PaperLikeClient par sa croix ; relancer le
client, redémarrer le Mac et éteindre/rallumer l’écran n’ont pas résolu le
problème. Il ne l’attribue pas au POC et demande de conserver celui-ci dans
`mac-setup`. Il prévoit de débrancher complètement l’écran. Le résultat de cet
essai manuel reste à recueillir ; la succession des événements ne démontre pas
la cause du défaut. Le POC reste désactivé pendant cet essai.

La version suivante démarre donc en **observation sans ouverture USB** par
défaut. Le contrôle demande un choix explicite séparé. Elle vérifie aussi
`enableDither = No` sur les sorties DASUNG avant d’annoncer cet état via `0x20/1`.
Ce contrôle de cohérence n’est pas présenté comme un correctif visuel prouvé.
Le mode contrôle n’a pas été relancé après le signalement utilisateur.

La version finale a passé **9 tests automatisés** et un essai réel en observation :
écran détecté, `controlEnabled = false`, zéro fenêtre, commandes de réglage
refusées et deuxième instance refusée. `lsof` confirme que seul PaperLikeClient
possédait le port USB pendant cet essai. Le processus d’observation a ensuite
été arrêté ; son LaunchAgent est toujours `disabled`. L’application installée
a été mise à jour avec cette version. Trace locale :
`cache/paperlike-agent/observation-test.json`.

## Matériel et client examinés

- macOS 26.6.2, Apple M1 Max.
- L’écran physique se présente à macOS comme `Paperlike253`, EDID fabricant
  `0x1263`, produit `0x0000`, 3200 × 1800, mode observé à 40 Hz. Le « 153 »
  mentionné initialement ne correspond pas au nom détecté.
- Le client officiel affiche `PaperLike253(Color) [FrontLight]`.
- La liaison de contrôle expose `/dev/cu.usbserial-2115410`, CH340
  `1a86:7523`. Le chemin est détecté dynamiquement, jamais codé en dur.
- Une seconde sortie vidéo reprend le nom/fabricant DASUNG avec produit `0x253C`.
  Sa nature et son câblage ne sont pas établis ; il ne faut pas en déduire un
  second écran physique, ni supposer qu’elle est virtuelle.
- Le client a été mis à jour pendant l’investigation. Sa fenêtre indique
  **V2.0.3**, mais son `Info.plist` conserve `CFBundleVersion = 1.2`.
  SHA-256 du binaire examiné après cette mise à jour :
  `c64c223493cae5d2fb86cdcbe8bddb7d75827dbd3e847500af66517b0e0e9304`.

## Sources primaires

1. [DASUNG — téléchargements officiels](https://www.dasung.com/h-col-112.html) :
   client Mac V2.0.3 disponible au moment de l’étude.
2. [PaperlikeMenu](https://github.com/WooHooDai/PaperlikeMenu) : alternative
   macOS récente, menus, raccourcis et login. L’auteur ne déclare des essais que
   sur PaperLike HD-FT M / Mac mini M4. Le dépôt consulté distribue le produit
   et sa documentation ; il n’établit pas sa compatibilité avec ce Color Revo.
   Aucun code ou binaire de ce projet n’est embarqué dans le POC.
3. [Denis Sandmann — Dasung Paperlike 253 Linux Driver](https://github.com/dnsandmann/Dasung-Paperlike-253-Linux-Driver) :
   rétro-ingénierie USB, CH340, protocole ASCII à 115200 bauds, identification et
   keepalive. Annonce publique datée du 5 juin 2026. Le comportement Linux ne
   prouve pas à lui seul celui du Mac ; les échanges ont été testés ici.
4. [Philip Metzler — dasung253](https://github.com/cpmetz/dasung253/blob/master/dasung253.py) :
   captures et commandes publiées en 2022 pour contraste, vitesse et effacement.
   Les réglages ont été recoupés avec le client installé puis avec le moniteur.
5. [Apple — LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
   et [Launch Services Keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html) :
   application agent masquée du Dock.
6. [Apple — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
   et [Launch Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) :
   démarrage au login. Le POC utilise le LaunchAgent utilisateur déjà employé
   dans mac-setup ; une version distribuée pourra employer SMAppService.

## Protocole recoupé

Les messages sont **24 caractères ASCII**, pas douze octets binaires :
`5FF5` + commande hexadécimale + valeur hexadécimale + douze `0` + `A0FA`.
L’implémentation Swift est indépendante ; elle ne charge ni ne redistribue le
client propriétaire. Les scripts publics ont été consultés comme descriptions
du protocole. Le binaire installé a été inspecté localement pour vérifier le
format, les bornes des réglages et les MCU acceptés.

| Action | Message hôte |
| --- | --- |
| Lire le MCU | `5FF50A10000000000000A0FA` |
| Lire le contraste | `5FF50A01000000000000A0FA` |
| Lire le mode | `5FF50A02000000000000A0FA` |
| Lire la vitesse | `5FF50A04000000000000A0FA` |
| Garder l’image active | `5FF52001000000000000A0FA` |
| Effacer les rémanences | `5FF50300000000000000A0FA` |
| Contraste 2 | `5FF50102000000000000A0FA` |
| Vitesse 5 | `5FF50405000000000000A0FA` |

Réponses réelles enregistrées :

```text
5FF5F00A103011100001A0FA  MCU 0x30 ; autres octets conservés, non interprétés
5FF5F00A010100000000A0FA  contraste 1
5FF5F00A020200000000A0FA  mode 2
5FF5F00A040400000000A0FA  vitesse 4
5FF5F020000000000000A0FA  accusé de réception du keepalive
5FF5F003000000000000A0FA  accusé de réception de l’effacement
```

Le keepalive est envoyé toutes les deux secondes pour conserver une marge par
rapport au délai d’environ cinq secondes décrit par la source Linux. Aucune
commande « reset », mise à jour de firmware ou extinction n’est exposée.

Point identifié après le retour utilisateur : dans le client Mac V2.0.3,
`updateDitheringInfo:` envoie la commande `0x20` avec l’état de désactivation du
dithering, depuis `tryToDisableDithering`. Le message ne doit donc pas être
interprété comme un simple keepalive indépendant de l’état graphique du Mac.
Après retour au client officiel, les propriétés `enableDither` lues sont `No` ;
cela ne prouve pas leur valeur pendant l’essai du POC. BetterDisplay est aussi
actif. La cause du défaut visuel n’est pas encore identifiée.

## Validation réalisée

- Compilation native et signature ad hoc de l’application.
- Tests du protocole, bruit et fragmentation USB, filtrage des réponses,
  bornes de commandes, refus de sélection ambiguë et échange par pseudo-terminal.
- Installation réelle du LaunchAgent. macOS indique `running` et l’entrée de
  démarrage est `enabled, allowed` dans `sfltool dumpbtm`.
- `NSRunningApplication` indique `activationPolicy = 2` (prohibited),
  `active = false`, et CoreGraphics compte **zéro fenêtre** du processus.
- Le POC attend pendant que le client officiel est ouvert. Après sa fermeture,
  l’identification série réussit avec MCU `0x30`.
- Contraste **1 → 2 → 1**, vitesse **4 → 5 → 4** : valeurs confirmées par
  relecture après chaque écriture. État final identique à l’état initial.
- Effacement reçu et acquitté par le moniteur. L’effet sur la dalle physique
  nécessite l’observation de l’utilisateur.
- Raccourci Control+Option+Command+R accepté par macOS (`OSStatus = 0`).
  La frappe physique reste à essayer par l’utilisateur.

Le journal détaillé de l’essai de réglages reste local dans
`cache/paperlike-agent/hardware-test.json` (ignoré par Git).
Ces résultats prouvent les échanges sur ce Mac et cet écran pendant l’essai,
pas la stabilité sur plusieurs jours ni les cycles de veille, débranchement ou
redémarrage complet. Aucun diagnostic global du code propriétaire n’est revendiqué.
