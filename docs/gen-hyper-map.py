#!/usr/bin/env python3
"""Generate docs/hyper-azerty-map.svg — a memorization map of all Hyper (CapsLock)
and Meh (right ⌥) shortcuts on the French AZERTY keyboard. Sources:
dotfiles/aerospace/aerospace.toml and dotfiles/karabiner/karabiner.json. Re-run
after changing those configs."""

from html import escape

# ---- palette -------------------------------------------------------------
CAT = {
    "app":  {"fill": "#7c3aed", "fg": "#ffffff", "sub": "#e9d5ff"},  # apps / spaces
    "win":  {"fill": "#0e7490", "fg": "#ffffff", "sub": "#cffafe"},  # windows / layout
    "sys":  {"fill": "#b45309", "fg": "#ffffff", "sub": "#fde9c8"},  # mouse / launcher
    "obs":  {"fill": "#be123c", "fg": "#ffffff", "sub": "#ffe4e6"},  # OBS cameras / scenes
    "none": {"fill": "#f1f5f9", "fg": "#94a3b8", "sub": "#cbd5e1"},  # free
}

# ---- Hyper layer: (cap, category, line1, line2) --------------------------
NUMBERS = [
    ("1", "app", "Space 1", ""), ("2", "app", "Space 2", ""), ("3", "app", "Space 3", ""),
    ("4", "none", "", ""), ("5", "none", "", ""), ("6", "none", "", ""),
    ("7", "none", "", ""), ("8", "none", "", ""), ("9", "none", "", ""), ("0", "none", "", ""),
]
AZERTY = [
    ("A", "app", "Agenda", "Notion Cal."), ("Z", "none", "", ""), ("E", "none", "", ""),
    ("R", "app", "Reminders", ""), ("T", "app", "TickTick", ""),
    ("Y", "app", "YouTube", "Kaset"), ("U", "sys", "Homerow", "click"),
    ("I", "none", "", ""), ("O", "app", "Obsidian", ""), ("P", "none", "", ""),
    ("^", "none", "", ""), ("$", "none", "", ""),
]
QSDF = [
    ("Q", "none", "", ""), ("S", "app", "Slack", ""), ("D", "app", "Messages", "+ WhatsApp"),
    ("F", "app", "Files", "yazi"), ("G", "app", "ChatGPT", ""), ("H", "app", "Helium", ""),
    ("J", "sys", "Homerow", "scroll"), ("K", "none", "", ""), ("L", "app", "Linear", ""),
    ("M", "app", "Mail", "Superhuman"),
]
WXCV = [
    ("W", "app", "WezTerm", ""), ("X", "none", "", ""), ("C", "app", "Claude", ""),
    ("V", "app", "Meet", "Google Meet"), ("B", "app", "Browser", "Safari"),
    ("N", "app", "Notes", "Brouillon"), (",", "sys", "Raycast", ""), (";", "sys", "Raycast", ""),
    (":", "sys", "Raycast", ""), ("=", "sys", "Raycast", ""),
]
SPECIAL = [  # (cap, cat, line1, line2, width)
    ("Tab", "none", "", "", 132),
    ("␣  Space", "none", "", "", 200),
    ("← →", "app", "cycle spaces", "prev / next", 132),
    ("↑ ↓", "none", "", "", 132),
]

