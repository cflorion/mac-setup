# mac-setup

Automated configuration of my Mac: installs apps, applies my macOS
settings, and symlinks all my config files (dotfiles) — so a fresh Mac is
ready in one command.

---

## 🚀 Install on a fresh Mac

A single line to paste in Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cflorion/mac-setup/main/bootstrap.sh)"
```

It installs the Command Line Tools + Homebrew, clones this repo into
`~/code/mac-setup`, then runs `make install` (everything else).

> Some settings require a manual step: they are printed in the terminal
> with the `⚠️  Manual step:` marker.

---

## 🛠️ Commands (`make`)

### Daily
| Command | Effect |
|---|---|
| `make update` | Fast update: Homebrew, Node, dotfiles, macOS settings |
| `make backup` | Back up SSH keys before reformatting |
| `make restore-ssh` | Restore SSH keys from the latest backup |

### Full install
| Command | Effect |
|---|---|
| `make install` | Install everything (fresh machine) — runs all the blocks below |

### Block by block (useful to re-run a single part)
| Command | Effect |
|---|---|
| `make brew` | Install the apps listed in `Brewfile` |
| `make fuji-webcam` | Install FUJIFILM X Webcam from the bundled `.pkg` (needs sudo) |
| `make mas` | Install Mac App Store apps |
| `make node` | Install Node.js LTS (via fnm) |
| `make npm-global` | Install global packages (via pnpm) |
| `make link` | Symlink dotfiles into `~` and `~/.config/` |
| `make macos` | Apply all macOS settings |
| `make macos-<module>` | Apply a single setting (see the list below) |
| `make raycast` | Configure Raycast (frees Cmd+Space, imports the config) |
| `make sketchybar` | Build and start the SketchyBar menu bar |
| `make obsidian` | Copy the Obsidian theme and plugins into the vault |
| `make pwa` | Recreate the Chrome PWA shortcuts (e.g. Google Chat) |
| `make ollama` | Pull the Ollama models |

`make macos-<module>` modules:
`finder` · `dock` · `keyboard` · `trackpad` · `mission-control` · `desktop` ·
`control-center` · `pointer`

---

## 📂 Layout

```
mac-setup/
├── Makefile              # Entry point: all the commands above
├── bootstrap.sh          # First-install script (run via curl)
├── Brewfile              # Homebrew apps (formulae + casks)
├── installers/           # Vendor .pkg files with no Homebrew cask (Fuji X Webcam)
│
├── apps-mas.sh           # Mac App Store apps (via `mas`)
├── macos-defaults.sh     # Runs every module in macos/
├── raycast.sh            # Raycast config
├── pwa.sh                # Recreates Chrome PWAs
├── backup.sh             # SSH key backup
├── restore-ssh.sh        # SSH key restore
│
├── macos/                # macOS settings, one file per domain
│   ├── finder.sh         # Finder
│   ├── dock.sh           # Dock + hot corners
│   ├── keyboard.sh       # Keyboard (key repeat, accents…)
│   ├── trackpad.sh       # Trackpad
│   ├── mission-control.sh
│   ├── desktop.sh        # Desktop
│   ├── control-center.sh # Control Center / menu bar
│   └── pointer.sh        # Pointer + accessibility
│
├── dotfiles/             # Configs symlinked by `make link`
│   ├── .zshrc            # → ~/            (dotfiles into the home dir)
│   ├── .gitconfig        # → ~/
│   ├── .finicky.js       # → ~/            (link router to browsers)
│   ├── nvim/             # → ~/.config/nvim/    (Neovim / LazyVim)
│   ├── wezterm/          # → ~/.config/wezterm/ (terminal)
│   ├── aerospace/        # → ~/.config/aerospace/ (window manager)
│   ├── sketchybar/       # → ~/.config/sketchybar/ (menu bar, in Lua)
│   ├── karabiner/        # → ~/.config/karabiner/ (key remaps, e.g. Hyper)
│   ├── atuin/ lazygit/ zed/ starship.toml …
│   ├── bin/              # → ~/.local/bin/  (scripts: commit, pr, aerospace-*…)
│   ├── raycast/          # Raycast config export (*.rayconfig)
│   ├── obsidian/         # Theme + plugins (copied, not symlinked)
│   └── sublime-text/     # → ~/Library/.../Sublime Text/
│
├── launchd/              # LaunchAgents (e.g. reload SketchyBar on theme change)
├── documents/            # Templates (e.g. Typst) copied into ~/templates/
├── wallpapers/           # Wallpapers
│
├── shortcuts.md          # All my keyboard shortcuts (AeroSpace, Raycast, WezTerm…)
└── CLAUDE.md             # Notes for the AI assistant working on this repo
```

> The `backup/` folder (SSH keys) is gitignored.

---

## 📖 Going further

- **[shortcuts.md](shortcuts.md)** — the full list of my keyboard shortcuts.
- **[CLAUDE.md](CLAUDE.md)** — detailed architecture and repo conventions.
