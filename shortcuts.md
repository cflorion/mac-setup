# Keyboard shortcuts

> **Hyper** = hold CapsLock = Cmd+Ctrl+Opt+Shift
> **CapsLock** tapped alone = Escape
> **Meh** = hold right ⌥ = Ctrl+Opt+Shift (window and OBS layer)

---

## Karabiner

| Key | Action |
|---|---|
| CapsLock (hold) | Hyper (Cmd+Ctrl+Opt+Shift) |
| CapsLock (tap) | Escape |
| Right ⌥ (hold) | Meh (Ctrl+Opt+Shift) |
| Left ⌥ (tap) | Handy dictation (⌃⌥⌘D) |

> Right ⌥ is Meh only: type ⌥-characters (`{`, `[`, `|`…) with left ⌥.

---

## Meh — OBS / video calls

Meh keys emit F-keys (F13–F20) that have no physical key on the keyboard, so they
never clash with anything. OBS listens for those F-keys (Settings → Hotkeys).
Each camera key shows one source and hides the others in one shot.

| Shortcut | Emits | OBS action |
|---|---|---|
| Meh+1 | F19 | Camera **Facetime** |
| Meh+2 | F20 | Camera **Brio** |
| Meh+3 | F16 | Camera **ionPhone** |
| Meh+4 | F13 | Camera **Fuji** |
| Meh+W | F18 | Scene **Écran** (incrustation) |
| Meh+Q | F17 | Scene **Régie** |

> Karabiner key codes name physical (US QWERTY) positions: its `z` and `a` are the
> AZERTY **W** and **Q** keys.

---

## AeroSpace — Window Manager

### Window navigation
| Shortcut | Action |
|---|---|
| Meh+H / L | Focus window left / right |
| Meh+J / K | Focus window down / up |

### Layout — Meh (Ctrl+Opt+Shift)
| Shortcut | Action |
|---|---|
| Meh+F | Fullscreen |
| Meh+Space | Floating ↔ Tiling |
| Meh+← / → | Move window to left/right monitor |
| Meh+↑ / ↓ | Move window to monitor above/below |
| Meh+R | Resize mode (then H/J/K/L, Esc or Enter to exit) |
| Meh+M | Move mode (then a letter/digit to send the window there) |

### Workspaces
| Shortcut | Action |
|---|---|
| Hyper+← / → | Previous / next workspace |
| Hyper+1 / 2 / 3 | Free workspace |

### Focus or launch app (key = workspace)
| Shortcut | App |
|---|---|
| Hyper+W | WezTerm |
| Hyper+F | yazi (Files) |
| Hyper+M | Superhuman (Mail) |
| Hyper+S | Slack |
| Hyper+D | Messages + WhatsApp (Discussions), Messages on the left |
| Hyper+C | Claude |
| Hyper+L | Linear |
| Hyper+O | Obsidian |
| Hyper+T | TickTick |
| Hyper+R | Reminders |
| Hyper+A | Notion Calendar (Agenda) |
| Hyper+H | Helium |
| Hyper+V | Google Meet (Visio) |
| Hyper+B | Safari (Browser) |
| Hyper+G | ChatGPT |
| Hyper+Y | Kaset (YouTube Music) |

### Scratch note
| Shortcut | Action |
|---|---|
| Hyper+N | Apple Notes on the `Brouillon` note, over the current workspace; press again while Notes is in front to hide it (`notes-scratch`) |

> The note title is its first line: keep `Brouillon` on line 1 and type below it.
> Overwrite that line and the note is renamed — Hyper+N then no longer finds it
> and creates a fresh `Brouillon` note next to the old one.

---

## Links — Finicky

Finicky is the default browser: it sends every link to Safari.

| Action | Opens in |
|---|---|
| Click a link | Safari |
| Shift+click a link (outside Safari) | Helium |

> Links clicked inside Safari stay in Safari — Finicky never sees them.
> In WezTerm, Shift+click is also a selection gesture — not a reliable way to send a link to Helium.

---

## Raycast

| Shortcut | Action |
|---|---|
| Hyper+, | Search Menu Bar Items |
| Hyper+; | Toggle System Appearance |
| Hyper+: | Search Emoji & Symbols |
| Hyper+= | Clipboard History |

---

## Homerow

| Shortcut | Action |
|---|---|
| Hyper+U | Click |
| Hyper+J | Scroll |

> Karabiner turns them into ⌃⌥⌘H / ⌃⌥⌘J, the shortcuts set in Homerow.

---

## WezTerm

| Shortcut | Action |
|---|---|
| **Tabs** | |
| Cmd+T | New tab |
| Cmd+W | Close tab |
| Cmd+← / → | Previous / next tab |
| Cmd+1…9 | Tab by number |
| Cmd+Shift+E | Rename tab |
| **Panes** | |
| Cmd+D | Split right |
| Cmd+Shift+D | Split down |
| Ctrl+H/J/K/L | Focus pane left/down/up/right |
| Ctrl+Shift+H/J/K/L | Resize pane |
| Cmd+Shift+Z | Zoom pane (toggle) |
| Cmd+Shift+W | Close pane |
| **Workspaces** | |
| Cmd+Shift+S | Workspace picker |
| Cmd+Shift+N | New workspace |
| Cmd+Shift+[ / ] | Previous / next workspace |
| **Misc** | |
| Cmd+C / V | Copy / Paste |
| Cmd+F | Search |
| Cmd+P | Command palette |
| Cmd++ / Cmd+- / Cmd+0 | Font size +/−/reset |
| Cmd+Shift+R | Reload config |
| Cmd+Enter | Fullscreen |
| Cmd+Q | Quit |
| Cmd+Shift+X | Copy mode (vim) |
