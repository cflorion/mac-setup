#!/usr/bin/env python3
"""Generate docs/hyper-azerty-map.svg — a memorization map of all Hyper (CapsLock)
shortcuts on the French AZERTY keyboard. Sources: dotfiles/aerospace/aerospace.toml
and dotfiles/karabiner/karabiner.json. Re-run after changing those configs."""

from html import escape

# ---- palette -------------------------------------------------------------
CAT = {
    "app":  {"fill": "#7c3aed", "fg": "#ffffff", "sub": "#e9d5ff"},  # apps / spaces
    "win":  {"fill": "#0e7490", "fg": "#ffffff", "sub": "#cffafe"},  # windows / layout
    "sys":  {"fill": "#b45309", "fg": "#ffffff", "sub": "#fde9c8"},  # mouse / launcher
    "none": {"fill": "#f1f5f9", "fg": "#94a3b8", "sub": "#cbd5e1"},  # free
}

# ---- key data: (cap, category, line1, line2) -----------------------------
NUMBERS = [
    ("1", "app", "Space 1", ""), ("2", "app", "Space 2", ""), ("3", "app", "Space 3", ""),
    ("4", "none", "", ""), ("5", "none", "", ""), ("6", "none", "", ""),
    ("7", "none", "", ""), ("8", "none", "", ""), ("9", "none", "", ""), ("0", "none", "", ""),
]
AZERTY = [
    ("A", "app", "Agenda", "Notion Cal."), ("Z", "none", "", ""), ("E", "none", "", ""),
    ("R", "win", "Resize mode", "h j k l"), ("T", "app", "TickTick", ""),
    ("Y", "app", "YouTube", "Kaset"), ("U", "sys", "Homerow", "click"),
    ("I", "none", "", ""), ("O", "app", "Obsidian", ""), ("P", "none", "", ""),
    ("^", "win", "Focus", "← left"), ("$", "win", "Focus", "right →"),
]
QSDF = [
    ("Q", "none", "", ""), ("S", "app", "Slack", ""), ("D", "win", "Move mode", "→ letter"),
    ("F", "win", "Fullscreen", ""), ("G", "app", "Gemini", ""), ("H", "app", "Helium", ""),
    ("J", "sys", "Homerow", "scroll"), ("K", "none", "", ""), ("L", "app", "Linear", ""),
    ("M", "app", "Mail", "Superhuman"),
]
WXCV = [
    ("W", "app", "WezTerm", ""), ("X", "none", "", ""), ("C", "app", "Chat", "Google Chat"),
    ("V", "app", "Meet", "Google Meet"), ("B", "app", "Browser", "Safari"),
    ("N", "none", "", ""), (",", "sys", "Raycast", ""), (";", "sys", "Raycast", ""),
    (":", "sys", "Raycast", ""), ("=", "sys", "Raycast", ""),
]
SPECIAL = [  # (cap, cat, line1, line2, width)
    ("Tab", "win", "Focus mode", "h j k l", 132),
    ("␣  Space", "win", "floating ⇄ tiling", "", 200),
    ("← →", "win", "window →", "monitor", 132),
    ("↑ ↓", "win", "cycle", "spaces", 132),
]

# ---- geometry ------------------------------------------------------------
KW, KH, PITCH, VPITCH = 88, 84, 96, 96
LEFT = 60
OFFSETS = [0, 20, 36, 52]      # diagonal stagger per row
ROW_Y = [190, 286, 382, 478]

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

W = 1300
H = 1052

