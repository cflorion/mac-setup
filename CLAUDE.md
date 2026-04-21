# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS setup automation repo (cflorion/mac-setup) that configures a fresh Mac from scratch: installs apps via Homebrew/MAS, symlinks dotfiles, applies macOS defaults, and sets up development tools.
When the user ask changes, the goal is to update this macOs setup repo.

## Key Commands

- `make install` — Full setup for a new machine (brew, node, npm-global, link, sketchybar, obsidian, macos, raycast, mas, ollama)
- `make update` — Fast daily update (brew, node, link, macos)
- `make backup` — Backup SSH keys before formatting
- `make restore-ssh` — Restore SSH keys from most recent backup
- `make link` — Symlink dotfiles only
- `make brew` — Install Homebrew packages only
- `make macos` — Apply all macOS defaults
- `make macos-<module>` — Apply a single module (finder, dock, keyboard, trackpad, mission-control, desktop, control-center, pointer)
- Bootstrap on a fresh Mac: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cflorion/mac-setup/main/bootstrap.sh)"`

## Architecture

- **Makefile** — Orchestrates everything. `make install` is the entry point; individual targets can run independently.
- **Brewfile** — Declarative list of brew formulae, casks, and taps.
- **bootstrap.sh** — Curl-runnable first-time script: installs Xcode CLT, Homebrew, clones repo, runs `make install`.
- **macos-defaults.sh** — Runner that sources all modules from `macos/`. Some settings require manual steps (logged to stdout).
- **macos/** — Individual `defaults write` modules: `finder.sh`, `dock.sh`, `keyboard.sh`, `trackpad.sh`, `mission-control.sh`, `desktop.sh`, `control-center.sh`, `pointer.sh`.
- **raycast.sh** — Disables Spotlight shortcuts (freeing Cmd+Space for Raycast), opens extension install URLs, imports Raycast config.
- **apps-mas.sh** — Mac App Store installs via `mas`.
- **dotfiles/** — Symlinked into `~` and `~/.config/` by `make link`:
  - Hidden files (`.zshrc`, `.gitconfig`, `.gitignore_global`) → `~/`
  - Directories (`nvim/`, `lazygit/`, `sketchybar/`, `atuin/`, `wezterm/`, `karabiner/`, `aerospace/`, `borders/`) → `~/.config/<name>/`
  - `bin/` → `~/.local/bin/` (custom scripts: `commit`, `pr`, `popina-pdf`)
  - `starship.toml` → `~/.config/starship.toml`
  - `zed/settings.json` → `~/.config/zed/settings.json` (only settings, not full dir)
  - `sublime-text/` → `~/Library/Application Support/Sublime Text/Packages/User/`
  - `obsidian/` → copied (not symlinked) to iCloud vault to avoid sync issues
- **documents/** — Templates (e.g. Typst) copied to `~/templates/` by `make link`.

## Conventions

- All shell scripts use `set -euo pipefail`.
- Manual steps that can't be automated are echoed to stdout as reminders.
- The repo lives at `~/code/mac-setup`.
- Backup directory (`backup/`) is gitignored and contains SSH key snapshots.
- Sketchybar config is Lua-based (not shell). It has C event providers (`helpers/event_providers/`) that compile via `make` — run `make sketchybar` to rebuild after changes.
- macOS defaults modules are sourced (not executed) by `macos-defaults.sh`, so they don't need their own shebang or `set -euo pipefail`.
- The Raycast config file (`dotfiles/raycast/*.rayconfig`) is a binary export — update it by re-exporting from Raycast, not by hand-editing.
