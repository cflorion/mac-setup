# Recherche et preuves — 12 septembre 2026

## Cause du défaut visuel : table gamma écrasée par BetterDisplay

**Deux attributions erronées ont précédé celle-ci dans ce fichier. Les voici
consignées, parce que chacune paraissait solide.**

Le défaut — image sombre, couleurs sales, larges zones noires qui vibrent au
moindre mouvement — n'était causé ni par le moniteur, ni par ses registres, ni
par le tramage de macOS. Il venait de la **table gamma de la sortie**, écrasée
par la luminosité logicielle de BetterDisplay.

### L'expérience qui l'a isolé

L'utilisateur a ouvert une **session macOS vierge** sur le même Mac, avec le même
écran et les mêmes câbles : l'affichage y est correct. Cela disqualifie d'un seul
coup le matériel, l'état interne du moniteur et tout réglage système partagé, et
désigne l'état propre à la session utilisateur. Aucune des mesures précédentes
n'avait cette force de discrimination.

### La mesure confirmante

| Écran | Plafond de la table gamma | Écart max à la rampe identité |
| --- | --- | --- |
| Interne (`41038`) | `1.000` | `0.0000` |
| DASUNG `9532` | **`0.375`** | **`0.6250`** |

Et dans les préférences de BetterDisplay :

```
value@softwareBrightness-ColorController@Display:12 = 0.375   ← Revo Color
value@softwareBrightness-ColorController@Display:2  = 1       ← écran interne
value@hardwareBrightness-DDCController@Display:12   = 0
```

Les deux valeurs `0.375` coïncident exactement. Le moniteur n'ayant pas de
contrôle de luminosité matériel exploitable, BetterDisplay n'a d'autre moyen
d'assombrir que d'écraser la table gamma. Sur un LCD rétroéclairé, cela ne fait
qu'assombrir. Sur e-ink, **les niveaux de gris *sont* l'image** : tout se retrouve
tassé dans le tiers bas de la plage, le contraste s'effondre et le waveform du
panneau s'affole sur des valeurs devenues ambiguës.

Cela explique aussi ce qui résistait : la persistance après redémarrage
(BetterDisplay restaure son réglage au login), l'échec du client officiel — qui
met pourtant bien `enableDither = false` — et le fait que débrancher ou
redémarrer le moniteur ne changeait rien, la table étant côté hôte.

### Propriété de la table gamma à connaître

CoreGraphics **restaure la table gamma à la fin du processus qui l'a écrite.**
Un correctif appliqué par un utilitaire à durée de vie courte ne tient donc pas,
et l'assombrissement de BetterDisplay ne subsiste que tant qu'il tourne. Cette
propriété a d'abord fait croire à l'échec d'un test de détection ; c'était le
test qui était mal construit, pas la détection.

### Détection ajoutée à l'agent

`paperlike status` expose désormais un champ `gamma` par sortie DASUNG
(`ceiling`, `maxDeviation`), et l'agent journalise une erreur dès qu'une table
cesse d'être linéaire. **En lecture seule, délibérément** : corriger la table
ferait de l'agent un second écrivain en conflit avec BetterDisplay ou tout outil
de calibration légitime, alors que toute sa sûreté tient à ce qu'il n'écrive
qu'une seule propriété, sur les framebuffers d'un seul fabricant.

Essai : table maintenue à `0.375` par un processus tiers → `ceiling: 0.375`,
`maxDeviation: 0.625` et l'erreur journalisée ; au relâchement, retour à
`ceiling: 1`, `maxDeviation: 0` et la notice de retour au linéaire.

## Le tramage : un défaut réel, mais distinct

Ce qui suit reste exact et utile — le tramage **était** activé et devait être
désactivé — mais il faut cesser de lui attribuer le défaut visuel ci-dessus.

macOS expose `enableDither` sur chaque framebuffer ; sur e-ink, le tramage
ajoute du bruit. Le client officiel le désactive en boucle
(`enableDisableDithering:`, `startDisableDithering`, `disableDitheringTimer`,
`ditheringCheckAction while (true)`), car macOS restaure la valeur lors d'une
reconnexion, d'un réveil ou d'un changement de mode. Fermer la fenêtre du client
par sa croix quitte l'application, et plus rien ne maintenait le réglage.

| Moment | ProductID 9532 (DP) | ProductID 0 (HDMI) |
| --- | --- | --- |
| Client quitté, après redémarrage | `enableDither = Yes` | `enableDither = Yes` |
| Après `open -a PaperLikeClient` | `enableDither = No` | `enableDither = No` |