add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}" font-family="-apple-system, Helvetica, Arial, sans-serif">')
add(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')

# title
add(f'<text x="{LEFT}" y="48" font-size="30" font-weight="800" fill="#0f172a">'
    f'Hyper &amp; Meh map — AZERTY keyboard</text>')

# hero: CapsLock = Hyper
add(f'<rect x="{LEFT}" y="74" width="{W-2*LEFT}" height="72" rx="14" '
    f'fill="#0f172a"/>')
add(f'<text x="{LEFT+22}" y="118" font-size="26" font-weight="800" fill="#ffffff">'
    f'⇪ CapsLock = HYPER</text>')
add(f'<text x="{LEFT+322}" y="106" font-size="14" fill="#cbd5e1">'
    f'hold → Hyper (⌘ ⌃ ⌥ ⇧)</text>')
add(f'<text x="{LEFT+322}" y="128" font-size="14" fill="#cbd5e1">'
    f'tap alone → Escape</text>')
add(f'<text x="{W-LEFT-22}" y="118" font-size="15" font-weight="600" '
    f'text-anchor="end" fill="#94a3b8">Hyper + …</text>')

# keyboard rows
row(NUMBERS, ROW_Y[0], OFFSETS[0])
row(AZERTY,  ROW_Y[1], OFFSETS[1])
row(QSDF,    ROW_Y[2], OFFSETS[2])
row(WXCV,    ROW_Y[3], OFFSETS[3])

# special keys row
sx, sy = LEFT, 596
for cap, cat, l1, l2, w in SPECIAL:
    key(sx, sy, cap, cat, l1, l2, w)
    sx += w + 12

# ---- bottom panels -------------------------------------------------------
PY = 720
# legend
add(f'<text x="{LEFT}" y="{PY}" font-size="16" font-weight="700" fill="#0f172a">Legend</text>')
legend = [("app", "App / space"), ("win", "Windows & layout"),
          ("sys", "Mouse & launcher"), ("none", "Free")]
lx = LEFT
for cat, lbl in legend:
    add(f'<rect x="{lx}" y="{PY+12}" width="20" height="20" rx="5" fill="{CAT[cat]["fill"]}" '
        f'stroke="#00000022"/>')
    add(f'<text x="{lx+28}" y="{PY+27}" font-size="13.5" fill="#334155">{escape(lbl)}</text>')
    lx += 30 + 9 * len(lbl) + 24

# modes sub-panel
my = PY + 64
add(f'<text x="{LEFT}" y="{my}" font-size="16" font-weight="700" fill="#0f172a">Modes (Hyper opens, then…)</text>')
modes = [
    "Hyper + ^ / $  →  focus window left / right (keys right of P, direct, no mode)",
    "Hyper + D  →  Move mode: type the space's letter to send the window there (Esc cancels)",
    "Hyper + Tab  →  Focus mode (fallback, h j k l) — Cmd+Tab is often caught by macOS",
    "Hyper + R  →  Resize mode: h l = width ∓ · j k = height ±",
    "Hyper + Space  →  toggle floating ⇄ tiling · Hyper + ← →  move window to the other monitor",
]
for i, m in enumerate(modes):
    add(f'<text x="{LEFT}" y="{my+24+i*22}" font-size="13.5" fill="#334155">{escape(m)}</text>')

# footnotes
fy = my + 24 + len(modes) * 22 + 26
add(f'<text x="{LEFT}" y="{fy}" font-size="16" font-weight="700" fill="#0f172a">Notes</text>')
notes = [
    "Digits 1–3: Hyper includes ⇧, so the digit is emitted (not @ & «).",
    "Raycast ×4: , ; : = launch 4 Raycast commands (Raycast config is binary, not detailed here).",
    "Outside Hyper: tapping ⌥ (left or right) triggers Handy dictation (⌃⌥⌘D). Right ⇧ (hold) = Meh.",
    "Apps whose key isn't the initial: B→Safari (Browser), M→Superhuman (Mail), "
    "Y→Kaset (YouTube), A→Notion Calendar (Agenda), V→Google Meet (Visio).",
]
for i, n in enumerate(notes):
    add(f'<text x="{LEFT}" y="{fy+24+i*22}" font-size="13.5" fill="#334155">{escape(n)}</text>')

# ---- Meh / OBS panel (right column) --------------------------------------
# Second layer: hold right ⇧ = Meh (⌃⌥⇧), emits clean F-keys that OBS listens
# for. Cameras "show one source + hide the rest" in one shot; E/R switch scenes.
MX, MY = 720, 612
OBS = "#0d9488"
add(f'<rect x="{MX-16}" y="{MY-28}" width="{W-LEFT-(MX-16)}" height="288" rx="14" '
    f'fill="#f0fdfa" stroke="{OBS}55"/>')
add(f'<text x="{MX}" y="{MY}" font-size="16" font-weight="700" fill="#0f172a">'
    f'Meh layer — right ⇧  (OBS / visio)</text>')
add(f'<text x="{MX}" y="{MY+20}" font-size="12.5" fill="#475569">'
    f'hold right ⇧ = Meh (⌃⌥⇧) · tap = ⇧ · emits F-keys (no key clash)</text>')
meh = [
    ("Meh + 1", "Caméra Facetime", "F19"),
    ("Meh + 2", "Caméra Brio", "F20"),
    ("Meh + 3", "Caméra ionPhone", "F16"),
    ("Meh + 4", "Caméra Fuji", "F13"),
    ("Meh + E", "Scène Écran (incrustation)", "F18"),
    ("Meh + R", "Scène Régie", "F17"),
]
for i, (combo, label, fkey) in enumerate(meh):
    ry = MY + 58 + i * 34
    add(f'<rect x="{MX}" y="{ry-18}" width="92" height="26" rx="7" fill="{OBS}"/>')
    add(f'<text x="{MX+46}" y="{ry}" font-size="13" font-weight="700" '
        f'text-anchor="middle" fill="#ffffff">{escape(combo)}</text>')
    add(f'<text x="{MX+106}" y="{ry}" font-size="13.5" fill="#334155">{escape(label)}</text>')
    add(f'<text x="{W-LEFT-12}" y="{ry}" font-size="11.5" text-anchor="end" '
        f'fill="#94a3b8">{escape(fkey)}</text>')

add('</svg>')

with open("docs/hyper-azerty-map.svg", "w") as f:
    f.write("\n".join(out))
print("wrote docs/hyper-azerty-map.svg")
