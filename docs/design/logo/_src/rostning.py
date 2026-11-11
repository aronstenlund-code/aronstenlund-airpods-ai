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


# --- D, E, F (Ke40, D129/D130): glasversionerna ----------------------------------------------------
# Samma ram som A–C. Glas = genomskinliga ytor (opacitet), ljusa kanter (tunna vita streck) och samma ljusfält.
# I mörkt läggs ytorna med mix-blend-mode screen (de lyser där de överlappar), i ljust med normal blandning.
GLOW_OPACITY["svart"] = GLOW_OPACITY["mork"]

PALETTE["D"] = {
    "namn": "glasklotet",
    "mork": dict(bg=("#1E1024", "#050307"), spot="#4A2456", bars_l=("#FFB070", "#E8784C"),
                 bars_r=("#F08AD8", "#A764EC"), glow="#D46FC8"),
    "ljus": dict(bg=("#FBF4FA", "#EFE3F3"), spot="#FFFFFF", bars_l=("#F59C5C", "#DE6A42"),
                 bars_r=("#DE74C9", "#9A55E2"), glow="#D46FC8"),
    # iOS mörkt läge: motivet på nästan svart, utan färgad bakgrund
    "svart": dict(bg=("#0E0B10", "#000000"), spot="#2A1830", bars_l=("#FFB070", "#E8784C"),
                  bars_r=("#F08AD8", "#A764EC"), glow="#D46FC8"),
}
PALETTE["E"] = {
    "namn": "glasringen",
    "mork": dict(bg=("#2A1A12", "#0A0605"), spot="#6A3A1E", bars_l=("#FFAE5C", "#E8702E"),
                 bars_r=("#FFAE5C", "#E8702E"), glow="#FF8A3D"),
    "ljus": dict(bg=("#FCF5EE", "#F3E5D8"), spot="#FFFFFF", bars_l=("#F5953F", "#D95A1E"),
                 bars_r=("#F5953F", "#D95A1E"), glow="#FF8A3D"),
}
PALETTE["F"] = {
    "namn": "glasvagen",
    "mork": dict(bg=("#0F2430", "#03080D"), spot="#1E4F66", bars_l=("#000", "#000"), bars_r=("#000", "#000"),
                 glow="#4FC3D9"),
    "ljus": dict(bg=("#F0F8FB", "#DFEEF4"), spot="#FFFFFF", bars_l=("#000", "#000"), bars_r=("#000", "#000"),
                 glow="#4FC3D9"),
}
NO_BARS = {"F"}   # glasvågen har inga staplar i förlagan; vågen fyller samma bredd som staplarna (810 px)

def _blend(mode):
    return "screen" if mode in ("mork", "svart") else "normal"

def _hl(d, w=3, op=0.38):
    return f'<path d="{d}" fill="none" stroke="#FFFFFF" stroke-opacity="{op}" stroke-width="{w}"/>'

def _circle_d(cx, cy, r):
    return f"M{cx - r:.1f} {cy:.1f}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z"