**Le POC est hors de cause dans les deux défauts** : au moment du signalement il
était en `state = waiting`, `lsof` ne montrait aucun détenteur du port, et son
contrôle `requireDisabled` l'empêchait précisément d'émettre.

### Mécanisme repris par l'agent

Les entitlements de `Stillcolor.app` donnent la clé exacte :

```
(allow iokit-set-properties (iokit-property "enableDither") (iokit-property "uniformity2D"))
```

La propriété écrite est **`enableDither`** ; la chaîne `disableDithering` visible
dans ce binaire n'est que le nom de sa fonction Swift interne. Écrire une clé
inconnue est refusé par le pilote avec `kIOReturnBadArgument` (`0xE00002C2`) —
erreur obtenue et levée pendant l'étude.

`IORegistryEntrySetCFProperty(service, "enableDither", kCFBooleanFalse)` sur les
services `IOMobileFramebufferAP` renvoie `kern_return = 0` depuis un binaire
ordinaire, **non sandboxé et sans entitlement** : Stillcolor n'a besoin de
l'exception `com.apple.security.temporary-exception.sbpl` que parce qu'il est
lui-même sandboxé. Le basculement a été vérifié par relecture dans les deux sens.

L'agent applique donc ce réglage lui-même à chaque tick de deux secondes, quel
que soit le mode de contrôle : l'écriture est une propriété IOKit sur le
framebuffer et ne touche jamais au port USB. Seules les sorties dont le
fabricant EDID est DASUNG (`0x1263`) sont écrites — la correspondance fabricant
est la condition positive d'écriture. La dalle interne est délibérément exclue :
y supprimer le tramage produit du banding.

Essai de bout en bout réalisé : `enableDither` forcé à `true` sur les deux
sorties, rétabli à `false` par l'agent en moins de deux secondes, `result = 0`,
compteur `ditheringReasserts` incrémenté de deux et `wasEnabled = true`
enregistré. La reprise après un cycle de veille système complet n'a pas été
observée ; le minuteur périodique la couvre par construction, sans preuve.

### Deux moniteurs DASUNG, pas un seul — comment les distinguer

**Erreur commise pendant cette étude, consignée ici pour qu'elle ne se répète
pas.** macOS expose deux connexions `Paperlike253`. Elles ont été prises pour un
seul écran branché deux fois, et « débrancher le câble HDMI » a été conseillé à
tort. L'utilisateur possède réellement **deux moniteurs DASUNG distincts** : un
Paperlike 253 noir et blanc et un Paperlike 253 Revo Color.

Le piège est que tout ce qui saute aux yeux est identique : même
`ProductName = "Paperlike253"`, même fabricant EDID `0x1263`, même définition
3200 × 1800. Les observations qui avaient servi à conclure (`SinkDeviceID`
`AG6320`, portID 16, historique `RTK FHD`/`Yealink` sur le même port) sont
exactes mais ne prouvent rien : elles décrivent un trajet par un dock, ce qui est
tout aussi vrai pour deux écrans que pour deux câbles.

Les vrais discriminants :

| Champ | Noir et blanc | Revo Color |
| --- | --- | --- |
| `ProductID` | `0` | `9532` (`0x253C`) |
| `SerialNumber` | `0` | `25312` |
| `YearOfManufacture` | 2020 | 2025 |
| `DFP Type` | 3 (`HDMI`) | 0 (`DP`) |
| `SupportsBT2020RGB` / `YCC` / `cYCC` | absents | présents |

Le numéro de série et l'année séparent les deux de façon fiable ; les champs
`SupportsBT2020*` ne sont présents que sur le modèle couleur. Ne jamais
identifier un écran DASUNG par son `ProductName`.

Conséquence pour le code : l'anti-tramage itère sur **toutes** les sorties dont
le fabricant EDID est `0x1263` et écrit chacune. Deux moniteurs sont donc
couverts sans traitement particulier, et la disparition de l'un n'affecte pas
l'autre — `withDasungFramebuffers` ne conserve aucun état entre deux appels.

Un seul adaptateur CH340 est présent (`/dev/cu.usbserial-2115410`) : un seul des
deux moniteurs a son câble USB de contrôle branché. `selectedDevice()` refuse
toute sélection ambiguë si un second apparaît.

### Écran noir : résolu par l'effacement

