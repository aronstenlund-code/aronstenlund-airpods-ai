#!/usr/bin/env python3
"""Kelly Ke78: bygger site/integritet.html och site/villkor.html ur docs/legal/*.md (enkel markdown).

Overifierade påståenden skrivs [[O: ...]] i källan och visas gulmarkerade med en ruta överst, så att Aron kan läsa igenom.
Före publicering ska alla [[O: ...]] vara borta (skriptet stoppar med --publish om något finns kvar).
"""
import html, pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[2] / "site"
PUBLISH = "--publish" in sys.argv

CSS = """:root{--bg:#fff;--ink:#141A2E;--mut:#5E6779;--line:#E3E7EF;--blue:#2346C8;--warn:#FFF3BF}
@media (prefers-color-scheme:dark){:root{--bg:#0F1218;--ink:#EEF1F7;--mut:#A3ABBA;--line:#262C38;--blue:#7F9BFF;--warn:#4A3F10}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:400 1.0625rem/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,"Segoe UI",Roboto,sans-serif;-webkit-font-smoothing:antialiased}
main{max-width:720px;margin:0 auto;padding:24px 16px 64px}header{max-width:720px;margin:0 auto;padding:16px 16px 0;display:flex;align-items:center;gap:10px;font-weight:700}
header img{width:28px;height:28px;border-radius:7px}a{color:var(--blue)}h1{font-size:2rem;line-height:1.15;margin:12px 0 4px}h2{font-size:1.25rem;margin:32px 0 6px}
p,li{color:var(--ink)}.meta{color:var(--mut);font-size:.9375rem}nav.lang{font-size:.9375rem;margin:8px 0 0}
mark.o{background:var(--warn);color:inherit;padding:0 3px;border-radius:3px}.o-box{background:var(--warn);border-radius:10px;padding:12px 14px;margin:16px 0;font-size:.9375rem}
hr{border:0;border-top:1px solid var(--line);margin:40px 0}"""

def md(text):
    out, ul = [], False
    for line in text.strip().split("\n"):
        line = line.rstrip()
        if line.startswith("- "):
            if not ul: out.append("<ul>"); ul = True
            out.append("<li>" + inline(line[2:]) + "</li>"); continue
        if ul: out.append("</ul>"); ul = False
        if not line: continue
        if line == "---": out.append("<hr>"); continue
        if line.startswith("## "): out.append(f'<h2 id="{slug(line[3:])}">' + inline(line[3:]) + "</h2>")
        elif line.startswith("# "): out.append("<h1>" + inline(line[2:]) + "</h1>")
        else: out.append("<p>" + inline(line) + "</p>")
    if ul: out.append("</ul>")
    return "\n".join(out)

def slug(t): return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")
def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r"\[\[O: (.+?)\]\]", r'<mark class="o">Overifierat: \1</mark>', t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', t)
    return t

def build(name, title, src):
    text = (ROOT.parent / "docs" / "legal" / f"{name}.md").read_text(encoding="utf-8")
    n = len(re.findall(r"\[\[O: ", text))
    if PUBLISH and n: sys.exit(f"{name}: {n} overifierade punkter kvar, publiceras inte")
    box = "" if n == 0 else f'<div class="o-box"><strong>Utkast, inte publicerat.</strong> {n} punkter är gulmarkerade: de är inte verifierade och ska kontrolleras eller strykas innan sidan publiceras.</div>'
    page = f"""<!doctype html><html lang="sv"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · EarMind</title><meta name="robots" content="{'index' if n == 0 else 'noindex'}"><link rel="icon" href="favicon-32.png">
<style>{CSS}</style></head><body><header><img src="img/ikon-64.webp" alt=""><a href="./" style="color:inherit;text-decoration:none">EarMind</a></header>
<main>{box}{md(text)}</main></body></html>"""
    (ROOT / f"{name}.html").write_text(page, encoding="utf-8")
    print(f"{name}.html: {n} overifierade")

build("integritet", "Integritet", "integritet")
build("villkor", "Villkor", "villkor")
