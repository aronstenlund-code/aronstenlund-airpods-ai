"""Kelly, Ke56 (2026-11-13): App Store-bilder i Apple-stil (D160) ur appens simulatorbilder. Publiceras inte.

Användning (från repots rot), Ke90: engelska först, svenska som andra språk:
  python -I docs/appstore/_src/appstore.py <mapp med bilderna> en|sv [<fet ttf> <vanlig ttf>]
Skriver docs/appstore/<en|sv>/<n>.jpg. Engelska skärmbilder heter en-<scen>.png (kelly-appstore-shots.yml).

Typsnittet ska vara SF Pro Display Bold/Regular när bilderna görs på en Mac; utan argument Inter Display (molnet).
Varje bild (1320×2868, 6,9 tum) är en oförändrad skärmbild ur appen, nedskalad, i en enkel ram med rubrik ovanför.
Inga påhittade skärmar, ingen skugga och ingen gradient.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC = Path(sys.argv[1])
# Ke80: Inter Display (finns i molnet) som standard; SF Pro Display på en Mac ges som argument.
LANG = sys.argv[2]
BOLD = sys.argv[3] if len(sys.argv) > 3 else "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
REG = sys.argv[4] if len(sys.argv) > 4 else "/usr/share/fonts/opentype/inter/InterDisplay-Regular.otf"
OUT = Path("docs/appstore") / LANG
OUT.mkdir(parents=True, exist_ok=True)

BG, INK, MUTED, BEZEL = (245, 245, 247), (29, 29, 31), (110, 110, 115), (29, 29, 31)
W, H = 1320, 2868

# (scen, rubrik, rad under) per språk. Ke90 (D253, D259, D262, D263): engelska först. Inget om låst skärm (D209) och
# inget om 5 000 välkomstkrediter (D239). Sista bilden Spela in själv (A165, repOwnDeck).
# Bild 8 aktiveringsordet: scenen listeningActivation (Angela Schrute, A166), tagen i en egen körning (kelly/appstore-shots-ke90b).
SHOTS = {
    "en": [
        ("repSayCredits", "Type. Listen.", "What you type is read in your earbuds."),
        ("repSayOnCard", "Again and again.", "From 10 minutes up to an hour."),
        ("repSayPicked", "How should it sound?", "Describe it, and EarMind picks a voice."),
        ("repSayVoicesUser", "Pick a voice.", "Listen first. It's free."),
        ("repSayCompressed", "Make it shorter.", "Compress keeps the content in fewer words."),
        ("repTextNew", "Snap your textbook.", "Quiz questions with answers, or the whole text read aloud."),
        ("repPlayAnswer", "Press for the answer.", "Once for the long answer, twice for short, three times to pause."),
        ("listeningActivation", "Say your words.", "Question you're not prepared for? Say [ … ] so our AI activates."),
        ("repShop", "Start free.", "1,500 credits are included every month."),
        ("repOwnDeck", "Record it yourself.", "Completely free. The sound stays on your phone."),
    ],
    "sv": [
        ("repSayCredits", "Skriv. Lyssna.", "Det du skriver läses upp i dina hörlurar."),
        ("repSayOnCard", "Om och om igen.", "Från 10 minuter upp till en timme."),
        ("repSayPicked", "Hur ska det låta?", "Skriv det, så väljer EarMind en röst."),
        ("repSayVoicesUser", "Välj en röst.", "Lyssna först. Det kostar inget."),
        ("repSayCompressed", "Gör det kortare.", "Komprimera ger samma innehåll med färre ord."),
        ("repTextNew", "Fota boken.", "Frågor med svar, eller hela texten uppläst."),
        ("repPlayAnswer", "Tryck för svaret.", "1 gång för långt svar, 2 för kort, 3 för paus."),
        ("listeningActivation", "Säg dina ord.", "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI."),
        ("repShop", "Börja gratis.", "1\u00a0500 krediter ingår varje månad."),
        ("repOwnDeck", "Spela in själv.", "Helt gratis. Ljudet stannar på din telefon."),
    ],
}[LANG]


def lines(d, text, font, width):
    """Raden under på högst två rader, bruten vid ett mellanslag så nära mitten som möjligt."""
    if d.textlength(text, font=font) <= width:
        return [text]
    words = text.split(" ")
    best = min(range(1, len(words)), key=lambda i: abs(d.textlength(" ".join(words[:i]), font=font) - d.textlength(" ".join(words[i:]), font=font)))
    return [" ".join(words[:best]), " ".join(words[best:])]


def make(src: Image.Image, title: str, sub: str) -> Image.Image:
    c = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(c)
    tf, sf = ImageFont.truetype(BOLD, 112), ImageFont.truetype(REG, 52)
    y = 210
    tw = d.textlength(title, font=tf)
    d.text(((W - tw) / 2, y), title, font=tf, fill=INK)
    y += 160
    for k, line in enumerate(lines(d, sub, sf, W - 160)):
        d.text(((W - d.textlength(line, font=sf)) / 2, y + 68 * k), line, font=sf, fill=MUTED)
    top = y + 68 * 2 + 70  # plats för två rader på alla bilder, så att telefonerna står i samma höjd
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
    p = OUT / f"{i}.jpg"
    pre = "en-" if LANG == "en" else ""
    make(Image.open(SRC / f"{pre}{scene}.png"), title, sub).save(p, quality=88, optimize=True, progressive=True)
    print(p, p.stat().st_size // 1024, "kB")
