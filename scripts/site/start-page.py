"""Kelly Ke96 (2026-11-27): "Kom igång"-guiden earmind.vercel.app/start (engelska) och /sv/start (svenska).

Fem steg, en skärmbild per steg ur Kellys bildflöde (kelly-appstore-shots.yml, grenen kelly/screens-ke96):
installera, AirPods, första frågan, aktiveringsorden, Spela in själv. Lovar bara det som finns: appen är inte ute än
(ingen App Store-länk), inget om låst skärm (D209). Stilen tas från site/index.html, som hjälpsidan (Ke94).
Kör från repots rot:  python3 -I scripts/site/start-page.py [<mapp med skärmbilderna>]
Med mapp görs bilderna om (site/img/start/<en|sv>-<scen>.webp, 600 px breda); utan mapp bara sidorna.
"""
import html
import re
import sys
from pathlib import Path

SITE = Path("site")
src = (SITE / "index.html").read_text(encoding="utf-8")
css_all = re.search(r"<style>(.*?)</style>", src, re.S).group(1)
lines = css_all.split("\n")
start = next(i for i, l in enumerate(lines) if l.strip().startswith(":root"))
end = next(i for i, l in enumerate(lines) if "Första skärmen" in l)
base = lines[start:end] + [l for l in lines[end:] if any(l.strip().startswith(s) for s in (".top {", ".langsw", ".fine"))]

CSS = "\n".join(base) + """
  .top.narrow { max-width: 880px; }
  .guide { padding-top: 28px; padding-bottom: calc(56px + env(safe-area-inset-bottom)); max-width: 880px; }
  .guide h1 { font-weight: 700; font-size: clamp(2.25rem, 10vw, 3.25rem); line-height: 1.04; letter-spacing: -.035em; }
  .guide .lead { margin-top: 10px; color: var(--mut); line-height: 1.5; max-width: 40em; }
  .steps { counter-reset: st; }
  .step { counter-increment: st; margin-top: 24px; padding: 20px; display: grid; gap: 18px; align-items: center; }
  .step h2 { display: flex; align-items: center; gap: 12px; font-weight: 700; font-size: 1.375rem; line-height: 1.2; }
  .step h2::before { content: counter(st); flex: none; width: 34px; height: 34px; border-radius: 50%; background: var(--blue);
                     color: var(--on-blue); display: grid; place-items: center; font-size: 1rem; }
  .step p { margin-top: 8px; color: var(--mut); line-height: 1.5; }
  .step b { color: var(--ink); font-weight: 600; }
  .shot { display: block; width: 100%; max-width: 260px; height: auto; margin: 0 auto; border-radius: 26px;
          border: 6px solid #1d1d1f; background: #1d1d1f; }
  .note { margin-top: 28px; color: var(--mut); }
  .note a, .back { color: var(--blue); }
  .back { display: inline-block; margin-top: 16px; }
  @media (min-width: 720px) { .step { grid-template-columns: minmax(0, 1fr) 260px; padding: 28px; } }
"""

T = {
    "en": {
        "lang": "en", "path": "/start", "home": "/", "support": "/support",
        "title": "Get started with EarMind",
        "desc": "Five short steps: install EarMind, connect your AirPods, ask your first question, set your activation words and record it yourself.",
        "h1": "Get started",
        "lead": "Five short steps from the first screen to your first answer in your AirPods.",
        "note": 'More questions? See <a href="/support">Help and support</a>.',
        "back": "Back to EarMind",
        "alt": "Screen from the app: ",
        "steps": [
            ("fsWelcome", "Install and open EarMind",
             "The iPhone app is coming soon to the App Store. When it's out, install it and open it. Read the welcome screen and tap <b>Continue</b>. No account is needed.",
             "the welcome screen with Snap your textbook, Listen in your AirPods and Ask out loud"),
            ("repControls", "Connect your AirPods",
             "Put in your AirPods. They connect to your iPhone as usual. In EarMind, open <b>Control with your AirPods</b> to try the presses: once for the long answer, twice for the short one, three times to pause. No AirPods? Answers play on the phone's speaker.",
             "Control with your AirPods, where you try the presses"),
            ("firstListening", "Ask your first question",
             "The next screen explains what happens to sound and text. Tap <b>I understand, start EarMind</b>, allow the microphone, and ask out loud, for example “What is photosynthesis?” The answer comes in your ear and on the screen. You always see “● Listening”, and one tap stops it. Want to study without the microphone? Tap <b>Later</b>, then <b>New quiz</b>.",
             "Listening, with Ask what you want"),
            ("listeningActivation", "Set your activation words",
             "Under “Question you're not prepared for? Say [ … ] so our AI activates.” type one or more words of your own, for example <b>Help me</b>. When EarMind hears them while it listens, it answers the question that was just asked.",
             "the activation words field with Help me, and an answer"),
            ("repOwnDeck", "Record it yourself – completely free",
             "On the first screen, tap <b>Record it yourself</b>. Write a question and an answer, tap <b>Record</b> and read them aloud, then tap <b>Practice</b>. No credits, and the sound stays on your phone.",
             "Record it yourself, with questions, answers and the Practice button"),
        ],
    },
    "sv": {
        "lang": "sv", "path": "/sv/start", "home": "/sv", "support": "/sv/support",
        "title": "Kom igång med EarMind",
        "desc": "Fem korta steg: installera EarMind, koppla dina AirPods, ställ din första fråga, välj dina aktiveringsord och spela in själv.",
        "h1": "Kom igång",
        "lead": "Fem korta steg från första skärmen till ditt första svar i dina AirPods.",
        "note": 'Fler frågor? Se <a href="/sv/support">Hjälp och support</a>.',
        "back": "Tillbaka till EarMind",
        "alt": "Skärm ur appen: ",
        "steps": [
            ("fsWelcome", "Installera och öppna EarMind",
             "iPhone-appen kommer snart till App Store. När den finns: installera och öppna den. Läs välkomstskärmen och tryck <b>Fortsätt</b>. Du behöver inget konto.",
             "välkomstskärmen med Fota boken, Lyssna i dina AirPods och Fråga högt"),
            ("repControls", "Koppla dina AirPods",
             "Sätt i dina AirPods. De kopplas till telefonen som vanligt. Öppna <b>Styr med dina AirPods</b> i EarMind och prova trycken: en gång för det långa svaret, två gånger för det korta, tre gånger för paus. Inga AirPods? Då spelas svaren i telefonens högtalare.",
             "Styr med dina AirPods, där du provar trycken"),
            ("firstListening", "Ställ din första fråga",
             "Nästa skärm förklarar vad som händer med ljud och text. Tryck <b>Jag förstår, starta EarMind</b>, tillåt mikrofonen och fråga högt, till exempel ”Vad är fotosyntes?” Svaret kommer i örat och på skärmen. Du ser alltid ”● Lyssnar”, och ett tryck stoppar. Vill du plugga utan mikrofon? Tryck <b>Senare</b> och sedan <b>Nytt prov</b>.",
             "Lyssnar, med Fråga vad du vill"),
            ("listeningActivation", "Välj dina aktiveringsord",
             "Under ”Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI.” skriver du ett eller flera egna ord, till exempel <b>Hjälp mig</b>. När EarMind hör dem medan den lyssnar svarar den på frågan som just ställdes.",
             "fältet för aktiveringsorden med Hjälp mig, och ett svar"),
            ("repOwnDeck", "Spela in själv – helt gratis",
             "Tryck <b>Spela in själv</b> på första skärmen. Skriv en fråga och ett svar, tryck <b>Spela in</b> och läs upp dem, och tryck sedan <b>Öva</b>. Inga krediter, och ljudet stannar på din telefon.",
             "Spela in själv, med frågor, svar och knappen Öva"),
        ],
    },
}


