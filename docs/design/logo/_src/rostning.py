"""Kelly, Ke31 (2026-11-11): de tre loggkandidaterna för röstningen (D127) som rena vektorer.

Förlagor: docs/design/logo/rostning/A-klotet.png, B-grona-formen.png, C-orange-ringen.png (ChatGPT-bilder).
Kör från repots rot:  python3 docs/design/logo/_src/rostning.py
Skriver SVG i docs/design/logo/rostning/vektor/. PNG görs med _src/rostning-render.js (Playwright).

Rättvisa (det röstningen kräver): allt utom själva motivet är gemensamt och står bara här.
  - Ruta 1024 × 1024, fyrkantig utan genomskinlighet (iOS rundar hörnen själv).
  - Motivet ryms i samma ruta: 500 px brett, centrerat på 512, 512.
  - Samma staplar: två på varje sida, samma läge, höjd och bredd.
  - Samma ljus: en ljuskälla uppe till vänster (samma toning på motivet), samma glöd bakom motivet,
    samma ljusa fläck i bakgrunden. Bara färgerna skiljer.
"""
import math
from pathlib import Path

OUT = Path("docs/design/logo/rostning/vektor")
OUT.mkdir(parents=True, exist_ok=True)

# --- Gemensam ram ------------------------------------------------------------------------------
CX = CY = 512
MOTIF_W = 500                 # motivets bredd (och klotets/ringens diameter), som i förlagorna (0,49 av ikonen)
R = MOTIF_W / 2
BARS = [(318, 236), (392, 148)]   # (avstånd från mitten, höjd): inre hög, yttre låg
BAR_W = 26
GLOW_BLUR = 34                 # glöd bakom motivet (stdDeviation)
GLOW_OPACITY = {"mork": 0.42, "ljus": 0.22}

# Varje kandidat: färger per läge. Bakgrunden är en diagonal toning + en ljus fläck uppe till vänster
# med samma styrka för alla tre (spot_opacity).
PALETTE = {
    "A": {
        "namn": "klotet",
        "mork": dict(bg=("#1C1320", "#060508"), spot="#4A2E55", bars_l=("#F4A56C", "#E27A55"),
                     bars_r=("#E58BE0", "#B46BE8"), glow="#C46FD0"),
        "ljus": dict(bg=("#FBF6FB", "#EEE5F2"), spot="#FFFFFF", bars_l=("#F09A5E", "#DB6F4C"),
                     bars_r=("#D47ADB", "#9D57DE"), glow="#C46FD0"),
    },
    "B": {
        "namn": "grona-formen",
        "mork": dict(bg=("#032019", "#010C0B"), spot="#1E5A47", bars_l=("#8EDDB5", "#5DB88E"),
                     bars_r=("#8EDDB5", "#5DB88E"), glow="#6CCB9E"),
        "ljus": dict(bg=("#F2FAF5", "#E0EFE7"), spot="#FFFFFF", bars_l=("#5DBB8F", "#3E9A70"),
                     bars_r=("#5DBB8F", "#3E9A70"), glow="#6CCB9E"),
    },
    "C": {
        "namn": "orange-ringen",
        "mork": dict(bg=("#231719", "#0A0607"), spot="#553227", bars_l=("#FFA04D", "#E8662E"),
                     bars_r=("#FFA04D", "#E8662E"), glow="#FF8A3D"),
        "ljus": dict(bg=("#FCF6F1", "#F3E6DC"), spot="#FFFFFF", bars_l=("#F48A3C", "#D9581F"),
                     bars_r=("#F48A3C", "#D9581F"), glow="#FF8A3D"),
    },
}


def frame_defs(p):
    return (
        f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{p["bg"][0]}"/><stop offset="1" stop-color="{p["bg"][1]}"/></linearGradient>'
        f'<radialGradient id="spot" cx="0.38" cy="0.32" r="0.55">'
        f'<stop offset="0" stop-color="{p["spot"]}" stop-opacity="0.40"/>'
        f'<stop offset="1" stop-color="{p["spot"]}" stop-opacity="0"/></radialGradient>'
        f'<linearGradient id="barL" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{p["bars_l"][0]}"/><stop offset="1" stop-color="{p["bars_l"][1]}"/></linearGradient>'
        f'<linearGradient id="barR" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{p["bars_r"][0]}"/><stop offset="1" stop-color="{p["bars_r"][1]}"/></linearGradient>'
        # Samma ljus på motivet för alla tre: ljust uppe till vänster, mörkare nere till höger.
        # Ljuset ligger i rutans koordinater (motivets ruta CX±R), så att det är exakt samma fält för alla tre.
        f'<radialGradient id="light" gradientUnits="userSpaceOnUse" cx="{CX - 0.36 * R:.0f}" cy="{CY - 0.48 * R:.0f}" r="{1.7 * R:.0f}">'
        '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.30"/>'
        '<stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>'
        '<stop offset="0.75" stop-color="#000000" stop-opacity="0"/>'
        '<stop offset="1" stop-color="#000000" stop-opacity="0.28"/></radialGradient>'
        f'<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">'
        f'<feGaussianBlur stdDeviation="{GLOW_BLUR}"/></filter>'
    )