Symptôme distinct des deux précédents : le Revo Color n'affichait plus rien du
tout, ce que ni le tramage ni la table gamma n'expliquent — tous deux salissent
l'image sans l'effacer. Les registres relus à ce moment étaient contraste 1,
mode 2, vitesse 4, et le moniteur répondait normalement.

`paperlike refresh` (commande `0x03`) a suffi : acquittement `5FF5F003…` du
moniteur, image revenue. Il s'agissait donc d'un état interne du panneau, pas
d'un problème hôte. Une occurrence antérieure figurait dans les notes de
passation, récupérée en changeant le contraste — ce qui déclenche le même
redessin. Le geste à retenir pour un panneau resté noir est l'effacement, qui
exige `--control` et le lien CH340.

## Latence des réglages : l'attente venait de l'agent, pas du moniteur

Un raccourci mettait environ deux secondes à agir. Le moniteur n'y était pour
rien : `SerialPort.readFrames` ne sortait qu'à l'expiration du délai, **même
après avoir reçu la réponse attendue**. Chaque lecture coûtait donc son délai
entier de 0,6 s, et un réglage en enchaîne trois ou quatre (condition de la
lumière, valeur avant, attente de 0,25 s après l'écriture, relecture).

| Mesure | Avant | Après |
| --- | --- | --- |
| `paperlike read 07` | 0,63 s | 0,06 s |
| `paperlike query` (4 registres) | 2,47 s | 0,20 s |
| Écriture + relecture (`light-temp +1`) | ~1,5 s | 0,12 s |

Désormais une lecture rend la main dès que la réponse de son registre est
analysée ; le délai ne sert plus qu'en cas d'échec. Le moniteur **acquitte aussi
les écritures de réglage** par `5FF5F0<cmd>000000000000A0FA` (relevé :
`F008` pour la température, `F009` pour la luminosité) : cet accusé met fin à
l'attente, mais il n'est jamais pris pour une preuve — la relecture reste le
contrat de chaque écriture.

La limite qui refusait deux commandes à moins de 0,5 s d'intervalle
(« Commande trop rapprochée ») est remplacée par un espacement de 0,1 s qui
retarde au lieu de refuser. Côté raccourcis, les appuis rapprochés sur la même
touche relative sont fusionnés : cinq appuis sur ↑ pendant un échange donnent
une seule écriture de +40 après la première.

## Lumière frontale : allumer et éteindre

`paperlike light on|off|toggle` (raccourci ⌃⌥⌘L) écrit le registre `0x07`.
Les modes 1 à 3 restent non identifiés ; l'agent rétablit le dernier mode vu
non nul (3 a été observé), et 1 avant d'en avoir vu un. Ce mode est lu à la
connexion et conservé dans les préférences de l'agent (`lastLightMode`) : sans
cela, chaque réinstallation le ramenait à 1.

Le registre de luminosité `0x09` **se lit 0 tant que la lumière est éteinte**,
et retrouve sa valeur à l'allumage (relevé : 0 éteinte, 40 après
`light-mode 1`). Le moniteur la conserve donc. Une valeur réellement nulle
donnerait une lumière « allumée » sans effet sur la dalle, qui passerait pour
un raccourci en panne : dans ce seul cas, l'allumage la remonte à 20.

