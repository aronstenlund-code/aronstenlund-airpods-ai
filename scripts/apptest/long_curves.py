"""T2 (Toby): curves and a Markdown summary of apptest-out/chain/long.json.

Writes memory.svg, latency.svg, answers.svg next to long.json and prints summary.md to stdout. No third-party packages.
"""
import json
import sys
from pathlib import Path


def svg_chart(title, unit, points, out: Path, kind="line"):
    """points: [(x_minutes, y)]; a plain SVG line or dot chart, 640x260."""
    w, h, left, bottom, top, right = 640, 260, 56, 32, 28, 16
    if not points:
        out.write_text(f"<svg xmlns='http://www.w3.org/2000/svg' width='{w}' height='{h}'><text x='10' y='20'>{title}: no data</text></svg>")
        return
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    x_max = max(max(xs), 1)
    y_min = 0
    y_max = max(ys) * 1.1 or 1

    def px(x):
        return left + (w - left - right) * x / x_max

    def py(y):
        return h - bottom - (h - bottom - top) * (y - y_min) / (y_max - y_min)

    parts = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{w}' height='{h}' font-family='sans-serif' font-size='11'>",
             "<rect width='100%' height='100%' fill='white'/>",
             f"<text x='{left}' y='16' font-size='13' font-weight='bold'>{title}</text>"]
    for i in range(5):
        y = y_min + (y_max - y_min) * i / 4
        parts.append(f"<line x1='{left}' x2='{w - right}' y1='{py(y):.1f}' y2='{py(y):.1f}' stroke='#e2e7ef'/>")
        parts.append(f"<text x='{left - 6}' y='{py(y) + 4:.1f}' text-anchor='end' fill='#5a6478'>{y:.0f}</text>")
    for i in range(7):
        x = x_max * i / 6
        parts.append(f"<text x='{px(x):.1f}' y='{h - 12}' text-anchor='middle' fill='#5a6478'>{x:.0f} min</text>")
    parts.append(f"<text x='12' y='{top + 8}' fill='#5a6478'>{unit}</text>")
    if kind == "dots":
        parts += [f"<circle cx='{px(x):.1f}' cy='{py(y):.1f}' r='2.2' fill='#2346c8'/>" for x, y in points]
    else:
        path = " ".join(f"{'M' if i == 0 else 'L'}{px(x):.1f},{py(y):.1f}" for i, (x, y) in enumerate(points))
        parts.append(f"<path d='{path}' fill='none' stroke='#2346c8' stroke-width='2'/>")
    parts.append("</svg>")
    out.write_text("\n".join(parts), encoding="utf-8")


def median(values):
    values = sorted(values)
    return values[len(values) // 2] if values else None


def main(out: Path) -> None:
    path = out / "long.json"
    print("## Långtest Provläge (T2, simulator)\n")
    print("Simulator only, never a verification on a device. Live Scribe and /answer, answers not spoken.\n")
    if not path.exists():
        print("No long.json (the test did not get as far as writing it).")
        return
    r = json.loads(path.read_text(encoding="utf-8"))
    samples, answers = r["samples"], r["answers"]
    svg_chart("Minne (phys_footprint)", "MB", [(s["minute"], s["memoryMB"]) for s in samples], out / "memory.svg")
    svg_chart("Tid till första text per svar", "ms",
              [(a["minute"], a["firstTextMs"]) for a in answers if a.get("firstTextMs")], out / "latency.svg", "dots")
    svg_chart("Svar totalt", "svar", [(s["minute"], s["answered"]) for s in samples], out / "answers.svg")
    last = samples[-1] if samples else {}
    print(f"Planerat {r['minutes']:.0f} min · körde {last.get('minute', 0):.1f} min · "
          f"{len(answers)} svar · Scribe-händelser {len(r.get('reconnectLines', []))} · "
          + (f"**stoppade vid minut {r['stoppedAtMinute']:.1f}**" if r.get("stoppedAtMinute") is not None else "lyssnade hela tiden")
          + "\n")
    print("| Minut | Minne MB | Hört | Svar | Svar/min (senaste 5) | Median första text (senaste 5 min) | Läge | Aktiv |")
    print("|---:|---:|---:|---:|---:|---:|---|---|")
    for i, s in enumerate(samples):
        if i % 5 != 0 and i != len(samples) - 1:
            continue
        window = [a for a in answers if s["minute"] - 5 <= a["minute"] <= s["minute"]]
        med = median([a["firstTextMs"] for a in window if a.get("firstTextMs")])
        rate = len(window) / 5 if s["minute"] >= 5 else len(window) / max(s["minute"], 1)
        print(f"| {s['minute']:.0f} | {s['memoryMB']:.0f} | {s['heard']} | {s['answered']} | {rate:.1f} | "
              f"{'%.0f ms' % med if med else '–'} | {s['mode']} | {'ja' if s['active'] else '**nej**'} |")
    if r.get("reconnectLines"):
        print("\n### Scribe-händelser\n")
        for line in r["reconnectLines"][:40]:
            print(f"- `{line}`")
    if r.get("errorLines"):
        print("\n### Fel i loggen (första 30)\n")
        for line in r["errorLines"][:30]:
            print(f"- `{line}`")
    print("\nKurvor: memory.svg, latency.svg, answers.svg i artefakten.")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
