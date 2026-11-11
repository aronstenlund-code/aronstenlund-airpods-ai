"""Kelly, Ke40: tonad appikon (iOS 18+, Tinted) för D glasklotet.
iOS vill ha en gråskalebild på svart; systemet färgar den själv. Görs av den mörka versionen (motivet på svart).
Kör efter rostning-render.js:  python3 docs/design/logo/_src/rostning-tonad.py  (och sedan render.js igen för kontrollen)
"""
from PIL import Image, ImageOps

DIR = "docs/design/logo/rostning/vektor"
im = Image.open(f"{DIR}/D-glasklotet-svart-1024.png").convert("L")
im = ImageOps.autocontrast(im, cutoff=0.5)          # motivet ljust, bakgrunden svart
im.convert("RGB").save(f"{DIR}/D-glasklotet-tonad-1024.png", optimize=True)
print("skrev tonad")
