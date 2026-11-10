"""Kelly, Ke24 (2026-11-10): Arons val nummer 4 (bock med ljudvågor), omritat som ren vektor.

Symbolen ritas i en ruta på 100 × 100. Samma tal går rakt in i SwiftUI (LumenLogo) med skala size/100.
Kör från repots rot: python docs/design/logo/_src/symbol4.py
Skriver SVG-filerna i docs/design/logo/. PNG görs med _src/render.js (puppeteer).
"""
import math
from pathlib import Path

OUT = Path("docs/design/logo")

# --- Geometri (ruta 100 × 100) ---------------------------------------------------------------
CHECK = [(13, 51), (31, 68), (53, 42)]   # bocken: vänster, botten, spets
CHECK_W = 12                              # linjebredd bock
C = (59, 55)                              # ljudvågornas centrum
ARCS = [(18, 10), (32, 10)]                 # (radie, linjebredd)
SPAN = 46                                 # grader upp och ned från vågrätt

def arc_d(r):
    a = math.radians(SPAN)
    x0, y0 = C[0] + r * math.cos(a), C[1] - r * math.sin(a)
    x1, y1 = C[0] + r * math.cos(a), C[1] + r * math.sin(a)
    return f"M{x0:.2f} {y0:.2f}A{r} {r} 0 0 1 {x1:.2f} {y1:.2f}"

def symbol(stroke, extra=""):
    pts = " ".join(f"{x} {y}" for x, y in CHECK)
    g = [f'<polyline points="{pts}" stroke-width="{CHECK_W}"/>']
    g += [f'<path d="{arc_d(r)}" stroke-width="{w}"/>' for r, w in ARCS]
    return (f'<g fill="none" stroke="{stroke}" stroke-linecap="round" stroke-linejoin="round"{extra}>'
            + "".join(g) + "</g>")

# Symbolen ensam, enfärgad (currentColor), för sidhuvudet och i appen. Rutan är symbolens yta (7–96 × 27–83),
# alltså 89 × 56: rita den med bredden = höjden × 1,59.
(OUT / "lumen-symbol.svg").write_text(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="7 27 89 56">' + symbol("currentColor") + "</svg>\n",
    encoding="utf-8")

# Appikonen 1024 × 1024, fyrkantig utan genomskinlighet (iOS rundar hörnen själv).
# Symbolen skalas 7,6 gånger (89 × 56 i rutan blir 676 × 426 px) och centreras på sin yta.
S = 7.6
def place():
    bx0, bx1, by0, by1 = 7, 96, 27, 83     # symbolens yta inkl. linjebredd (uträknad)
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    return f' transform="translate({512 - cx * S:.1f} {512 - cy * S:.1f}) scale({S})"'

ICONS = {
    # ljust: SYSTEM.md-blått med en svag toning inom samma blå, vit symbol
    "lumen-ikon-ljus.svg": ('<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
                            '<stop offset="0" stop-color="#3D62E6"/><stop offset="1" stop-color="#1D34AE"/></linearGradient>',
                            "url(#bg)", "#FFFFFF", ""),
    # mörkt (iOS 18+ mörka ikoner): nästan svart bakgrund, symbolen i mörka lägets accent
    "lumen-ikon-mork.svg": ('<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
                            '<stop offset="0" stop-color="#1A2030"/><stop offset="1" stop-color="#0B0E15"/></linearGradient>'
                            '<linearGradient id="fg" x1="0" y1="0" x2="1" y2="1">'
                            '<stop offset="0" stop-color="#A9BCFF"/><stop offset="1" stop-color="#7F9BFF"/></linearGradient>',
                            "url(#bg)", "url(#fg)", ""),
    # tonad (iOS 18+): gråskala, iOS färgar den själv
    "lumen-ikon-tonad.svg": ("", "#000000", "#FFFFFF", ""),
}
for name, (defs, bg, fg, _) in ICONS.items():
    # gradient på en stroke i användarkoordinater: gradientUnits objectBoundingBox fungerar för <g> med stroke
    (OUT / name).write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
        f"<defs>{defs}</defs>"
        f'<rect width="1024" height="1024" fill="{bg}"/>'
        + symbol(fg, place()) + "</svg>\n", encoding="utf-8")

# För favicon: vit symbol på en blå rundad ruta (läsbar i flikar i både ljust och mörkt).
(OUT / "lumen-favicon.svg").write_text(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect width="100" height="100" rx="22" fill="#2346C8"/>'
    + symbol("#FFFFFF", ' transform="translate(5.2 2.2) scale(.87)"') + "</svg>\n", encoding="utf-8")
print("ok")
