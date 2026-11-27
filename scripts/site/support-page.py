"""Kelly Ke94 (2026-11-27): hjälpsidan earmind.vercel.app/support (engelska) och /sv/support (svenska).

Innehållet bygger på docs/HJALP.md (Kevin, O105-1) men lovar bara det som är provat eller beslutat: inget om låst skärm
(D209), ingen välkomstbonus (D239), ingen kontaktadress (Aron väljer en, TILL-ARON). Stilen tas från site/index.html.
Kör från repots rot:  python3 -I scripts/site/support-page.py
"""
import html
import re
from pathlib import Path

SITE = Path("site")
src = (SITE / "index.html").read_text(encoding="utf-8")
css_all = re.search(r"<style>(.*?)</style>", src, re.S).group(1)


def rules(*selectors):
    """De delar av sajtens CSS som sidan använder: tokens, grund, huvud, kort, språkväxel."""
    keep = []
    lines = css_all.split("\n")
    # tokens och mörkt läge: allt fram till första sektionskommentaren efter grunden
    start = next(i for i, l in enumerate(lines) if l.strip().startswith(":root"))
    end = next(i for i, l in enumerate(lines) if "Första skärmen" in l)
    keep.extend(lines[start:end])
    for l in lines[end:]:
        if any(l.strip().startswith(s) for s in selectors):
            keep.append(l)
    return "\n".join(keep)


CSS = rules(".top {", ".langsw", ".fine") + """
  .help { padding-top: 28px; padding-bottom: calc(56px + env(safe-area-inset-bottom)); max-width: 760px; }
  .help h1 { font-weight: 700; font-size: clamp(2.25rem, 10vw, 3.25rem); line-height: 1.04; letter-spacing: -.035em; }
  .help .lead { margin-top: 10px; color: var(--mut); font-size: 1.0625rem; line-height: 1.5; }
  .toc { margin-top: 20px; display: flex; flex-wrap: wrap; gap: 8px; }
  .toc a { display: inline-block; padding: 8px 14px; border-radius: 999px; background: var(--surface); border: 1px solid var(--line);
           text-decoration: none; font-size: .9375rem; font-weight: 600; }
  .topic { margin-top: 28px; padding: 20px; scroll-margin-top: 16px; }
  .topic h2 { font-weight: 700; font-size: 1.375rem; line-height: 1.2; letter-spacing: -.01em; }
  .topic dl { margin: 0; }
  .topic dt { font-weight: 600; margin-top: 16px; }
  .topic dd { margin: 4px 0 0; color: var(--mut); }
  .topic ol { list-style: decimal; padding-left: 1.3em; margin-top: 4px; }
  .topic ol li + li { margin-top: 2px; }
  .topic b { color: var(--ink); font-weight: 600; }
  .back { display: inline-block; margin-top: 28px; color: var(--blue); }
  .lead a { color: var(--blue); }
  .top.narrow { max-width: 760px; }
"""

