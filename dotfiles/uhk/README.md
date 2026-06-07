# UHK (Ultimate Hacking Keyboard) configuration

`uhk-config.json` is the full **user configuration** exported from UHK Agent
(keymaps, macros, modules, backlighting). It is the human-readable, diffable
format that Agent can re-import. It is **not** symlinked — like the Raycast
export, it is restored manually through the app.

## Restore on a new machine

1. Install Agent: `brew install --cask uhk-agent` (already in the `Brewfile`).
2. Open UHK Agent with the keyboard plugged in.
3. Menu → **Import user configuration** → pick `uhk-config.json`.
4. Click **Save to keyboard** to flash it onto the device.

## Update this export after changing the config

Just run `make uhk-backup` — it copies the live config that Agent maintains
into `uhk-config.json`. (Equivalent to `cp ~/Library/Application\ Support/uhk-agent/*.json
dotfiles/uhk/uhk-config.json`.) Then commit the diff.

(The numeric filename under `~/Library/Application Support/uhk-agent/` is the
device id; its contents are portable across keyboards via Agent's import.)

## Layout notes (AZERTY)

macOS stays on the **Français** input source. The UHK sends standard scancodes
which macOS translates to AZERTY, so letter positions match a Magic Keyboard
AZERTY — letters are **not** remapped in Agent. Only the ISO-only `< >` key
(absent on the ANSI UHK) is reassigned. System-wide remaps (CapsLock→Hyper,
⌥ tap→dictation, …) live in Karabiner, not Agent, to avoid double-remapping.