# ---- Meh layer -----------------------------------------------------------
# Karabiner key codes are physical US positions: the OBS scene keys it binds as
# `a` and `z` are the AZERTY Q and W keys.
MEH_NUMBERS = [
    ("1", "obs", "Facetime", "camera · F19"), ("2", "obs", "Brio", "camera · F20"),
    ("3", "obs", "ionPhone", "camera · F16"), ("4", "obs", "Fuji", "camera · F13"),
    ("5", "none", "", ""), ("6", "none", "", ""), ("7", "none", "", ""),
    ("8", "none", "", ""), ("9", "none", "", ""), ("0", "none", "", ""),
]
MEH_AZERTY = [
    ("A", "none", "", ""), ("Z", "none", "", ""), ("E", "none", "", ""),
    ("R", "win", "Resize mode", "h j k l"), ("T", "none", "", ""), ("Y", "none", "", ""),
    ("U", "none", "", ""), ("I", "none", "", ""), ("O", "none", "", ""),
    ("P", "none", "", ""), ("^", "none", "", ""), ("$", "none", "", ""),
]
MEH_QSDF = [
    ("Q", "obs", "Régie", "scene · F17"), ("S", "none", "", ""), ("D", "none", "", ""),
    ("F", "win", "Fullscreen", ""), ("G", "none", "", ""), ("H", "win", "Focus", "← left"),
    ("J", "win", "Focus", "↓ down"), ("K", "win", "Focus", "↑ up"),
    ("L", "win", "Focus", "right →"), ("M", "win", "Move mode", "→ space key"),
]
MEH_WXCV = [
    ("W", "obs", "Écran", "scene · F18"), ("X", "none", "", ""), ("C", "none", "", ""),
    ("V", "none", "", ""), ("B", "none", "", ""), ("N", "none", "", ""),
    (",", "none", "", ""), (";", "none", "", ""), (":", "none", "", ""), ("=", "none", "", ""),
]
MEH_SPECIAL = [
    ("Tab", "none", "", "", 132),
    ("␣  Space", "win", "floating ⇄ tiling", "", 200),
    ("← →", "win", "window → monitor", "left / right", 132),
    ("↑ ↓", "win", "window → monitor", "up / down", 132),
]

# ---- bottom panels -------------------------------------------------------
MODES = [
    "Meh + M  →  Move mode: type a space's key (letter or 1–3) to send the window there (Esc cancels)",
    "Meh + R  →  Resize mode: h l = width ∓ · j k = height ± (Esc or Enter exits)",
]
NOTES = [
    "Digits: Hyper and Meh both include ⇧, so the number row reads as digits "
    "(unshifted it types & é \" ').",
    "Raycast ×4: , ; : = launch 4 Raycast commands (Raycast config is binary, not detailed here).",
    "Left ⌥: tap alone → Handy dictation (⌃⌥⌘D); hold it to type ⌥-characters ({ [ | …), "
    "since right ⌥ is Meh.",
    "Apps whose key isn't the initial: B→Safari (Browser), M→Superhuman (Mail), "
    "Y→Kaset (YouTube), A→Notion Calendar (Agenda),",
    "V→Google Meet (Visio), D→Messages + WhatsApp (Discussions), F→yazi (Files), "
    "G→ChatGPT (GPT).",
]

# ---- geometry ------------------------------------------------------------
KW, KH, PITCH = 88, 84, 96
LEFT = 60
OFFSETS = [0, 20, 36, 52]      # diagonal stagger per row
ROW_DY = [0, 96, 192, 288]     # row tops, from the layer's first row
SPECIAL_DY = 406               # special-keys row, from the layer's first row
HYPER_Y = 190                  # first-row top of each layer; its hero bar sits 116 above
MEH_Y = HYPER_Y + 646
LEGEND_Y = MEH_Y + SPECIAL_DY + KH + 44
MODES_Y = LEGEND_Y + 64
NOTES_Y = MODES_Y + 24 + len(MODES) * 22 + 26

W = 1300
H = NOTES_Y + 24 + len(NOTES) * 22 - 4

out = []
def add(s): out.append(s)

def key(x, y, cap, cat, l1, l2, w=KW):
    c = CAT[cat]
    add(f'<g>')
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{KH}" rx="11" '
        f'fill="{c["fill"]}" stroke="#00000022" stroke-width="1"/>')
    # keycap letter (top-left)
    add(f'<text x="{x+11}" y="{y+30}" font-size="23" font-weight="700" '
        f'fill="{c["fg"]}">{escape(cap)}</text>')
    cx = x + w/2
    if l1:
        ly = y + 56 if l2 else y + 62
        add(f'<text x="{cx}" y="{ly}" font-size="12.5" font-weight="600" '
            f'text-anchor="middle" fill="{c["fg"]}">{escape(l1)}</text>')
    if l2:
        add(f'<text x="{cx}" y="{y+72}" font-size="10.5" '
            f'text-anchor="middle" fill="{c["sub"]}">{escape(l2)}</text>')
    add('</g>')