T = {
    "en": {
        "lang": "en", "path": "/support", "other": "/sv/support", "home": "/",
        "title": "EarMind help and support",
        "desc": "How to get started with EarMind, use your AirPods, credits, Record it yourself and privacy.",
        "h1": "Help and support",
        "lead": "Short answers to common questions about EarMind. The app is in English and Swedish.",
        "start": 'New to EarMind? <a href="/start">Get started in five steps</a>.',
        "back": "Back to EarMind",
        "contact": "Something not working? In the app, go to <b>Settings › Feedback and suggestions</b> and tell us what happened.",
        "topics": [
            ("start", "Getting started", [
                ("What is EarMind?", "EarMind helps you study by listening in your AirPods. Snap your textbook and EarMind creates quiz questions with answers and reads them in your ear. Or type any text in <b>Say in AirPods</b> and hear it again and again."),
                ("How do I make my first quiz?", "<ol><li>Tap <b>New quiz</b>.</li><li>Add material: <b>Take photos</b>, <b>Choose photos</b>, <b>Add document</b> (PDF, Word or text) or <b>Type text</b>.</li><li>Tap <b>Create questions</b>. You can leave the app while it works.</li><li>Check <b>Is this right?</b> and tap <b>Looks right</b>, or write a correction.</li><li>Tap <b>Start quiz</b>.</li></ol>"),
                ("How does Say in AirPods work?", "Type or paste a text and tap <b>Play for 10 min</b>. It repeats until the time is up, from 10 minutes up to an hour. Write how it should sound under <b>How should it sound?</b>, or pick a voice and preview it for free. Long text? Tap <b>Compress</b> for a shorter one with the same content."),
            ]),
            ("airpods", "AirPods", [
                ("How do I hear the answers?", "While a question plays or right after it: press once for the long answer, twice for the short answer and three times to pause. Press again to continue. The answers are only read when you press."),
                ("Do I need AirPods?", "No. Without AirPods the app plays through the phone's speaker."),
                ("Older AirPods with a double tap on each earbud", "Set the left earbud to <b>Next Track</b> (short answer) and the right to <b>Play/Pause</b> (long answer and pause) in iPhone Settings › Bluetooth › ⓘ next to your AirPods."),
                ("A press doesn't get through", "Check that both AirPods are in your ears and connected. If another app is playing music, the presses go to that app: start EarMind again and they come back. You can try the presses first under <b>Control with your AirPods</b>."),
            ]),
            ("words", "Your activation words", [
                ("What are activation words?", "In More modes (beta) the app says: <b>“Question you're not prepared for? Say [ … ] so our AI activates.”</b> Type one or more words of your own in the field. When EarMind hears them while it listens, it answers the question that was just asked."),
                ("When does it listen?", "Only in More modes, after you have said yes and started it. You always see “● Listening” at the top, and you stop it with one tap. Start quiz and Say in AirPods never use the microphone."),
            ]),
            ("record", "Record it yourself – completely free", [
                ("What is it?", "Write your own questions and answers, record them in your own voice and practice them in your AirPods, just like a quiz."),
                ("Does it cost anything?", "No. It uses no credits. Anything you haven't recorded is read by the phone's own voice."),
                ("Where does the sound go?", "Nowhere. Your recordings stay on your phone and are never sent to us."),
            ]),
            ("credits", "Credits and the launch offer", [
                ("How do credits work?", "1 credit is 1 character of new audio. You get 1,500 credits every month, and they refill on the 1st. Repeats, audio that already exists, quizzes others have shared, Compress, voice previews and Record it yourself are free."),
                ("What if I run out?", "The app shows what something costs before anything is made, and nothing is taken if you don't have enough. Tap <b>Top up</b> for credit packs or the <b>Weekly pass</b>. Prices are shown in the app, and you pay with your Apple account. The weekly pass renews every week until you cancel in iPhone Settings › your name › Subscriptions."),
                ("Is there a launch offer?", "During launch week, everything is 65% off. The app and this website show it while the week lasts."),
            ]),
            ("server", "When our server can't answer", [
                ("Reading aloud", "If the voice can't read right now, the phone's own voice reads instead, and the app tells you. No credits are used for it."),
                ("Answers and grading", "On iPhones with Apple Intelligence, the phone's own model answers in More modes and grades your answers, and the app says so. No credits are used for it."),
                ("Compress and new quizzes", "If the server can't shorten your text, the phone's model does it where it's available. If a new quiz can't be made right now, try again in a moment, or use Record it yourself."),
            ]),
            ("privacy", "Privacy", [
                ("Is my material saved?", "No. Photos, documents and text are sent once to make the questions and are then deleted."),
                ("Is any sound saved?", "EarMind never saves what the microphone hears. In More modes the sound is sent to ElevenLabs to be turned into text, and EarMind keeps only the text. Your own recordings in Record it yourself stay on your phone."),
                ("What is saved?", "Your quizzes, with questions, answers and audio, are saved with your account so they're there on a new phone. You don't need to sign up with an email."),
                ("Can I delete everything?", "Yes. In the app: <b>Settings › Account › Delete account</b> deletes the account and everything on our server."),
            ]),
        ],
    },
    "sv": {
        "lang": "sv", "path": "/sv/support", "other": "/support", "home": "/sv",
        "title": "EarMind hjälp och support",
        "desc": "Så kommer du igång med EarMind, använder dina AirPods, krediter, Spela in själv och integritet.",
        "h1": "Hjälp och support",
        "lead": "Korta svar på vanliga frågor om EarMind. Appen finns på svenska och engelska.",
        "start": 'Ny i EarMind? <a href="/sv/start">Kom igång i fem steg</a>.',
        "back": "Tillbaka till EarMind",
        "contact": "Fungerar något inte? Gå till <b>Inställningar › Feedback och förslag</b> i appen och berätta vad som hände.",
        "topics": [
            ("start", "Kom igång", [
                ("Vad är EarMind?", "EarMind hjälper dig att plugga genom att lyssna i dina AirPods. Fota boken, så gör EarMind provfrågor med svar och läser upp dem i örat. Eller skriv valfri text i <b>Säg i AirPods</b> och hör den om och om igen."),
                ("Hur gör jag mitt första prov?", "<ol><li>Tryck <b>Nytt prov</b>.</li><li>Lägg till material: <b>Fota sidor</b>, <b>Välj bilder</b>, <b>Lägg till dokument</b> (PDF, Word eller text) eller <b>Skriv text</b>.</li><li>Tryck <b>Gör frågor</b>. Du kan lämna appen under tiden.</li><li>Kolla <b>Stämmer det här?</b> och tryck <b>Ser rätt ut</b>, eller skriv en rättelse.</li><li>Tryck <b>Starta prov</b>.</li></ol>"),
                ("Hur fungerar Säg i AirPods?", "Skriv eller klistra in en text och tryck <b>Spela i 10 min</b>. Den upprepas tills tiden är slut, från 10 minuter upp till en timme. Skriv hur det ska låta under <b>Hur ska det låta?</b>, eller välj en röst och provlyssna gratis. Lång text? Tryck <b>Komprimera</b>, så blir den kortare med samma innehåll."),
            ]),
            ("airpods", "AirPods", [
                ("Hur hör jag svaren?", "Medan en fråga spelas eller strax efter: tryck en gång för det långa svaret, två gånger för det korta och tre gånger för paus. Tryck igen för att fortsätta. Svaren läses bara upp när du trycker."),
                ("Behöver jag AirPods?", "Nej. Utan AirPods spelar appen i telefonens högtalare."),
                ("Äldre AirPods med dubbeltryck på varje lur", "Ställ in vänster lur på <b>Nästa spår</b> (kort svar) och höger på <b>Spela/pausa</b> (långt svar och paus) under Inställningar › Bluetooth › ⓘ vid dina AirPods."),
                ("Ett tryck kommer inte fram", "Kolla att båda AirPods sitter i öronen och är anslutna. Spelar en annan app musik går trycken dit: starta EarMind igen, så kommer de tillbaka. Du kan prova trycken först under <b>Styr med dina AirPods</b>."),
            ]),
            ("words", "Dina aktiveringsord", [
                ("Vad är aktiveringsord?", "I Fler lägen (beta) står det: <b>”Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI.”</b> Skriv ett eller flera egna ord i fältet. När EarMind hör dem medan den lyssnar svarar den på frågan som just ställdes."),
                ("När lyssnar den?", "Bara i Fler lägen, när du har sagt ja och startat. Du ser alltid ”● Lyssnar” överst och stoppar med ett tryck. Starta prov och Säg i AirPods använder aldrig mikrofonen."),
            ]),
            ("record", "Spela in själv – helt gratis", [
                ("Vad är det?", "Skriv dina egna frågor och svar, läs in dem med din röst och öva på dem i dina AirPods, precis som ett prov."),
                ("Kostar det något?", "Nej. Det använder inga krediter. Det du inte har läst in läses av telefonens egen röst."),
                ("Vart tar ljudet vägen?", "Ingenstans. Dina inspelningar stannar på telefonen och skickas aldrig till oss."),
            ]),
            ("credits", "Krediter och lanseringsrabatten", [
                ("Hur fungerar krediter?", "1 kredit är 1 tecken nytt ljud. Du får 1&nbsp;500 krediter varje månad, och de fylls på den 1:a. Upprepningar, ljud som redan finns, prov som andra har delat, Komprimera, att provlyssna röster och Spela in själv kostar inget."),
                ("Om krediterna tar slut?", "Appen visar vad något kostar innan något görs, och inget dras om du inte har tillräckligt. Tryck <b>Fyll på</b> för kreditpaket eller <b>Veckokort</b>. Priserna står i appen, och du betalar med ditt Apple-konto. Veckokortet förnyas varje vecka tills du säger upp det under Inställningar › ditt namn › Prenumerationer."),
                ("Finns det en lanseringsrabatt?", "Under lanseringsveckan är det 65&nbsp;% rabatt på allt. Appen och den här sajten visar det så länge veckan pågår."),
            ]),
            ("server", "När vår server inte kan svara", [
                ("Uppläsning", "Kan rösten inte läsa upp just nu läser telefonens egen röst i stället, och appen säger det. Inga krediter dras för det."),
                ("Svar och rättning", "På iPhone med Apple Intelligence svarar telefonens egen modell i Fler lägen och rättar dina svar, och appen säger det. Inga krediter dras för det."),
                ("Komprimera och nya prov", "Kan servern inte korta din text gör telefonens modell det där den finns. Går ett nytt prov inte att göra just nu: försök igen om en stund, eller använd Spela in själv."),
            ]),
            ("privacy", "Integritet", [
                ("Sparas mitt material?", "Nej. Foton, dokument och text skickas en gång för att göra frågorna och raderas sedan."),
                ("Sparas något ljud?", "EarMind sparar aldrig det mikrofonen hör. I Fler lägen skickas ljudet till ElevenLabs för att bli text, och EarMind behåller bara texten. Dina egna inspelningar i Spela in själv stannar på telefonen."),
                ("Vad sparas?", "Dina prov, med frågor, svar och ljud, sparas på ditt konto så att de finns kvar på en ny telefon. Du behöver inte registrera dig med e-post."),
                ("Kan jag radera allt?", "Ja. I appen: <b>Inställningar › Konto › Radera konto</b> raderar kontot och allt på vår server."),
            ]),
        ],
    },
}


