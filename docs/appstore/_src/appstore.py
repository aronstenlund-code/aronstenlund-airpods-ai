"""Kelly, Ke56 (2026-11-13): App Store-bilder i Apple-stil (D160) ur appens simulatorbilder. Publiceras inte.

Användning (från repots rot):
  python -I docs/appstore/_src/appstore.py <mapp med CI-bilderna> [<fet ttf> <vanlig ttf>]

<mapp> är artefakten från "Simulator screenshots", uppackad (light-<scen>.png). Typsnittet ska vara SF Pro Display
Bold/Regular när bilderna görs på en Mac. Utan argument används Segoe UI (Windows) som ersättning, och då är bilderna
bara förhandsvisningar.
Skriver docs/appstore/69-<n>.jpg (1320×2868, 6,9 tum). Varje bild är en oförändrad skärmbild ur appen, nedskalad, i
en enkel ram och med rubrik ovanför. Inga påhittade skärmar, ingen skugga och ingen gradient.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC = Path(sys.argv[1])
# Ke80: Inter Display (finns i molnet) som standard; SF Pro Display på en Mac ges som argument.
BOLD = sys.argv[2] if len(sys.argv) > 2 else "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
REG = sys.argv[3] if len(sys.argv) > 3 else "/usr/share/fonts/opentype/inter/InterDisplay-Regular.otf"
OUT = Path("docs/appstore")
OUT.mkdir(parents=True, exist_ok=True)

BG, INK, MUTED, BEZEL = (245, 245, 247), (29, 29, 31), (110, 110, 115), (29, 29, 31)
W, H = 1320, 2868

# (scen, rubrik, rad under). Ordning enligt Ke56. Texten för trycken följer A90 (Arons ord).
SHOTS = [
    # Ke80 (D232, 2026-11-18): full storlek ur kelly-appstore-shots.yml. Inget om låst skärm (D209 inte provat).
    ("repSayCredits", "Skriv. Lyssna.", "Det du skriver läses upp i dina hörlurar."),
    ("repSayOnCard", "Om och om igen.", "Från 10 minuter upp till en timme."),
    ("repSayPicked", "Hur ska det låta?", "Skriv det, så väljer EarMind en röst."),
    ("repSayVoicesUser", "Välj en röst.", "Lyssna först. Det kostar inget."),
    ("repHomeSaidMarks", "Spela igen.", "Det senaste ligger kvar under fältet."),
    ("repTextNew", "Fota boken.", "Frågor med svar, eller hela texten uppläst."),
    ("repPlayAnswer", "Tryck för svaret.", "1 gång för långt svar, 2 för kort, 3 för paus."),
    ("repShop", "Börja gratis.", "5 000 krediter att börja med, 1 500 varje månad."),
]


def make(src: Image.Image, title: str, sub: str) -> Image.Image:
    c = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(c)
    tf, sf = ImageFont.truetype(BOLD, 112), ImageFont.truetype(REG, 52)
    y = 210
    tw = d.textlength(title, font=tf)
    d.text(((W - tw) / 2, y), title, font=tf, fill=INK)
    y += 160
    sw_ = d.textlength(sub, font=sf)
    d.text(((W - sw_) / 2, y), sub, font=sf, fill=MUTED)
    top = y + 150
    # Telefonen: skärmbilden i en mörk ram med iOS-hörn, beskuren av nederkanten.
    sw = 960
    shot = src.convert("RGB").resize((sw, round(src.height * sw / src.width)), Image.LANCZOS)
    bez, r = 26, 150
    x = (W - sw) // 2
    d.rounded_rectangle((x - bez, top - bez, x + sw + bez, top + shot.height + bez), r + bez, fill=BEZEL)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), r, fill=255)
    c.paste(shot, (x, top), mask)
    return c


for i, (scene, title, sub) in enumerate(SHOTS, 1):
    p = OUT / f"69-{i}.jpg"
    make(Image.open(next(q for q in (SRC / f"{scene}.png", SRC / f"light-{scene}.png") if q.exists())), title, sub).save(p, quality=88, optimize=True, progressive=True)
    print(p, p.stat().st_size // 1024, "kB")