def page(t):
    steps = []
    for scene, h, p, alt in t["steps"]:
        img = f"/img/start/{t['lang']}-{scene}.webp"
        steps.append(f'<li class="step paper"><div><h2>{html.escape(h)}</h2><p>{p}</p></div>'
                     f'<img class="shot" src="{img}" width="600" height="1304" loading="lazy" alt="{html.escape(t["alt"] + alt)}"></li>')
    en_cur = ' aria-current="true"' if t["lang"] == "en" else ""
    sv_cur = ' aria-current="true"' if t["lang"] == "sv" else ""
    return f"""<!doctype html>
<html lang="{t['lang']}">
<head>
<!-- Kelly Ke96: genererad av scripts/site/start-page.py. Ändra skriptet, inte filen. -->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>{html.escape(t['title'])}</title>
<meta name="description" content="{html.escape(t['desc'])}">
<link rel="canonical" href="https://earmind.vercel.app{t['path']}">
<link rel="alternate" hreflang="en" href="https://earmind.vercel.app/start">
<link rel="alternate" hreflang="sv" href="https://earmind.vercel.app/sv/start">
<link rel="alternate" hreflang="x-default" href="https://earmind.vercel.app/start">
<meta name="theme-color" media="(prefers-color-scheme: light)" content="#FFFFFF">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#0F1218">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<style>
{CSS}
</style>
</head>
<body>
<header class="top wrap narrow">
  <a class="name" href="{t['home']}"><img src="/img/ikon-64.webp" width="32" height="32" alt=""> <span>EarMind</span></a>
  <nav class="langsw" aria-label="Language"><a href="/start" hreflang="en" lang="en" data-lang="en" aria-label="English"{en_cur}>EN</a><a href="/sv/start" hreflang="sv" lang="sv" data-lang="sv" aria-label="Svenska"{sv_cur}>SV</a></nav>
</header>
<main class="guide wrap">
  <h1>{html.escape(t['h1'])}</h1>
  <p class="lead">{html.escape(t['lead'])}</p>
  <ol class="steps">{''.join(steps)}</ol>
  <p class="note">{t['note']}</p>
  <a class="back" href="{t['home']}">{html.escape(t['back'])}</a>
</main>
<script>
// Samma språkval som sajten och betan (Ke87).
(function(){{var k="earmind.beta.lang";try{{document.querySelectorAll(".langsw a").forEach(function(a){{a.addEventListener("click",function(){{try{{localStorage.setItem(k,a.dataset.lang)}}catch(e){{}}}})}});
if(location.pathname==="/start"&&localStorage.getItem(k)==="sv")location.replace("/sv/start");}}catch(e){{}}}})();
</script>
</body>
</html>
"""


if len(sys.argv) > 1:
    from PIL import Image
    shots = Path(sys.argv[1])
    out = SITE / "img" / "start"
    out.mkdir(parents=True, exist_ok=True)
    for lang in ("en", "sv"):
        for scene, *_ in T[lang]["steps"]:
            src_png = shots / (f"en-{scene}.png" if lang == "en" else f"{scene}.png")
            im = Image.open(src_png).convert("RGB").resize((600, 1304), Image.LANCZOS)
            dst = out / f"{lang}-{scene}.webp"
            im.save(dst, quality=80, method=6)
            print(dst, dst.stat().st_size, "byte")

(SITE / "sv").mkdir(exist_ok=True)
for lang, path in (("en", SITE / "start.html"), ("sv", SITE / "sv" / "start.html")):
    path.write_text(page(T[lang]), encoding="utf-8")
    print(path, path.stat().st_size, "byte")
