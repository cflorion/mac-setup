# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What This Is

A macOS setup automation repo (cflorion/mac-setup) that configures a fresh Mac from scratch: installs apps via Homebrew/MAS, symlinks dotfiles, applies macOS defaults, and sets up development tools.
When the user ask changes, the goal is to update this macOs setup repo.

## Key Commands

- `make install` — Full setup for a new machine (brew, node, npm-global, link, disabled SketchyBar, obsidian, macos, raycast, mas, ollama, pwa-helium)
- `make update` — Fast daily update (brew, node, link, macos, disabled SketchyBar)
- `make backup` — Backup SSH keys before formatting
- `make restore-ssh` — Restore SSH keys from most recent backup
- `make link` — Symlink dotfiles only
- `make brew` — Install Homebrew packages only
- `make macos` — Apply all macOS defaults
- `make fuji-webcam` — Install FUJIFILM X Webcam from the bundled `.pkg` (no Homebrew cask exists; needs sudo, restart after)
- `make sketchybar` — Build and enable the optional SketchyBar setup
- `make disable-sketchybar` — Stop SketchyBar and its theme watcher without deleting their configuration
- `make uhk-backup` — Snapshot the live UHK Agent user-config into `dotfiles/uhk/uhk-config.json` (commit the diff afterwards)
- `make macos-<module>` — Apply a single module (finder, dock, keyboard, trackpad, mission-control, desktop, control-center, pointer, e-ink)
- `make macos-e-ink` — Apply e-ink display optimizations (font smoothing off, reduce transparency, increase contrast)
- Bootstrap on a fresh Mac: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cflorion/mac-setup/main/bootstrap.sh)"`

## Architecture

- **Makefile** — Orchestrates everything. `make install` is the entry point; individual targets can run independently.
- **Brewfile** — Declarative list of brew formulae, casks, and taps.
- **bootstrap.sh** — Curl-runnable first-time script: installs Xcode CLT, Homebrew, clones repo, runs `make install`.
- **macos-defaults.sh** — Runner that sources all modules from `macos/`. Some settings require manual steps (logged to stdout).
- **macos/** — Individual `defaults write` modules: `finder.sh`, `dock.sh`, `keyboard.sh`, `trackpad.sh`, `mission-control.sh`, `desktop.sh`, `control-center.sh`, `pointer.sh`.
- **raycast.sh** — Disables Spotlight shortcuts (freeing Cmd+Space for Raycast), opens extension install URLs, imports the newest Raycast `*.rayconfig` export.
- **apps-mas.sh** — Mac App Store installs via `mas`.
- **installers/** — Vendor `.pkg` installers with no Homebrew cask (e.g. `XWebcamIns220.pkg` for FUJIFILM X Webcam). Installed by the `fuji-webcam` Makefile target via `sudo installer -pkg … -target /`, guarded so it skips when the app already exists.
- **pwa-helium.sh** — Recreates *native* Helium PWA `.app` shortcuts (Google Chat, Google Meet) in `~/Applications/Chromium Apps.localized/` by launching `Helium --app-id=<id>` (same trick as Chrome's `--app-id`, which regenerates the shortcut on disk). Used for Google web apps: they open external links via their parent browser process, bypassing the default browser, so Finicky can't route those clicks — running them *inside* Helium makes their links open in Helium. Each PWA must be installed once via Helium's ⋮ menu > "Install app…" (registers it in the Helium profile); the script regenerates it on re-runs. Installed by `make pwa-helium`. Note: the very first launch after regeneration triggers a Helium "rebuild" cycle that may not open a window — just launch it again.
- **launchd/** — LaunchAgent templates (`__HOME__` placeholder is substituted at install time). `com.user.sketchybar-theme.plist` runs `dark-notify` to reload sketchybar on light/dark switch when the optional bar is enabled by `make sketchybar`.
- **dotfiles/** — Symlinked into `~` and `~/.config/` by `make link`:
  - Hidden files (`.zshrc`, `.gitconfig`, `.gitignore_global`, `.finicky.js`) → `~/`
  - Directories (`nvim/`, `lazygit/`, `sketchybar/`, `atuin/`, `wezterm/`, `karabiner/`, `aerospace/`, `raycast/`) → `~/.config/<name>/`
  - `bin/` → `~/.local/bin/` (custom scripts: `commit`, `pr`, `popina-pdf`, `aerospace-focus-or-open`, `aerospace-workspace-cycle`, `notes-scratch`, `Codex`)
    - `notes-scratch` — Hyper+N scratch pad (Antinote replacement): focuses, or opens, a dedicated Apple Notes window named `Brouillon`, floated by the `com.apple.Notes` rule in `aerospace.toml`, so the note syncs to the iPhone through iCloud. Two non-obvious constraints: Apple Notes derives a note's name — and therefore the window title the script matches on — from the note's **first line**, and the Window ▸ "Open Note in New Window" menu item is a silent no-op unless Notes was activated with `open "notes://"` first (`activate` is not enough).
  - `starship.toml` → `~/.config/starship.toml`
  - `zed/settings.json` → `~/.config/zed/settings.json` (only settings, not full dir)
  - `sublime-text/` → `~/Library/Application Support/Sublime Text/Packages/User/`
  - `obsidian/` → copied (not symlinked) to iCloud vault to avoid sync issues
  - `uhk/uhk-config.json` → **not** symlinked: the Ultimate Hacking Keyboard user-config export, re-imported manually via UHK Agent (like the Raycast export). See `dotfiles/uhk/README.md`.
- **documents/** — Templates (e.g. Typst) copied to `~/templates/` by `make link`.

## Conventions

- All shell scripts use `set -euo pipefail`.
- Manual steps that can't be automated are echoed to stdout as reminders.
- The repo lives at `~/code/mac-setup`.
- Backup directory (`backup/`) is gitignored and contains SSH key snapshots.
- Sketchybar is disabled by default, but its Lua config is preserved. It has C event providers (`helpers/event_providers/`) that compile via `make` — run `make sketchybar` to rebuild and re-enable it after changes.
- macOS defaults modules are sourced (not executed) by `macos-defaults.sh`, so they don't need their own shebang or `set -euo pipefail`.
- The `npm-global` target installs global packages via **pnpm** (`PNPM_HOME=~/Library/pnpm`), despite its name.
- The Raycast config file (`dotfiles/raycast/*.rayconfig`) is a binary export — update it by re-exporting from Raycast, not by hand-editing. `dotfiles/raycast/extensions/` is gitignored: Raycast rewrites it via the `~/.config/raycast` symlink and it is not config.
