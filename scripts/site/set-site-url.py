#!/usr/bin/env python3
"""Kelly Ke68 (D202): byter sidans adress på ett ställe.

Sidans adress (canonical, og:url, og:image, sitemap och robots) står i site/site-url.txt. Metataggarna måste stå som
vanlig text i HTML-filen, eftersom Facebook, iMessage och Google inte kör JavaScript. Därför byts adressen med det här
skriptet i stället för en variabel i sidan.

    python3 scripts/site/set-site-url.py https://earmind.vercel.app/

Skriptet byter den gamla adressen mot den nya i site/index.html, site/sitemap.xml och site/robots.txt och skriver den
nya i site/site-url.txt. Det ändrar ingenting annat.
"""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2] / "site"
FILES = ["index.html", "sitemap.xml", "robots.txt"]

def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].startswith("https://"):
        print("Använd: set-site-url.py https://adress/  (med https:// och / på slutet)")
        return 2
    new = sys.argv[1] if sys.argv[1].endswith("/") else sys.argv[1] + "/"
    old = (ROOT / "site-url.txt").read_text().strip()
    if old == new:
        print("Adressen är redan", new)
        return 0
    for name in FILES:
        path = ROOT / name
        text = path.read_text(encoding="utf-8")
        n = text.count(old)
        path.write_text(text.replace(old, new), encoding="utf-8")
        print(f"{name}: {n} ställen")
    (ROOT / "site-url.txt").write_text(new + "\n")
    print("Ny adress:", new)
    return 0

if __name__ == "__main__":
    sys.exit(main())
