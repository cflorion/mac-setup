#!/usr/bin/env python3
"""Generate docs/hyper-azerty-map.svg — a memorization map of all Hyper (CapsLock)
shortcuts on the French AZERTY keyboard. Sources: dotfiles/aerospace/aerospace.toml
and dotfiles/karabiner/karabiner.json. Re-run after changing those configs."""

from html import escape

# ---- palette -------------------------------------------------------------
CAT = {
    "app":  {"fill": "#7c3aed", "fg": "#ffffff", "sub": "#e9d5ff"},  # apps / espaces
    "win":  {"fill": "#0e7490", "fg": "#ffffff", "sub": "#cffafe"},  # fenêtres / layout
    "sys":  {"fill": "#b45309", "fg": "#ffffff", "sub": "#fde9c8"},  # souris / lanceur
    "none": {"fill": "#f1f5f9", "fg": "#94a3b8", "sub": "#cbd5e1"},  # libre
}

# ---- key data: (cap, category, line1, line2) -----------------------------
NUMBERS = [
    ("1", "app", "Espace 1", ""), ("2", "app", "Espace 2", ""), ("3", "app", "Espace 3", ""),
    ("4", "none", "", ""), ("5", "none", "", ""), ("6", "none", "", ""),
    ("7", "none", "", ""), ("8", "none", "", ""), ("9", "none", "", ""), ("0", "none", "", ""),
]
AZERTY = [
    ("A", "app", "Agenda", "Notion Cal."), ("Z", "none", "", ""), ("E", "none", "", ""),
    ("R", "win", "mode Resize", "h j k l"), ("T", "app", "TickTick", ""),
    ("Y", "app", "YouTube", "Kaset"), ("U", "sys", "Homerow", "clic"),
    ("I", "none", "", ""), ("O", "app", "Obsidian", ""), ("P", "none", "", ""),
    ("^", "win", "Focus", "← gauche"), ("$", "win", "Focus", "droite →"),
]
QSDF = [
    ("Q", "none", "", ""), ("S", "app", "Slack", ""), ("D", "win", "mode Move", "→ lettre"),
    ("F", "win", "Fullscreen", ""), ("G", "app", "Gemini", ""), ("H", "app", "Helium", ""),
    ("J", "sys", "Homerow", "défil."), ("K", "none", "", ""), ("L", "app", "Linear", ""),
    ("M", "app", "Mail", "Superhuman"),
]
WXCV = [
    ("W", "app", "WezTerm", ""), ("X", "none", "", ""), ("C", "app", "Claude", ""),
    ("V", "app", "Chat", "Google Chat"), ("B", "app", "Browser", "Safari"),
    ("N", "none", "", ""), (",", "sys", "Raycast", ""), (";", "sys", "Raycast", ""),
    (":", "sys", "Raycast", ""), ("=", "sys", "Raycast", ""),
]
SPECIAL = [  # (cap, cat, line1, line2, width)
    ("Tab", "win", "mode Focus", "h j k l", 132),
    ("␣  Espace", "win", "flottant ⇄ pavé", "", 200),
    ("← →", "win", "fenêtre →", "moniteur", 132),
    ("↑ ↓", "win", "cycler", "espaces", 132),
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
    f'Carte Hyper — clavier AZERTY</text>')

# hero: CapsLock = Hyper
add(f'<rect x="{LEFT}" y="74" width="{W-2*LEFT}" height="72" rx="14" '
    f'fill="#0f172a"/>')
add(f'<text x="{LEFT+22}" y="118" font-size="26" font-weight="800" fill="#ffffff">'
    f'⇪ CapsLock = HYPER</text>')
add(f'<text x="{LEFT+322}" y="106" font-size="14" fill="#cbd5e1">'
    f'maintenir → Hyper (⌘ ⌃ ⌥ ⇧)</text>')
add(f'<text x="{LEFT+322}" y="128" font-size="14" fill="#cbd5e1">'
    f'appui seul → Échap</text>')
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
add(f'<text x="{LEFT}" y="{PY}" font-size="16" font-weight="700" fill="#0f172a">Légende</text>')
legend = [("app", "Application / espace"), ("win", "Fenêtres & disposition"),
          ("sys", "Souris & lanceur"), ("none", "Libre")]
lx = LEFT
for cat, lbl in legend:
    add(f'<rect x="{lx}" y="{PY+12}" width="20" height="20" rx="5" fill="{CAT[cat]["fill"]}" '
        f'stroke="#00000022"/>')
    add(f'<text x="{lx+28}" y="{PY+27}" font-size="13.5" fill="#334155">{escape(lbl)}</text>')
    lx += 30 + 9 * len(lbl) + 24

# modes sub-panel
my = PY + 64
add(f'<text x="{LEFT}" y="{my}" font-size="16" font-weight="700" fill="#0f172a">Modes (Hyper ouvre, puis…)</text>')
modes = [
    "Hyper + ^ / $  →  focus fenêtre gauche / droite (touches à droite de P, direct sans mode)",
    "Hyper + D  →  mode Move : tape la lettre de l’espace pour y envoyer la fenêtre (Échap annule)",
    "Hyper + Tab  →  mode Focus (repli, h j k l) — Cmd+Tab est souvent capté par macOS",
    "Hyper + R  →  mode Resize : h l = largeur ∓ · j k = hauteur ± ",
    "Hyper + Espace  →  bascule flottant ⇄ pavé · Hyper + ← →  déplace la fenêtre vers l’autre moniteur",
]
for i, m in enumerate(modes):
    add(f'<text x="{LEFT}" y="{my+24+i*22}" font-size="13.5" fill="#334155">{escape(m)}</text>')

# footnotes
fy = my + 24 + len(modes) * 22 + 26
add(f'<text x="{LEFT}" y="{fy}" font-size="16" font-weight="700" fill="#0f172a">Notes</text>')
notes = [
    "Chiffres 1–3 : Hyper inclut ⇧, donc le chiffre est bien émis (pas @ & «).",
    "Raycast ×4 : , ; : = lancent 4 commandes Raycast (config Raycast binaire, non détaillée ici).",
    "Hors-Hyper : un appui sur ⌥ (gauche ou droite) déclenche la dictée Handy (⌃⌥⌘D).",
    "Apps dont la touche n’est pas l’initiale : B→Safari (Browser), M→Superhuman (Mail), "
    "Y→Kaset (YouTube), A→Notion Calendar (Agenda), V→Google Chat.",
]
for i, n in enumerate(notes):
    add(f'<text x="{LEFT}" y="{fy+24+i*22}" font-size="13.5" fill="#334155">{escape(n)}</text>')

add('</svg>')

with open("docs/hyper-azerty-map.svg", "w") as f:
    f.write("\n".join(out))
print("wrote docs/hyper-azerty-map.svg")
