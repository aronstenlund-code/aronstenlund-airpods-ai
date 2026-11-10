"""Kelly (Ke22-samordning, 2026-11-10): slutbilden till Ryans annonser, regel 6 i
reports/ads/2026-11-10-1400-manus-7-koncept.md och ADS.md regel 19: vad det är + vad man gör nu.
1080x1920, SYSTEM.md (vit, bläck, en accent), bara ordmärket tills loggan är vald (Ke24).
Säkra ytan (ADS.md regel 23): inget i nedersta 480 px eller närmast högerkanten.
Användning: python docs/marketing/annonser/_src/slutbild.py <familjen-grotesk.ttf>
"""
import sys
from PIL import Image, ImageDraw, ImageFont
TTF = sys.argv[1]
INK, MUTED, BLUE, WHITE = (20, 26, 46), (94, 103, 121), (35, 70, 200), (255, 255, 255)
def font(s, w):
    f = ImageFont.truetype(TTF, s); f.set_variation_by_axes([w]); return f
for name in ["Proviska", "Testvisk", "Pod Whisper", "Whisper Pod", "Lumen"]:
    W, H = 1080, 1920
    im = Image.new("RGB", (W, H), WHITE); d = ImageDraw.Draw(im)
    cx = 500  # lite till vänster om mitten: högerkanten har plattformens knappar
    nf = font(150 if len(name) <= 9 else 118, 700)
    y = 560
    w = d.textlength(name, font=nf); d.text((cx - w / 2, y), name, font=nf, fill=INK)
    sf = font(54, 450); y += 210
    for line in ["AI i örat.", "Fungerar med AirPods."]:
        w = d.textlength(line, font=sf); d.text((cx - w / 2, y), line, font=sf, fill=MUTED); y += 70
    bf = font(52, 650); label = "Gratis väntelista"; bw = d.textlength(label, font=bf) + 120
    y += 70; d.rounded_rectangle((cx - bw / 2, y, cx + bw / 2, y + 120), 30, fill=BLUE)
    w = d.textlength(label, font=bf); d.text((cx - w / 2, y + 30), label, font=bf, fill=WHITE)
    p = f"docs/marketing/annonser/slutbild/slutbild-{name.lower().replace(' ', '-')}.png"
    im.quantize(64).save(p, optimize=True); print(p)