def page(t):
    toc = "".join(f'<a href="#{k}">{html.escape(h)}</a>' for k, h, _ in t["topics"])
    secs = []
    for k, h, qa in t["topics"]:
        items = "".join(f"<dt>{html.escape(q)}</dt><dd>{a}</dd>" for q, a in qa)
        secs.append(f'<section class="topic paper" id="{k}" aria-labelledby="{k}-h"><h2 id="{k}-h">{html.escape(h)}</h2><dl>{items}</dl></section>')
    en_cur = ' aria-current="true"' if t["lang"] == "en" else ""
    sv_cur = ' aria-current="true"' if t["lang"] == "sv" else ""
    en_href, sv_href = ("/support", "/sv/support")
    return f"""<!doctype html>
<html lang="{t['lang']}">
<head>
<!-- Kelly Ke94: genererad av scripts/site/support-page.py. Ändra skriptet, inte filen. -->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>{html.escape(t['title'])}</title>
<meta name="description" content="{html.escape(t['desc'])}">
<link rel="canonical" href="https://earmind.vercel.app{t['path']}">
<link rel="alternate" hreflang="en" href="https://earmind.vercel.app/support">
<link rel="alternate" hreflang="sv" href="https://earmind.vercel.app/sv/support">
<link rel="alternate" hreflang="x-default" href="https://earmind.vercel.app/support">
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
  <nav class="langsw" aria-label="Language"><a href="{en_href}" hreflang="en" lang="en" data-lang="en" aria-label="English"{en_cur}>EN</a><a href="{sv_href}" hreflang="sv" lang="sv" data-lang="sv" aria-label="Svenska"{sv_cur}>SV</a></nav>
</header>
<main class="help wrap">
  <h1>{html.escape(t['h1'])}</h1>
  <p class="lead">{html.escape(t['lead'])}</p>
  <p class="lead">{t['start']}</p>
  <nav class="toc" aria-label="{html.escape(t['h1'])}">{toc}</nav>
  {''.join(secs)}
  <p class="fine">{t['contact']}</p>
  <a class="back" href="{t['home']}">{html.escape(t['back'])}</a>
</main>
<script>
// Samma språkval som sajten och betan (Ke87): valet sparas och följer med.
(function(){{var k="earmind.beta.lang";try{{document.querySelectorAll(".langsw a").forEach(function(a){{a.addEventListener("click",function(){{try{{localStorage.setItem(k,a.dataset.lang)}}catch(e){{}}}})}});
if(location.pathname==="/support"&&localStorage.getItem(k)==="sv")location.replace("/sv/support");}}catch(e){{}}}})();
</script>
</body>
</html>
"""


(SITE / "sv").mkdir(exist_ok=True)
for lang, out in (("en", SITE / "support.html"), ("sv", SITE / "sv" / "support.html")):
    out.write_text(page(T[lang]), encoding="utf-8")
    print(out, out.stat().st_size, "byte")
