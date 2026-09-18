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
- **raycast.sh** — Disables Spotlight shortcuts (freeing Cmd+Space for Raycast), opens extension install URLs, imports the newest Raycast `*.rayconfig` export.
- **apps-mas.sh** — Mac App Store installs via `mas`.
- **installers/** — Vendor `.pkg` installers with no Homebrew cask (e.g. `XWebcamIns220.pkg` for FUJIFILM X Webcam). Installed by the `fuji-webcam` Makefile target via `sudo installer -pkg … -target /`, guarded so it skips when the app already exists.
- **pwa-helium.sh** — Recreates *native* Helium PWA `.app` shortcuts (Google Chat, Google Meet) in `~/Applications/Chromium Apps.localized/` by launching `Helium --app-id=<id>` (same trick as Chrome's `--app-id`, which regenerates the shortcut on disk). Used for Google web apps: they open external links via their parent browser process, bypassing the default browser, so Finicky can't route those clicks — running them *inside* Helium makes their links open in Helium. Each PWA must be installed once via Helium's ⋮ menu > "Install app…" (registers it in the Helium profile); the script regenerates it on re-runs. Installed by `make pwa-helium`. Note: the very first launch after regeneration triggers a Helium "rebuild" cycle that may not open a window — just launch it again.
- **apps/paperlike-agent/** — Swift agent for the DASUNG Paperlike 253 and 13K. Its main job is clearing `enableDither` on the Paperlike framebuffers (`IOMobileFramebufferAP`, DASUNG EDID `0x1263`, or the 13K's Realtek scaler EDID `RTK FHD` `0x4A8B`/447, matched on vendor *and* product — never the built-in panel, where removing dithering causes banding). macOS restores the property on reconnect, wake and mode change, so the agent re-applies it on `CGDisplayRegisterReconfigurationCallback` (plus a short bounded burst) and every 2 s as a fallback; this is why closing PaperLikeClient brings the artifacts back. Runs on `make paperlike`. USB serial control is a separate opt-in via `make paperlike-control`, not needed for the anti-dithering: it exposes every setting the vendor client drives (contrast, mode, speed, front-light mode/brightness/temperature, text enhancement, ghost cleanup), each write confirmed by register read-back, with signed values acting relatively (`paperlike light +10`). Command bytes were mapped from the client's `updateView…` methods — see RESEARCH.md; `0x05` (real-time clock) and `0x13` (the model id — the client's table: 1 13K Color, 2 13K, 3 103, 4 253, 5 253 Color) are deliberately never writable, enforced by a test. The light mode is a temperature preset: writing a temperature switches it to mode 3. Global hotkeys use Control+Option+Command (⌃⌥⌘L toggles the front light; brightness acts as one level where 0 is off, so ↑ from off lights it at 10 % and ↓ to 0 really switches it off — `FrontLight.step`) and are optionally redefined in `~/.config/paperlike/config.json`, read once at startup; a missing or broken config falls back to defaults and never blocks startup. ⌃⌥⌘M (the AZERTY M key, bound as `semicolon` since key names are ANSI positions) cycles the display modes (`paperlike mode next`; four, three on the black-and-white 253, which refuses web; the 13K reads web back as 1, not the 6 written — `DisplayMode.readBack`); register `0x02` values differ per model, so modes are chosen by name from `DisplayMode.modes(of:)`, never by number. ⌃⌥⌘C (`paperlike clear`) is the one action with no USB: the agent flashes the Paperlike display under the pointer black then white itself, so it also clears a Paperlike plugged in by HDMI alone, and it is the only hotkey registered without `--control`; `Action.frame` is nil for it so it can never reach the serial port. Each shortcut's result shows in a small HUD drawn for e-ink (opaque, no shadow, no animation), a non-activating `NSPanel` that never takes focus; `"hud": false` in the config disables it, and the HUD formatting lives in `PaperlikeCore` so it is tested. Serial reads return as soon as the awaited reply is parsed — the timeout is the failure path only; waiting it out used to cost ~2 s per shortcut. Every Paperlike output, and every CH340 that answers a supported MCU, is handled independently — one USB link per monitor. `0x13` pairs a link with its screen (13K models ↔ Realtek EDID, 253 Color ↔ DASUNG product `0x253C`, the other models ↔ other DASUNG products; USB topology can't), and commands and shortcuts act on the Paperlike under the pointer or a named one (`paperlike 13k light on`) — from another screen, the only link whose screen is connected — refusing rather than guessing when several match. The black-and-white 253's MCU (`0x10`) never answers `0x13`, so its link is paired by elimination (`Monitor.inferModels`: the only unreported link + the only unclaimed Paperlike screen, DASUNG product 0); an unknown link is only ever a candidate on a screen no known link drives, since its cable can stay on the dock with its screen unplugged — without it, every command on the Color's screen was refused as ambiguous. Two 253s share the same EDID `ProductName`, so tell them apart by `SerialNumber`/`YearOfManufacture`, never by name. It also *reports* (never corrects) the gamma table of each Paperlike output in `paperlike status` — a ceiling below 1.0 crushes the grey levels that are the image on e-ink, and is the most destructive host-side setting for these panels; BetterDisplay's software brightness is the usual cause. See `apps/paperlike-agent/RESEARCH.md`.
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