def d_motif(mode):
    """Glasklotet: en orange halvmåne uppe till vänster och en rosa–lila nere till höger runt en mörk, ihålig
    mitt, ett brett S-band i glas genom mitten och en genomskinlig bubbla vid högerkanten (som förlagan)."""
    bl = _blend(mode)
    defs = ('<linearGradient id="dTop" x1="0.1" y1="0" x2="0.9" y2="1"><stop offset="0" stop-color="#FFC888"/>'
            '<stop offset="0.5" stop-color="#F7844C"/><stop offset="1" stop-color="#E2589A"/></linearGradient>'
            '<linearGradient id="dBot" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#EE4E98"/>'
            '<stop offset="0.55" stop-color="#A444D8"/><stop offset="1" stop-color="#6232C8"/></linearGradient>'
            '<linearGradient id="dBand" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FF8A6A"/>'
            '<stop offset="0.45" stop-color="#F0559E"/><stop offset="1" stop-color="#A060EE"/></linearGradient>'
            f'<clipPath id="dClip"><circle cx="{CX}" cy="{CY}" r="{R}"/></clipPath>')
    top = _circle_d(CX, CY, R) + _circle_d(CX + 58, CY + 70, R - 22)
    bot = _circle_d(CX, CY, R) + _circle_d(CX - 50, CY - 62, R - 22)
    up, lo = [], []
    n = 90
    for k in range(n + 1):
        t = k / n
        x = CX - R * 0.96 + t * (R * 2.12)
        c = CY + 48 + 82 * math.sin(2 * math.pi * (t - 0.15))
        th = 150 * math.sin(math.pi * t) ** 0.6 + 8
        up.append((x, c - th / 2)); lo.append((x, c + th / 2))
    band = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in up + lo[::-1]) + "Z"
    band_up = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in up)
    band_lo = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in lo)
    bubble = _circle_d(CX + R - 18, CY - 4, 92)
    motif = (f'<path d="{bubble}" fill="#B46CF0" fill-opacity="0.28" style="mix-blend-mode:{bl}"/>'
             f'{_hl(bubble, 2.5, 0.28)}'
             f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="{'#0B0610' if bl == 'screen' else '#3A2246'}" fill-opacity="0.88"/>'
             f'<g clip-path="url(#dClip)"><path d="{bot}" fill="url(#dBot)" fill-rule="evenodd" opacity="0.95"/>'
             f'<path d="{top}" fill="url(#dTop)" fill-rule="evenodd" opacity="0.97"/></g>'
             f'<path d="{band}" fill="url(#dBand)" fill-opacity="0.78" style="mix-blend-mode:{bl}"/>'
             f'{_hl(band_up, 3, 0.5)}{_hl(band_lo, 2, 0.25)}'
             f'<g clip-path="url(#dClip)"><path d="{top}" fill="url(#light)" fill-rule="evenodd"/>'
             f'<path d="{bot}" fill="url(#light)" fill-rule="evenodd"/></g>'
             f'{_hl(_circle_d(CX, CY, R - 1.5), 2.5, 0.3)}')
    shape = f'<circle cx="{CX}" cy="{CY}" r="{R}"/>'
    return defs, shape, motif

def e_motif(mode):
    """Glasringen: en tjock ring i glas med ljusa kanter innanför och utanför, varmast uppe till vänster."""
    w = 56
    r = R - w / 2
    dark = mode in ("mork", "svart")
    defs = (f'<radialGradient id="eRing" gradientUnits="userSpaceOnUse" cx="{CX}" cy="{CY}" r="{R}">'
            f'<stop offset="{(R - w) / R:.3f}" stop-color="#FFC47A"/>'
            f'<stop offset="{(R - w * 0.78) / R:.3f}" stop-color="#E06A22" stop-opacity="0.8"/>'
            f'<stop offset="{(R - w * 0.5) / R:.3f}" stop-color="#7A300C" stop-opacity="0.6"/>'
            f'<stop offset="{(R - w * 0.2) / R:.3f}" stop-color="#D86A24" stop-opacity="0.85"/>'
            f'<stop offset="1" stop-color="#FFC27A"/></radialGradient>'
            '<linearGradient id="eTint" x1="0.1" y1="0.1" x2="0.9" y2="0.95"><stop offset="0" stop-color="#FFE0A8"/>'
            '<stop offset="1" stop-color="#E0561E"/></linearGradient>')
    inner = f'<circle cx="{CX}" cy="{CY}" r="{R - w}" fill="#070404"/>' if dark else ""
    ring = (f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="url(#eRing)" stroke-width="{w}"/>'
            f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="url(#eTint)" stroke-width="{w}" '
            f'stroke-opacity="0.22" style="mix-blend-mode:{_blend(mode)}"/>')
    edges = _hl(_circle_d(CX, CY, R - 1.5), 2.5, 0.45) + _hl(_circle_d(CX, CY, R - w + 1.5), 2.5, 0.35)
    light = f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke="url(#light)" stroke-width="{w}"/>'
    shape = f'<circle cx="{CX}" cy="{CY}" r="{r}" fill="none" stroke-width="{w * 1.4}"/>'
    return defs, shape, inner + ring + edges + light

