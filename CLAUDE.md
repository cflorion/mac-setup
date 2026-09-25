# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **raycast.sh** — Disables Spotlight shortcuts (freeing Cmd+Space for Raycast), opens extension install URLs, imports the newest Raycast `*.rayconfig` export. Raycast commands bound to keys are **not** in that export: they are AeroSpace bindings in `aerospace.toml` running `open raycast://extensions/…` deeplinks (Meh+I → GitHub *My Issues*; Meh+N → GitHub *Search Issues* prefilled via `fallbackText` with `cflorion/chezion#81`, the "NEXT" issue, which that command resolves to the single issue). Raycast shows "Request to run …" the first time a command is triggered from outside Raycast: answer *Always Run Command* once per command.
- **apps-mas.sh** — Mac App Store installs via `mas`.
- **installers/** — Vendor `.pkg` installers with no Homebrew cask (e.g. `XWebcamIns220.pkg` for FUJIFILM X Webcam). Installed by the `fuji-webcam` Makefile target via `sudo installer -pkg … -target /`, guarded so it skips when the app already exists.
- **pwa-helium.sh** — Recreates *native* Helium PWA `.app` shortcuts (Google Chat, Google Meet) in `~/Applications/Chromium Apps.localized/` by launching `Helium --app-id=<id>` (same trick as Chrome's `--app-id`, which regenerates the shortcut on disk). Used for Google web apps: they open external links via their parent browser process, bypassing the default browser, so Finicky can't route those clicks — running them *inside* Helium makes their links open in Helium. Each PWA must be installed once via Helium's ⋮ menu > "Install app…" (registers it in the Helium profile); the script regenerates it on re-runs. Installed by `make pwa-helium`. Note: the very first launch after regeneration triggers a Helium "rebuild" cycle that may not open a window — just launch it again.
- **Ditherbuster** — the DASUNG Paperlike agent (anti-dithering, USB control, `ditherbuster`/`dbust` CLI) moved to its own repo, `cflorion/ditherbuster`, cloned at `~/code/ditherbuster`; develop and install it there, not here. Only its AeroSpace float rule (`io.github.cflorion.ditherbuster`) stays in this repo.
- **launchd/** — LaunchAgent templates (`__HOME__` placeholder is substituted at install time). `com.user.sketchybar-theme.plist` runs `dark-notify` to reload sketchybar on light/dark switch when the optional bar is enabled by `make sketchybar`.
- **dotfiles/** — Symlinked into `~` and `~/.config/` by `make link`:
  - Hidden files (`.zshrc`, `.gitconfig`, `.gitignore_global`, `.finicky.js`) → `~/`
    - `.finicky.js` — Finicky is the system default browser and sends every link to Safari; holding **Shift** while clicking a link in another app sends it to Helium instead (`finicky.getModifierKeys()`, listed first so it also beats the Linear rule). Not ⌘ (Zed and VS Code open links on ⌘-click), ⌥ (⌥-click marks a Slack message unread) or ⌃ (⌃-click is a right-click, and Hyper and Meh both hold ⌃). The key is read when the URL arrives, so the rule relies on Finicky staying resident (`keepRunning`, true by default, set explicitly). Links clicked inside Safari never reach Finicky. In WezTerm, Shift+click is also a selection gesture (it extends the selection), so it is not a reliable way to send a terminal link to Helium.
  - Directories (`nvim/`, `lazygit/`, `sketchybar/`, `atuin/`, `wezterm/`, `karabiner/`, `aerospace/`, `raycast/`) → `~/.config/<name>/`
  - `bin/` → `~/.local/bin/` (custom scripts: `commit`, `pr`, `popina-pdf`, `aerospace-focus-or-open`, `aerospace-workspace-cycle`, `notes-scratch`). Because `~/.local/bin` *is* this directory, installers that write there land in the repo: Claude Code's native installer keeps `claude` here as a symlink to `~/.local/share/claude/versions/<version>` and rewrites it on every auto-update, so it is gitignored.
    - `notes-scratch` — Hyper+N toggles Apple Notes (Antinote replacement): brings the main Notes window, on the `Brouillon` note (created on first run), over the current workspace — floated by the `com.apple.Notes` rule in `aerospace.toml` — so the scratch note syncs to the iPhone through iCloud; pressed while Notes is focused, it hides Notes by parking its windows on the off-bar `Notes` workspace (kept out of `spaces.lua`, like `OBS`). Every time the window is shown it is also pinned to a fixed size (`NOTES_SCRATCH_WIDTH`/`HEIGHT`, default 904×761) and centered on the display it lands on, because Apple Notes has no persistent window-size setting and a freshly launched window opens at its own small default. The resize is split across two engines: JXA (`NSScreen`) computes the centered origin — the only way to reach AppKit's screen geometry — but JXA's own `bounds` setter on a Notes window is a silent no-op, so classic AppleScript's `set bounds of window` applies it. Two other non-obvious constraints: it parks instead of ⌘H-hiding because AeroSpace turns a hidden app's window into a tiling one when it moves to another workspace (a manual ⌘H is handled by unhiding Notes first — `NSRunningApplication.unhide` does not front it); and Apple Notes derives a note's name from its **first line**, so `Brouillon` must stay on line 1.
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