def row(keys, ry, off):
    x = LEFT + off
    for cap, cat, l1, l2 in keys:
        key(x, ry, cap, cat, l1, l2)
        x += PITCH

# dark bar naming the modifier key of a layer
def hero(y, title, hold, tap, right):
    add(f'<rect x="{LEFT}" y="{y}" width="{W-2*LEFT}" height="72" rx="14" '
        f'fill="#0f172a"/>')
    add(f'<text x="{LEFT+22}" y="{y+44}" font-size="26" font-weight="800" fill="#ffffff">'
        f'{escape(title)}</text>')
    add(f'<text x="{LEFT+322}" y="{y+32}" font-size="14" fill="#cbd5e1">'
        f'{escape(hold)}</text>')
    add(f'<text x="{LEFT+322}" y="{y+54}" font-size="14" fill="#cbd5e1">'
        f'{escape(tap)}</text>')
    add(f'<text x="{W-LEFT-22}" y="{y+44}" font-size="15" font-weight="600" '
        f'text-anchor="end" fill="#94a3b8">{escape(right)}</text>')

# four keyboard rows, then the special keys row
def layer(top, rows, special):
    for keys, dy, off in zip(rows, ROW_DY, OFFSETS):
        row(keys, top + dy, off)
    sx = LEFT
    for cap, cat, l1, l2, w in special:
        key(sx, top + SPECIAL_DY, cap, cat, l1, l2, w)
        sx += w + 12

add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}" font-family="-apple-system, Helvetica, Arial, sans-serif">')
add(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')

# title
add(f'<text x="{LEFT}" y="48" font-size="30" font-weight="800" fill="#0f172a">'
    f'Hyper &amp; Meh map — AZERTY keyboard</text>')

hero(HYPER_Y - 116, "⇪ CapsLock = HYPER", "hold → Hyper (⌘ ⌃ ⌥ ⇧)", "tap alone → Escape",
     "Hyper + …")
layer(HYPER_Y, [NUMBERS, AZERTY, QSDF, WXCV], SPECIAL)

hero(MEH_Y - 116, "Right ⌥ = MEH", "hold → Meh (⌃ ⌥ ⇧)", "tap alone → nothing", "Meh + …")
layer(MEH_Y, [MEH_NUMBERS, MEH_AZERTY, MEH_QSDF, MEH_WXCV], MEH_SPECIAL)

# legend
add(f'<text x="{LEFT}" y="{LEGEND_Y}" font-size="16" font-weight="700" fill="#0f172a">Legend</text>')
legend = [("app", "App / space"), ("win", "Windows & layout"),
          ("sys", "Mouse & launcher"), ("obs", "OBS camera / scene"), ("none", "Free")]
lx = LEFT
for cat, lbl in legend:
    add(f'<rect x="{lx}" y="{LEGEND_Y+12}" width="20" height="20" rx="5" fill="{CAT[cat]["fill"]}" '
        f'stroke="#00000022"/>')
    add(f'<text x="{lx+28}" y="{LEGEND_Y+27}" font-size="13.5" fill="#334155">{escape(lbl)}</text>')
    lx += 30 + 9 * len(lbl) + 24

# modes
add(f'<text x="{LEFT}" y="{MODES_Y}" font-size="16" font-weight="700" fill="#0f172a">Modes (Meh opens, then…)</text>')
for i, m in enumerate(MODES):
    add(f'<text x="{LEFT}" y="{MODES_Y+24+i*22}" font-size="13.5" fill="#334155">{escape(m)}</text>')

# notes
add(f'<text x="{LEFT}" y="{NOTES_Y}" font-size="16" font-weight="700" fill="#0f172a">Notes</text>')
for i, n in enumerate(NOTES):
    add(f'<text x="{LEFT}" y="{NOTES_Y+24+i*22}" font-size="13.5" fill="#334155">{escape(n)}</text>')

add('</svg>')

with open("docs/hyper-azerty-map.svg", "w") as f:
    f.write("\n".join(out))
print("wrote docs/hyper-azerty-map.svg")
