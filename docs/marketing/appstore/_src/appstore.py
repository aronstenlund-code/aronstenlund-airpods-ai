"""Kelly, Ke25 (2026-11-10): App Store-bilder ur appens simulatorbilder.

Användning (från repots rot):
  python docs/marketing/appstore/_src/appstore.py <mapp med CI-bilderna> <familjen-grotesk.ttf>

<mapp> är artefakten från "Simulator screenshots" (workflow_dispatch, device "iPhone 17 Pro Max", 1320×2868),
uppackad. <ttf> görs ur site/fonts/familjen-grotesk.woff2 med fontTools (flavor=None).
Skriver docs/marketing/appstore/69-<n>.jpg (1320×2868, 6,9") och 61-<n>.jpg (1179×2556, 6,1").
Inga påhittade skärmar: varje bild är en oförändrad skärmbild ur appen, bara nedskalad och med rubrik ovanför.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = Path(sys.argv[1])
TTF = sys.argv[2]
OUT = Path("docs/marketing/appstore")

# SYSTEM.md: ink, muted, blue (accent), soft. Ljus bakgrund i soft, så att skärmbilden (vit) syns som ett kort.
INK, MUTED, BLUE, SOFT = (20, 26, 46), (94, 103, 121), (35, 70, 200), (234, 240, 255)

# (källbild, rubrik, rad under). Ord som i appen och på sidan; inga sekunder, inget om prov-fusk, inga Apple-löften.
SHOTS = [
    ("light-intro", "AI i örat för\nhela vardagen", "Telefonen stannar i fickan."),
    ("light-home", "Förhör mig\ninför provet", "Eller få A-svar på dina egna frågor."),
    ("light-listeningProv", "Svaret hörs i örat\noch syns här", "Lyssnarbrickan visar när Lumen lyssnar."),
    ("light-switch", "Plugg, intervju,\nsocialt och Rizz", "Byt läge med rösten när du vill."),
    ("light-practice", "Övningsprov\nmed rösten", "Svara högt, eller säg nästa."),
    ("light-interview", "Öva inför\nintervjun", "En kompis frågar, du hör ett färdigt svar."),
]


def font(size, weight):
    f = ImageFont.truetype(TTF, size)
    f.set_variation_by_axes([weight])
    return f


def frame(src: Image.Image, title: str, sub: str, W: int, H: int) -> Image.Image:
    k = W / 1320
    canvas = Image.new("RGB", (W, H), SOFT)
    d = ImageDraw.Draw(canvas)
    y = int(150 * k)
    tf, sf = font(int(104 * k), 700), font(int(50 * k), 450)
    for line in title.split("\n"):
        w = d.textlength(line, font=tf)
        d.text(((W - w) / 2, y), line, font=tf, fill=INK)
        y += int(120 * k)
    y += int(22 * k)
    w = d.textlength(sub, font=sf)
    d.text(((W - w) / 2, y), sub, font=sf, fill=MUTED)
    top = y + int(120 * k)

    # Skärmbilden som ett kort: 82 % bredd, rundade hörn, mjuk skugga, beskärs av nederkanten.
    sw = int(W * 0.82)
    shot = src.convert("RGB").resize((sw, int(src.height * sw / src.width)), Image.LANCZOS)
    r = int(96 * k)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), r, fill=255)
    x = (W - sw) // 2
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x, top + int(18 * k), x + sw, top + shot.height), r, fill=70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(40 * k)))
    canvas.paste(Image.new("RGB", (W, H), (16, 24, 40)), (0, 0), shadow)
    canvas.paste(shot, (x, top), mask)
    # tunn kant, som korten i SYSTEM.md
    ImageDraw.Draw(canvas).rounded_rectangle((x, top, x + sw - 1, top + shot.height), r, outline=(228, 232, 239), width=max(2, int(3 * k)))
    return canvas


for i, (name, title, sub) in enumerate(SHOTS, 1):
    src = Image.open(SRC / f"{name}.png")
    for tag, (W, H) in {"69": (1320, 2868), "61": (1179, 2556)}.items():
        p = OUT / f"{tag}-{i}.jpg"
        frame(src, title, sub, W, H).save(p, quality=88, optimize=True, progressive=True)
        print(p, p.stat().st_size // 1024, "kB")
