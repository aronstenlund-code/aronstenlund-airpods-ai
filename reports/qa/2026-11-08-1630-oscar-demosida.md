# Oscar – demosidan live (O2)

Körd 2026-11-08 16:08–16:25 mot https://aronstenlund-code.github.io/aronstenlund-airpods-ai/ (sidans senaste commit `a4fb673`, Kelly D86). Skript: `scripts/qa/demo_site.py`, `scripts/qa/demo_site2.py`. Rådata: `reports/qa/data/2026-11-08-1612-demo-site.json`. Skärmbilder: `reports/qa/shots/` (JPEG, 50–182 kB, alla under 500 kB). **Kostnad ≈ 0,01 USD** av 0,10 (6 demofrågor, 12 uppläsningsanrop; inget Claude-anrop för bedömning). Allt är **verifierat live i Chromium**.

## Kort besked
**Sidan fungerar och kan stå kvar.** Inga hindrande fel. **WebKit (Safari) är inte testat**: Playwrights WebKit-webbläsare är inte installerad här och att installera den är en nedladdning som jag väntar på ett ja till (`playwright install webkit`, ca 70 MB). Mobil testades som iPhone 13-emulering i Chromium, så touch-ytor och layout är kontrollerade men inte Safaris egen talrigtning/ljuduppspelning.

## Resultat
| Test | Resultat |
|---|---|
| Svarar demon? | **Ja.** 5 frågor (ett knapptryck på förslagschip + 4 skrivna): första text **0,9–1,7 s** (1,6 s första, kall), svar 24–353 tecken, läses upp (2–4 `/tts`-anrop per svar, en per mening). "x frågor kvar idag" räknar ner 4→0 rätt. |
| Tak per besökare (5) | Efter 5 visar sidan själv "Du har ställt dagens 5 frågor i demon. Välkommen tillbaka i morgon." (röd, länk till väntelistan, knappen "Ställ en ny fråga"). När jag tog bort bara den lokala räknaren (samma besökare hos servern) och frågade igen visade sidan **serverns egen text oförändrad: "Du har använt dagens 5 demofrågor. Ladda ner appen eller kom tillbaka i morgon."** Alltså svenskt, och servern avgör. |
| Tak per nätverk (20) och globalt | **Ej testat i webbläsaren** (20 frågor från ett nät stänger demon för alla på det nätet; API-testet 2026-11-07 visade 429 `demo_limit_ip` med svensk text). |
| Tak för tal (8 röstfrågor) via sidan | **Inte avgjort.** Med fejkad mikrofon i headless-Chromium gjorde 9 tryck bara 2 `/stt-token`-anrop; sidan nådde aldrig taket. Texten testades via API tidigare. |
| Uppläsningstak (2 000 tecken) | Ej testat (kostar ElevenLabs-krediter). Mina 5 svar blev 1 089 tecken; fem svar på 400 tecken (max) är precis 2 000, så taket kan nås på fem långa svar. |
| Väntelista, ogiltig e-post | "Skriv en hel e-postadress, till exempel namn@exempel.se." under fältet. |
| Väntelista, utan samtycke | "Kryssa i rutan så att vi får mejla dig." (röd, tydlig). |
| Väntelista, giltig | "Klart. Vi mejlar när appen finns." |
| Dubblett, och versaler | Samma "Klart…" (avslöjar inte att adressen finns). |
| Honeypot-fältet | Utanför skärmen (`x = -9999`), `aria-hidden`, `tabindex=-1`. Syns inte och nås inte med tangentbord. |
| Ljust och mörkt | Båda följer systemet; layout intakt i båda (bilder `demo-chromium-{mobile,desktop}-{light,dark}-*`). Kontrast: **0 av 26 kontrollerade element under WCAG AA** (4,5:1 text, 3:1 stor text) i ljust och mörkt, mobil och dator. Mikrofonknappen visade 2,4:1 i första bildrutan, men det är bara de första ~0,4 s av inzoomningen (opacitet 0,4→1); när den landat är den **7,6:1** (ljust) och **6,8:1** (mörkt). Metod: beräknad ur datorstil och närmaste täckande bakgrund; rutnätsmönstret på pappret ingår inte, men är ljust och påverkar knappar och text lite. |
| Tangentbord | Tab-ordning: logga → tre förslagschip → mikrofonknapp → fältet → skicka → e-post → samtycke → "Skriv upp mig" → mejllänk (11 stopp), logisk och komplett, **synlig fokusmarkering överallt**. Frågor kan ställas helt med tangentbord (Enter i fältet). **Mikrofonknappen går att styra med mellanslag** (håll = lyssnar, släpp = klar), Enter ensam fungerar inte som håll-in. |
| Mobil (390×844) | Ingen sidledsscroll, viewport-meta rätt, `lang="sv"`, svensk titel. |
| Laddtid och sidvikt | **57 kB över nätet totalt, 3 anrop** (html 15 kB komprimerad, två typsnitt 21 + 18 kB), inga konsolfel, inga misslyckade anrop. Tre kalla laddningar: svar klart efter 190–250 ms, DOMContentLoaded 205–270 ms (Fast 4G 9 Mbit, 170 ms: laddad efter 450 ms). Första laddningen i hela sessionen tog 4,3 s (DNS/TLS), sedan aldrig mer. |

## Fynd (alla små)
1. **Fokus tappas efter en fråga** (`document.activeElement` blir `BODY`). Tangentbordsanvändare måste tabba om från sidans början efter varje svar. Förslag: flytta fokus till svaret eller "Ställ en ny fråga". (`aria-live="polite"` på svaret är på plats, så skärmläsare får texten.)
2. **Små träffytor på mobil:** samtyckesrutan är 24×24 px och mejllänken i integritetstexten är 18 px hög (under 44 px som Apple och WCAG AAA rekommenderar; WCAG AA kräver 24 px, så rutan klarar den gränsen).
3. **Svarskvalitet i det publika demot:** två språkfel i fem svar: "lågmält, diskret eller **oprätt**" (finns inte som ord) och "**ett** kapplöpning om upprustning". Det är Haikus svar, inte sidans fel, men sidan är det första en besökare ser.
4. **Tak för tal via sidan inte verifierat** (se tabell); fråga Kelly hur hon provat det, eller prova på en riktig telefon.
5. **Skärmbilden `demo-chromium-desktop-dark-answer.jpg`** visar väntelistan, inte svaret (sidan var nedrullad av mitt tangentbordstest). Svaret syns i mobilbilderna.

## Städa
Min väntelisterad `oscar-qa-site-160926@example.com` ligger i väntelistan; någon med databasåtkomst bör radera den.

## Inte testat
- WebKit/Safari, riktig iPhone, riktig Scribe-uppkoppling med mikrofon, ljuduppspelningens kvalitet. Nätverks- och globaltak i webbläsaren. TTS-taket.

## Nästa steg
1. Aron: ja eller nej till att jag installerar WebKit (`playwright install webkit`) och kör om i Safari-motorn.
2. Kelly: fynd 1, 2 och 4.
3. Kevin: fynd 3 (språkfel i demons Haiku-svar).