**Requête ignorée après un changement de mode.** Juste après l'accusé d'une
écriture de `0x07`, le moniteur **ignore** la lecture suivante : aucune réponse,
même tardive, alors que la même lecture 50 ms plus tard répond. C'est ce qui
faisait échouer le raccourci d'allumage une fois l'attente supprimée
(l'ancienne pause fixe de 0,25 s après chaque écriture le masquait). Une
requête est désormais renvoyée toutes les 0,2 s jusqu'à son délai de 0,6 s.

## Carte des commandes du moniteur

Relevée en désassemblant les méthodes `updateView…` du client : chaque libellé de
méthode précède immédiatement l'octet qu'elle envoie, sans inférence.

| Cmd | Méthode du client | Réglage | Bornes | Valeur d'origine |
| --- | --- | --- | --- | --- |
| `0x01` | `updateViewThresholdInfo:` | Contraste (« Contrast Level ») | 1–9 | 1 |
| `0x02` | `updateViewModeInfo:` | Mode : texte / image | 1–2 | 2 |
| `0x03` | `updateViewRefreshInfo:` | Ghost Cleanup | — | — |
| `0x04` | `updateViewSpeedInfo:` | Refresh Speed | 1–5 | 4 |
| `0x05` | `updateRealTimeClockInfo` | **Horloge temps réel** — non exposée | — | pas de réponse |
| `0x07` | `updateViewFrontModeInfo:` | Lumière frontale : mode | 0–3 | 0 |
| `0x08` | `updateViewFrontTemperatureValueInfo:` | Lumière frontale : température | 0–100 | 70 |
| `0x09` | `updateViewFrontBrightnessValueInfo:` | Lumière frontale : luminosité | 0–100 | 0 |
| `0x0A` | `requestUpdateViewInfo:` | préfixe de lecture | — | — |
| `0x10` | — | MCU | — | 48 (`0x30`) |
| `0x12` | `updateTextEnhancementInfo:` | Text Enhancement | 0–1 | 1 |
| `0x13` | — | **non identifié** — non exposé | — | 5 |
| `0x20` | `updateDitheringInfo:` | état du tramage | — | pas de réponse |

`0x05` et `0x13` ne sont pas exposés en écriture : le premier est une horloge,
le second reste inconnu. Un test l'impose (`testEverySettingIsUniquelyNamedAndCommanded`).

**Dépendance découverte :** `0x09` (luminosité frontale) est silencieusement
ignoré tant que `0x07` vaut 0. Le moniteur conserve alors l'ancienne valeur sans
rien signaler — d'où la relecture obligatoire après chaque écriture, et la
déclaration explicite de cette dépendance dans `Setting.requires`, pour rendre un
message utile plutôt qu'une erreur de bornes trompeuse.

Bornes établies par écriture puis relecture : le moniteur borne lui-même, donc
une valeur refusée se manifeste par une relecture divergente et la commande
échoue au lieu de prétendre avoir abouti. L'état d'origine ci-dessus a été
restauré après les essais.

## Matériel et client examinés

- macOS 26.6.2, Apple M1 Max.
- L’écran physique se présente à macOS comme `Paperlike253`, EDID fabricant
  `0x1263`, produit `0x0000`, 3200 × 1800, mode observé à 40 Hz. Le « 153 »
  mentionné initialement ne correspond pas au nom détecté.
- Le client officiel affiche `PaperLike253(Color) [FrontLight]`.
- La liaison de contrôle expose `/dev/cu.usbserial-2115410`, CH340
  `1a86:7523`. Le chemin est détecté dynamiquement, jamais codé en dur.
- La seconde sortie DASUNG, produit `0x253C` (9532), est un **second moniteur
  physique** : le Revo Color, à côté du Paperlike 253 noir et blanc en produit
  `0`. Voir « Deux moniteurs DASUNG » ci-dessus pour les champs qui les
  distinguent.
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

Dans le client Mac V2.0.3, `updateDitheringInfo:` envoie la commande `0x20` avec
l’état de désactivation du dithering, depuis `tryToDisableDithering`. Ce message
n’est donc pas un simple keepalive indépendant de l’état graphique du Mac : il
annonce au moniteur ce que l’hôte fait du tramage. C’est pourquoi
`requireDisabled` reste une **précondition sur le chemin série**, relue à chaque
cycle, et non une simple conséquence de l’écriture faite par l’agent : si macOS
remet `enableDither` à `Yes` entre l’écriture et l’émission, la trame `0x20/1`
est omise pour ce cycle plutôt qu’envoyée à tort.

BetterDisplay a été écarté comme cause : `systemVirtual@Display:*` et
`thirdPartyVirtual@Display:*` valent tous `0` (aucun écran virtuel) et
`intelEDIDOverride@v4707m0` vaut `0` (aucun override EDID actif sur le DASUNG).

## Validation réalisée

- Compilation native et signature ad hoc de l’application.
- Tests du protocole, bruit et fragmentation USB, filtrage des réponses,
  bornes de commandes, refus de sélection ambiguë et échange par pseudo-terminal.
- Installation réelle du LaunchAgent. macOS indique `running` et l’entrée de
  démarrage est `enabled, allowed` dans `sfltool dumpbtm`.
- `NSRunningApplication` indique `activationPolicy = 2` (prohibited),
  `active = false`, et CoreGraphics compte **zéro fenêtre** du processus.
  Depuis le HUD, une fenêtre non activante est visible 1,6 s après chaque
  raccourci, puis aucune ; pendant l'affichage, `paperlike status` relève
  `takesFocus: false` et `visibleWindowCount: 1`, puis `0` deux secondes après.
  Capture faite : le HUD s'affiche en haut à droite de l'écran sous le pointeur.
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
