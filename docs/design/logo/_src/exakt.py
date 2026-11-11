"""Kelly, Ke40 efter D139 (Aron 18:51): ikonerna ska vara EXAKT ChatGPT-bilderna.
Inget ritas om. Varje originalfil i docs/design/logo/rostning/ (A–F) beskärs till den rundade rutans kvadrat, hörnen
utanför rutan (vitt eller svart) fylls med närmaste färg inifrån, och bilden skalas upp till 1024 px med Lanczos.
Färg, form, staplar och glöd ändras inte.

Kör från repots rot:  python3 docs/design/logo/_src/exakt.py
Skriver docs/design/logo/rostning/exakt/A.png … F.png och AppIcon-1024.png (= D, utan genomskinlighet).
"""
from pathlib import Path
import numpy as np
from PIL import Image

SRC = Path("docs/design/logo/rostning")
OUT = SRC / "exakt"
OUT.mkdir(exist_ok=True)
FILES = {"A": "A-klotet", "B": "B-grona-formen", "C": "C-orange-ringen",
         "D": "D-glasklotet", "E": "E-glasringen", "F": "F-glasvagen"}


def bbox(a, outside):
    """Rutans kanter: rader/kolumner där tydligt många pixlar skiljer sig från färgen utanför."""
    diff = np.abs(a.astype(int) - np.array(outside)).sum(axis=2) > 60
    cols = np.where(diff.mean(axis=0) > 0.35)[0]
    rows = np.where(diff.mean(axis=1) > 0.35)[0]
    return cols[0], rows[0], cols[-1] + 1, rows[-1] + 1


def corner_radius(a, outside, x0, y0, x1, y1):
    """Hörnradien mätt längs diagonalen från varje hörn (medel av fyra)."""
    ks = []
    for cx, cy, dx, dy in [(x0, y0, 1, 1), (x1 - 1, y0, -1, 1), (x0, y1 - 1, 1, -1), (x1 - 1, y1 - 1, -1, -1)]:
        for k in range(1, (x1 - x0) // 2):
            px = a[cy + dy * k, cx + dx * k].astype(int)
            if np.abs(px - np.array(outside)).sum() > 60:
                ks.append(k)
                break
    return float(np.mean(ks)) / (1 - 1 / np.sqrt(2))


def inside_mask(n, r):
    """Rundad kvadrat n × n med radien r (en liten marginal in, så att kantpixlar inte räknas som inne)."""
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    r = r + 1.5
    cx = np.clip(xx, r, n - r)
    cy = np.clip(yy, r, n - r)
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= (r - 1.5) ** 2 + 0.01


def fill_outside(a, mask):
    """Fyll pixlar utanför masken med medelvärdet av redan fyllda grannar, lager för lager (ingen ändring inuti)."""
    a = a.astype(float).copy()
    filled = mask.copy()
    while not filled.all():
        acc = np.zeros_like(a); cnt = np.zeros(filled.shape)
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]:
            sf = np.roll(np.roll(filled, dy, 0), dx, 1)
            sa = np.roll(np.roll(a, dy, 0), dx, 1)
            acc += sa * sf[..., None]; cnt += sf
        new = (~filled) & (cnt > 0)
        a[new] = acc[new] / cnt[new][:, None]
        filled |= new
    return a.clip(0, 255).astype(np.uint8)


def ios_mask(n, margin=0.0):
    """iOS-maskens form (rundad kvadrat, radie 22,37 %). Räknas med 95 % av radien, så att kontrollen är på säkra sidan."""
    m = 0.2237 * n * 0.95                                  # försiktigt: mindre radie visar mer av hörnet
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    cx = np.clip(xx, m, n - m); cy = np.clip(yy, m, n - m)
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= (m + margin) ** 2


def smallest_inset(side, r, aa=3):
    """Minsta indrag i (px i källan) så att hela iOS-masken på den beskurna rutan ligger inne i originalets rundade
    ruta, minus aa px kantutjämning. Då syns varken hörnfyllnad eller originalets kant innanför masken."""
    orig = inside_mask(side, max(r, 1)) if aa == 0 else None
    yy, xx = np.mgrid[0:side, 0:side] + 0.5
    cx = np.clip(xx, r, side - r); cy = np.clip(yy, r, side - r)
    inside = ((xx - cx) ** 2 + (yy - cy) ** 2 <= (r - aa) ** 2) & (xx > aa) & (xx < side - aa) & (yy > aa) & (yy < side - aa)
    for i in range(0, side // 6):
        n = side - 2 * i
        m = ios_mask(n)
        if inside[i:i + n, i:i + n][m].all():
            return i
    return side // 6


report = []
for key, name in FILES.items():
    im = Image.open(SRC / f"{name}.png").convert("RGB")
    a = np.asarray(im)
    h, w, _ = a.shape
    outside = a[[1, 1, h - 2, h - 2], [1, w - 2, 1, w - 2]].mean(axis=0)
    x0, y0, x1, y1 = bbox(a, outside)
    side = max(x1 - x0, y1 - y0)                       # kvadrat runt rutan, centrerad
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    x0, y0 = int(round(cx - side / 2)), int(round(cy - side / 2))
    x0, y0 = max(0, min(x0, w - side)), max(0, min(y0, h - side))
    sq = a[y0:y0 + side, x0:x0 + side]
    r = corner_radius(sq, outside, 0, 0, side, side)
    # Hörnen utanför originalets ruta fylls inifrån (syns inte under iOS-masken, men filen har inga vita/svarta hörn).
    filled = fill_outside(sq, inside_mask(side, r))
    i = smallest_inset(side, r)
    crop = filled[i:side - i, i:side - i]
    big = Image.fromarray(crop).resize((1024, 1024), Image.LANCZOS)
    big.save(OUT / f"{key}.png", optimize=True)
    report.append(f"{key} {name}: källa {w}×{h}, ruta {side} px, hörnradie {r:.0f} px ({r / side:.1%}), "
                  f"utanför {'vitt' if outside.mean() > 128 else 'svart'}, indrag {i} px per sida ({i / side:.1%}), "
                  f"uppskalning ×{1024 / (side - 2 * i):.2f}")
    if key == "D":
        big.save(OUT / "AppIcon-1024.png", optimize=True)

print("\n".join(report))
(OUT / "_mått.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