def frame_back():
    return ('<rect width="1024" height="1024" fill="url(#bg)"/>'
            '<rect width="1024" height="1024" fill="url(#spot)"/>')


def bars():
    out = []
    for dx, h in BARS:
        for sign, grad in ((-1, "barL"), (1, "barR")):
            x = CX + sign * dx - BAR_W / 2
            out.append(f'<rect x="{x:.0f}" y="{CY - h / 2:.0f}" width="{BAR_W}" height="{h}" '
                       f'rx="{BAR_W / 2}" fill="url(#{grad})"/>')
    return "".join(out)


def glow(shape, mode, color):
    return (f'<g filter="url(#glow)" opacity="{GLOW_OPACITY[mode]}" fill="{color}" stroke="{color}">'
            f'{shape}</g>')


# --- A: klotet -----------------------------------------------------------------------------------
# Ett klot med mjuka S-formade band, från persika uppe till lila nere.
A_BANDS = {
    "mork": ["#FAC088", "#EF9563", "#E0777A", "#B65FC9", "#8E48DC", "#6B33B8"],
    "ljus": ["#F6AE6C", "#EC8B59", "#DA6D76", "#AE56C6", "#8540D6", "#6430B0"],
}


def a_motif(mode):
    cols = A_BANDS[mode]
    # Varje band är ytan under en S-kurva; kurvorna lutar uppåt åt höger som i förlagan.
    y_starts = [-1.2, -0.42, -0.12, 0.12, 0.40, 0.66]   # i radier, vänster kant
    paths = []
    for i, (col, y0) in enumerate(zip(cols, y_starts)):
        if i == 0:
            paths.append(f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="{col}"/>')
            continue
        x0, x1 = CX - R - 20, CX + R + 20
        ya = CY + y0 * R
        yb = ya - 0.55 * R        # högerkanten ligger högre
        c1 = (CX - 0.35 * R, ya + 0.38 * R)
        c2 = (CX + 0.15 * R, yb - 0.30 * R)
        d = (f"M{x0:.1f} {ya:.1f}C{c1[0]:.1f} {c1[1]:.1f} {c2[0]:.1f} {c2[1]:.1f} {x1:.1f} {yb:.1f}"
             f"L{x1:.1f} {CY + R + 20:.1f}L{x0:.1f} {CY + R + 20:.1f}Z")
        paths.append(f'<path d="{d}" fill="{col}"/>')
    body = "".join(paths)
    defs = f'<clipPath id="clipA"><circle cx="{CX}" cy="{CY}" r="{R}"/></clipPath>'
    motif = (f'<g clip-path="url(#clipA)">{body}'
             f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="url(#light)"/></g>')
    shape = f'<circle cx="{CX}" cy="{CY}" r="{R}"/>'
    return defs, shape, motif


# --- B: den gröna formen ---------------------------------------------------------------------------
# Ett tjockt band (mätt på förlagan, enhet = R): hög klocka uppåt (topp −0,97), spegelvänd klocka nedåt (+0,97),
# trubbiga ändar (−0,34 … +0,36) med små uppåtböjda spetsar, och en mörkare inre klocka som skugga.
B_COL = {
    "mork": dict(top="#9CDEBD", bottom="#4FA982", inner="#06231A"),
    "ljus": dict(top="#86D8B0", bottom="#3A9A6D", inner="#0F4D33"),
}
B_INSET = 12        # konturen dras in så mycket och ritas sedan med rund kant, så att hörnen blir mjuka


def _g(u, c, w):
    return math.exp(-((u - c) / w) ** 2)


def _dome(u, w, p):
    # Kupol: platt rund topp och branta sidor (förlagans klockor är inte spetsiga).
    return math.exp(-abs(u / w) ** p)


def b_top(u):
    # Klockans halvbredd vid halva höjden är 0,42 R i förlagan.
    return -(0.22 + 0.75 * _dome(u, 0.48, 2.6) + 0.12 * (_g(u, -0.97, 0.07) + _g(u, 0.97, 0.07)))


def b_bottom(u):
    return 0.36 + 0.61 * _dome(u, 0.43, 2.4)


def b_path(f_top=b_top, f_bot=b_bottom, span=1.0, inset=B_INSET):
    n = 120
    rx = R - inset
    us = [-span + 2 * span * k / n for k in range(n + 1)]
    top = [(CX + u * rx, CY + f_top(u) * R + inset) for u in us]
    bot = [(CX + u * rx, CY + f_bot(u) * R - inset) for u in reversed(us)]
    return "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in top + bot) + "Z"


def b_inner_top(u):
    return 0.16 - 0.56 * _dome(u, 0.44, 2.4)


def b_inner_bottom(u):
    return 0.16 + 0.30 * _g(u, 0, 0.30)


def b_motif(mode):
    c = B_COL[mode]
    d = b_path()
    defs = (f'<linearGradient id="bFill" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{c["top"]}"/><stop offset="1" stop-color="{c["bottom"]}"/></linearGradient>'
            f'<linearGradient id="bInner" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{c["inner"]}" stop-opacity="0.30"/>'
            f'<stop offset="0.45" stop-color="{c["inner"]}" stop-opacity="0.80"/>'
            f'<stop offset="1" stop-color="{c["inner"]}" stop-opacity="0"/></linearGradient>'
            f'<clipPath id="clipB"><path d="{d}" stroke="#000" stroke-width="{2 * B_INSET}" stroke-linejoin="round"/></clipPath>')
    body = (f'<path d="{d}" fill="url(#bFill)" stroke="url(#bFill)" stroke-width="{2 * B_INSET}" '
            f'stroke-linejoin="round"/>')
    inner = f'<path d="{b_path(b_inner_top, b_inner_bottom, 0.80, 0)}" fill="url(#bInner)"/>'
    light = (f'<path d="{d}" fill="url(#light)" stroke="url(#light)" stroke-width="{2 * B_INSET}" '
             f'stroke-linejoin="round"/>')
    motif = f'{body}<g clip-path="url(#clipB)">{inner}</g>{light}'
    shape = f'<path d="{d}" stroke-width="{2 * B_INSET}" stroke-linejoin="round"/>'
    return defs, shape, motif


# --- C: den orange ringen --------------------------------------------------------------------------
# En ring som lyser som en solförmörkelse, varmast uppe till vänster.
RING_W = 30
C_COL = {
    "mork": dict(a="#FFD58A", b="#FF8A3D", c="#E2532A", inner="#0B0808"),
    "ljus": dict(a="#FFB861", b="#F47A2C", c="#D2481E", inner=None),
}


def c_motif(mode):
    c = C_COL[mode]
    r = R - RING_W / 2                         # ytterkanten = 240, samma som klotet
    defs = (f'<linearGradient id="cRing" x1="0.15" y1="0.1" x2="0.85" y2="0.95">'
            f'<stop offset="0" stop-color="{c["a"]}"/><stop offset="0.5" stop-color="{c["b"]}"/>'
            f'<stop offset="1" stop-color="{c["c"]}"/></linearGradient>')
    inner = (f'<circle cx="{CX}" cy="{CY}" r="{r - RING_W / 2}" fill="{c["inner"]}"/>' if c["inner"] else "")
    ring = f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="url(#cRing)" stroke-width="{RING_W}"/>'
    light = (f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="url(#light)" '
             f'stroke-width="{RING_W}"/>')
    motif = inner + ring + light
    shape = f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke-width="{RING_W * 1.6}"/>'
    return defs, shape, motif


MOTIFS = {"A": a_motif, "B": b_motif, "C": c_motif}


def icon(key, mode):
    p = PALETTE[key][mode]
    mdefs, shape, motif = MOTIFS[key](mode)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'<defs>{frame_defs(p)}{mdefs}</defs>'
            f'{frame_back()}{glow(shape, mode, p["glow"])}{bars()}{motif}</svg>\n')


for key, spec in PALETTE.items():
    for mode in ("mork", "ljus"):
        name = f'{key}-{spec["namn"]}-{mode}.svg'
        (OUT / name).write_text(icon(key, mode), encoding="utf-8")
        print("skrev", OUT / name)
