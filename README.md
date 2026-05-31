# mac-setup

Configuration automatisée de mon Mac : installe les apps, applique mes réglages
macOS, et lie tous mes fichiers de config (dotfiles) — pour repartir d'un Mac
neuf en une commande.

---

## 🚀 Installation sur un Mac neuf

Une seule ligne à coller dans le Terminal :

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cflorion/mac-setup/main/bootstrap.sh)"
```

Elle installe les Command Line Tools + Homebrew, clone ce repo dans
`~/code/mac-setup`, puis lance `make install` (tout le reste).

> Certains réglages demandent une étape manuelle : elles s'affichent dans le
> terminal avec le marqueur `⚠️  Manual step:`.

---

## 🛠️ Commandes (`make`)

### Au quotidien
| Commande | Effet |
|---|---|
| `make update` | Mise à jour rapide : Homebrew, Node, dotfiles, réglages macOS |
| `make backup` | Sauvegarde les clés SSH avant de formater |
| `make restore-ssh` | Restaure les clés SSH depuis la dernière sauvegarde |

### Installation complète
| Commande | Effet |
|---|---|
| `make install` | Tout installer (machine neuve) — enchaîne tous les blocs ci-dessous |

### Bloc par bloc (utile pour rejouer une seule partie)
| Commande | Effet |
|---|---|
| `make brew` | Installe les apps listées dans le `Brewfile` |
| `make mas` | Installe les apps du Mac App Store |
| `make node` | Installe Node.js LTS (via fnm) |
| `make npm-global` | Installe les paquets globaux (via pnpm) |
| `make link` | Crée les symlinks des dotfiles vers `~` et `~/.config/` |
| `make macos` | Applique tous les réglages macOS |
| `make macos-<module>` | Applique un seul réglage (voir la liste plus bas) |
| `make raycast` | Configure Raycast (libère Cmd+Espace, importe la config) |
| `make sketchybar` | Compile et démarre la barre de menu SketchyBar |
| `make obsidian` | Copie le thème et les plugins Obsidian dans le coffre |
| `make pwa` | Recrée les raccourcis des PWA Chrome (ex. Google Chat) |
| `make ollama` | Télécharge les modèles Ollama |

Modules `make macos-<module>` :
`finder` · `dock` · `keyboard` · `trackpad` · `mission-control` · `desktop` ·
`control-center` · `pointer`

---

## 📂 Arborescence

```
mac-setup/
├── Makefile              # Point d'entrée : toutes les commandes ci-dessus
├── bootstrap.sh          # Script de 1ʳᵉ install (lancé via curl)
├── Brewfile              # Liste des apps Homebrew (formules + casks)
│
├── apps-mas.sh           # Apps Mac App Store (via `mas`)
├── macos-defaults.sh     # Lance tous les modules de macos/
├── raycast.sh            # Config Raycast
├── pwa.sh                # Recrée les PWA Chrome
├── backup.sh             # Sauvegarde des clés SSH
├── restore-ssh.sh        # Restauration des clés SSH
│
├── macos/                # Réglages macOS, un fichier par domaine
│   ├── finder.sh         # Finder
│   ├── dock.sh           # Dock + coins actifs
│   ├── keyboard.sh       # Clavier (répétition, accents…)
│   ├── trackpad.sh       # Trackpad
│   ├── mission-control.sh
│   ├── desktop.sh        # Bureau
│   ├── control-center.sh # Centre de contrôle / barre de menu
│   └── pointer.sh        # Curseur + accessibilité
│
├── dotfiles/             # Configs liées par symlink (`make link`)
│   ├── .zshrc            # → ~/            (fichiers cachés vers la maison)
│   ├── .gitconfig        # → ~/
│   ├── .finicky.js       # → ~/            (routeur de liens vers navigateurs)
│   ├── nvim/             # → ~/.config/nvim/    (Neovim / LazyVim)
│   ├── wezterm/          # → ~/.config/wezterm/ (terminal)
│   ├── aerospace/        # → ~/.config/aerospace/ (gestionnaire de fenêtres)
│   ├── sketchybar/       # → ~/.config/sketchybar/ (barre de menu, en Lua)
│   ├── karabiner/        # → ~/.config/karabiner/ (remaps clavier, ex. Hyper)
│   ├── atuin/ lazygit/ zed/ starship.toml …
│   ├── bin/              # → ~/.local/bin/  (scripts perso : commit, pr…)
│   ├── raycast/          # Export de config Raycast (*.rayconfig)
│   ├── obsidian/         # Thème + plugins (copiés, pas symlinkés)
│   └── sublime-text/     # → ~/Library/.../Sublime Text/
│
├── launchd/              # LaunchAgents (ex. recharger SketchyBar au thème système)
├── documents/            # Modèles (ex. Typst) copiés dans ~/templates/
├── wallpapers/           # Fonds d'écran
│
├── shortcuts.md          # Tous mes raccourcis clavier (AeroSpace, Raycast, WezTerm…)
└── CLAUDE.md             # Notes pour l'assistant IA travaillant sur ce repo
```

> Le dossier `backup/` (clés SSH) est ignoré par git.

---

## 📖 Pour aller plus loin

- **[shortcuts.md](shortcuts.md)** — la liste complète de mes raccourcis clavier.
- **[CLAUDE.md](CLAUDE.md)** — l'architecture détaillée et les conventions du repo.
