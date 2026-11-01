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
| `make flashspace` | Start FlashSpace app workspaces and stop AeroSpace |
| `make sketchybar` | Build and enable the optional SketchyBar menu bar |
| `make disable-sketchybar` | Stop SketchyBar and its theme watcher without removing their config |
| `make obsidian` | Copy the Obsidian theme and plugins into the vault |
| `make pwa` | Recreate the Chrome PWA shortcuts (e.g. Google Chat) |
| `make pwa-helium` | Create Helium app-window wrappers (links open in Helium) |
| `make ollama` | Pull the Ollama models |

`make macos-<module>` modules:
`finder` · `dock` · `keyboard` · `trackpad` · `mission-control` · `desktop` ·
`control-center` · `pointer`

SketchyBar remains installed and configured, but `make install` and `make update`
leave it disabled by default. Run `make sketchybar` if you want it back.

### FlashSpace app workspaces

FlashSpace replaces AeroSpace with virtual app workspaces defined entirely in
`dotfiles/flashspace/`. It stays inside one native macOS Space: Hyper+letter
hides the previous application, opens or reveals the selected one, and leaves
exactly that application visible. WhatsApp (`D`) and Messages (`H`) are separate
because FlashSpace manages complete applications rather than individual windows.

FlashSpace deliberately does not resize windows. After every workspace switch,
`flashspace-maximize` uses macOS Accessibility to fill the focused window without
tiling and without using macOS native fullscreen. skhd only owns the remaining
non-workspace commands (Yazi and the Raycast GitHub deeplinks). Yazi is focused
through macOS Accessibility, so the setup has no Yabai dependency. SIP remains on.

On first install, run `make flashspace`, then enable FlashSpace and skhd
in **System Settings → Privacy & Security → Accessibility**. Re-run
`make flashspace` afterwards. The only manual operation is macOS security consent;
workspaces, apps, shortcuts, startup and window sizing all come from this repo.
The old AeroSpace configuration remains available as a rollback option, with
automatic startup disabled.

The DASUNG Paperlike agent lives in its own repository,
[cflorion/ditherbuster](https://github.com/cflorion/ditherbuster), cloned in
`~/code/ditherbuster` and installed from there (`make install-control`).
The general install/update targets do not enable it. See its documentation
for hardware evidence and returning to the official client.

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
├── pwa-helium.sh         # Creates Helium app-window wrappers
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
│   ├── .gitconfig        # included by ~/.gitconfig
│   ├── .finicky.js       # → ~/            (link router to browsers)
│   ├── nvim/             # → ~/.config/nvim/    (Neovim / LazyVim)
│   ├── wezterm/          # → ~/.config/wezterm/ (terminal)
│   ├── flashspace/       # → ~/.config/flashspace/ (app workspaces)
│   ├── skhd/             # → ~/.config/skhd/ (auxiliary hotkeys)
│   ├── aerospace/        # → ~/.config/aerospace/ (disabled rollback config)
│   ├── sketchybar/       # → ~/.config/sketchybar/ (menu bar, in Lua)
│   ├── karabiner/        # → ~/.config/karabiner/ (key remaps, e.g. Hyper)
│   ├── atuin/ lazygit/ zed/ starship.toml …
│   ├── bin/              # → ~/.local/bin/  (scripts: commit, pr, FlashSpace helpers…)
│   ├── raycast/          # Raycast config export (*.rayconfig)
│   ├── obsidian/         # Theme + plugins (copied, not symlinked)
│   └── sublime-text/     # → ~/Library/.../Sublime Text/
│
├── launchd/              # LaunchAgents (e.g. reload SketchyBar on theme change, daily trackers in Safari)
├── documents/            # Templates (e.g. Typst) copied into ~/templates/
├── wallpapers/           # Wallpapers
│
├── shortcuts.md          # All my keyboard shortcuts (FlashSpace, Raycast, WezTerm…)
└── CLAUDE.md             # Notes for the AI assistant working on this repo
```

> The `backup/` folder (SSH keys) is gitignored.

---

## 📖 Going further

- **[shortcuts.md](shortcuts.md)** — the full list of my keyboard shortcuts.
- **[CLAUDE.md](CLAUDE.md)** — detailed architecture and repo conventions.