def f_motif(mode):
    """Glasvågen: tre breda, genomskinliga vågband som fyller ikonen som i förlagan (900 px), högsta toppen till
    höger om mitten. Förlagan saknar staplar."""
    bl = _blend(mode)
    x0, x1 = CX - 450, CX + 450
    defs = ('<linearGradient id="fW1" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3DBBA6"/>'
            '<stop offset="0.55" stop-color="#8AD2F4"/><stop offset="1" stop-color="#4A7EE2"/></linearGradient>'
            '<linearGradient id="fW2" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2FA79C"/>'
            '<stop offset="1" stop-color="#3C6CD2"/></linearGradient>'
            f'<linearGradient id="fLight" gradientUnits="userSpaceOnUse" x1="{CX}" y1="{CY - 200}" x2="{CX}" y2="{CY + 260}">'
            '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.35"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>')
    waves = [  # (topp-x, topphöjd, bas-y, tjocklek i toppen, tjocklek annars, gradient, opacitet)
        (CX - 330, 150, CY + 200, 130, 80, "fW2", 0.55),
        (CX + 250, 140, CY + 170, 110, 80, "fW2", 0.45),
        (CX + 60, 330, CY + 190, 160, 90, "fW1", 0.80),
    ]
    out = []
    for px, hgt, base, tp, te, grad, op in waves:
        up, lo = [], []
        n = 100
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            g = math.exp(-((x - px) / 175) ** 2)
            y = base - hgt * g + 22 * math.sin((x - x0) / 140)
            t = te + (tp - te) * g
            up.append((x, y - t / 2)); lo.append((x, y + t / 2))
        d = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in up + lo[::-1]) + "Z"
        hl = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in up)
        out.append(f'<path d="{d}" fill="url(#{grad})" fill-opacity="{op}" style="mix-blend-mode:{bl}"/>'
                   f'<path d="{d}" fill="url(#fLight)"/>{_hl(hl, 3, 0.55 * op + 0.1)}')
    shape = (f'<path d="M{x0} {CY + 150}C{CX - 150} {CY + 160} {CX - 60} {CY - 160} {CX + 60} {CY - 150}'
             f'C{CX + 160} {CY - 140} {CX + 260} {CY + 150} {x1} {CY + 150}" fill="none" stroke-width="90"/>')
    return defs, shape, "".join(out)

MOTIFS = {"A": a_motif, "B": b_motif, "C": c_motif, "D": d_motif, "E": e_motif, "F": f_motif}


def icon(key, mode):
    p = PALETTE[key][mode]
    mdefs, shape, motif = MOTIFS[key](mode)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'<defs>{frame_defs(p)}{mdefs}</defs>'
            f'{frame_back()}{glow(shape, mode, p["glow"])}{"" if key in NO_BARS else bars()}{motif}</svg>\n')


for key, spec in PALETTE.items():
    for mode in [m for m in ("mork", "ljus", "svart") if m in spec]:
        name = f'{key}-{spec["namn"]}-{mode}.svg'
        (OUT / name).write_text(icon(key, mode), encoding="utf-8")
        print("skrev", OUT / name)

# Symbolen för appens rubrik (D129): glasklotet förenklat till en enfärgad ring med ett S-band, currentColor.
# Ruta 100 × 100. Läsbar i 20–24 pt; ska följa textstorleken (SYSTEM.md avsnitt 10.6).
(OUT / "D-glasklotet-symbol.svg").write_text(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><g fill="none" stroke="currentColor" '
    'stroke-linecap="round"><circle cx="50" cy="50" r="39" stroke-width="9"/>'
    '<path d="M14 58C30 30 46 34 54 52S76 72 86 42" stroke-width="11"/></g></svg>\n', encoding="utf-8")
print("skrev symbol")
