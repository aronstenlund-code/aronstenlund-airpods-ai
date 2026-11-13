# Kelly Ke51: bygger utkastet till demosidan för repetitionsläget av site/index.html.
# Kör från repots rot: python -I drafts/site-repetition/build.py
# Utkastet publiceras INTE: det ligger utanför site/ (Pages publicerar bara site/**), har noindex och läser sajtens
# typsnitt och bilder via <base href="../../site/">. Läggs in i site/ först när T18 är godkänt och Aron sagt ja.
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parents[2]
src = (root / "site/index.html").read_text(encoding="utf-8")
here = pathlib.Path(__file__).parent
hero = (here / "hero.html").read_text(encoding="utf-8")
steps = (here / "steps.html").read_text(encoding="utf-8")
css = (here / "draft.css").read_text(encoding="utf-8")
js = (here / "draft.js").read_text(encoding="utf-8")

def sub(pattern, repl, s, flags=re.S):
    n, k = re.subn(pattern, lambda m: repl, s, count=1, flags=flags)
    if k != 1:
        sys.exit("hittade inte: " + pattern[:60])
    return n

out = src
out = sub(r"<head>", '<head>\n<base href="../../site/">\n<meta name="robots" content="noindex, nofollow">\n'
          '<!-- UTKAST (Kelly Ke51). Publiceras inte förrän T18 är godkänt och Aron sagt ja. -->', out)
out = sub(r"<title>.*?</title>", "<title>Earmind – Plugga med AirPods utan att röra mobilen (utkast)</title>", out)
# Heron: ny rubrik och ingress; repetitionsdemon före den gamla livedemon, som döljs men finns kvar (sidans skript
# letar efter dess element).
out = sub(r'<div class="intro">.*?</div>\s*\n\s*<div class="demo paper" id="demo"',
          hero + '\n    <div class="demo paper" id="demo" hidden', out)
out = sub(r'<section class="start wrap" id="kom-igang".*?</section>', steps, out)
# D142: lyssnande lägen är BETA. "Vad kan Earmind?" beskriver dem, så rubriken får märket och en rad.
out = sub(r'<h2 id="kan-h">Vad kan <span data-app></span>\?</h2>',
          '<h2 id="kan-h">Mer i <span data-app></span> <span class="draft-flag beta">Beta</span></h2>\n'
          '    <p class="lead">Lägen som lyssnar på vad du säger. De är i beta och blir bättre hela tiden. Starta prov använder aldrig mikrofonen.</p>', out)
out = sub(r"</style>", css + "\n</style>", out)
out = sub(r"</body>", "<script>\n" + js + "\n</script>\n</body>", out)
(here / "index.html").write_text(out, encoding="utf-8", newline="\n")
print("klart", len(out.encode("utf-8")), "byte")
