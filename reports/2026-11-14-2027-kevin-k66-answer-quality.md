# K66: svarskvaliteten efter Oscars O63 (Kevin, 2026-11-14 20:27)

## Kort
Alla fem punkterna är klara och driftsatta (071310e och a2eb799). Oscars sex prov från O63 kördes igen live med testkonton (**verifierat live**):

| | O63 (före) | K66 (efter) |
|---|---|---|
| Frågor | 69 | 66 |
| Cirkulära varför-svar (regeln nedan) | 3 av de 5 sämsta | **0** (14 varför-frågor) |
| Svar som säger "materialet" | 1 | **0** |
| "fjärde statsmakten" (materialet säger tredje) | fel premiss | "Varför kallas medierna den **tredje** statsmakten?" |
| Pythagoras "varför" utan bevis | cirkulärt | 0 varför-frågor i matteprovet, bara "Vad säger …", "Hur räknar man …" |
| Rousseau "varför" | upprepade frågan | "Vad menade Rousseau om makten?" |
| Protonerna "varför" | cirkulärt | "Hur många protoner har kol?" |
| Engelskprovet (D182) | svenska | **12/12 frågor och svar på engelska** |
| Frågor med visningstext (`screen`) | – | 12 (matte 6 av 8, historia 4, engelska 1, samhälle 1) |

- **Kostnad Claude:** 0,31 USD (6 prov).
- **Kostnad ElevenLabs:** 0, eftersom `/exam` aldrig anropar ElevenLabs och spara-testet använde testkonto med tyst ljud.
- **Data:**
  - `reports/qa/data/2026-11-14-202305-k66-quality.json`
  - `reports/qa/data/2026-11-14-202347-k66-quality.json`
- **Skript:** `scripts/k66-quality-check.py`, med ett testkonto per prov eftersom gränsen räknas per konto.

## Vad som ändrades (`exam/drill.ts`)
1. **Varför-frågor (prio 2).**
   - **Plan-prompten:** "Varför …?" ställs bara när materialet ger orsaken. När materialet bara säger att något är så (en regel, en lag, en definition) blir frågan "Vad …?" eller "Hur …?".
   - **Svars-prompten:** ett varför besvaras aldrig genom att upprepa frågans påstående.
   - **Granskningen i kod (`isCircular`):** ett varför-svar underkänns och frågas om när det korta svaret har färre än två nya innehållsord, eller säger "just det sambandet". Det sista försöket accepteras ändå, hellre än inget svar.
2. **Premiss och "materialet" (prio 2).**
   - **Plan-prompten:** en fråga påstår aldrig något som materialet inte säger eller som strider mot det.
   - **Svarssteget kan rätta frågan (`<may_fix>`):** en fråga vars premiss strider mot anteckningarna, eller ett varför som anteckningarna inte förklarar, får en bättre fråga i `question`, och det är den som besvaras.
   - **Bara genererade frågor rättas.** Elevens egna frågor (`drill_one`, `drill_answers`) ändras aldrig.
   - **"materialet", "i texten", "anteckningarna" och "enligt boken"** i ett svar underkänns i kod (`mentionsMaterial`), och svaret frågas om.
3. **Tillagda gruppregler (prio 3):** svars-prompten förbjuder generella regler om en hel grupp ("alla", "alltid", "aldrig", "kan alltså vara") som anteckningarna inte säger. Exemplet från O63 ("Alla föreningar kan alltså vara molekyler") står i prompten.
   - **Ingen jämförelse i kod med anteckningarna:** den skulle kräva ett modellanrop till per prov.
   - **Kemi live:** molekyl och förening förklaras utan den felaktiga regeln (**verifierat live**, 1 körning).
4. **Visningstext (prio 3).** Varje fråga och svar kan ha `screen: {question?, short?, long?}` med bara de fält som skiljer sig. Där står tal och formler som i en lärobok: 1850, 3,14, a² + b² = c², A = π · r², 5 cm.
   - **Rösten** läser alltid `question`, `short` och `long`, som har talen som ord. Ljudet påverkas inte.
   - **Var fältet finns:**
     - i `/exam` (drill, drill_answers, drill_one) som `items[].screen`
     - när det sparas med `/drill save`, i den nya kolumnen `drill_items.screen` (jsonb, migration `20261114203000_drill_items_screen.sql`, tillämpad)
     - i `get`/`status`/`list`, och följer med en kopia
   - **Live:** `save` och `get` gav `screen` tillbaka, och provet togs bort.
   - **Spärrar i kod:**
     - en visningstext som är lika med den talade texten tas bort
     - en visningstext som är mer än 1,5 gånger längre eller under en fjärdedel av den talade texten tas bort
     - lång visningstext = kort visningstext + resten (D145 även på skärmen)
   - **Angela Schrute är meddelad.** Appen ska visa `screen.question ?? question`, och likadant för `short` och `long`. När eleven ändrar ett fält skickas inte det fältets screen-värde.
5. **D182 språkämnen.**
   - **I koden:** `examLanguage(subject)` (Engelska → English, Spanska, Tyska, Franska, Italienska med flera) ger `<language>` till svarssteget.
   - **Plan-prompten:** skriver sammanfattning, anteckningar och frågor på ämnets språk.
   - **Kontrollsteget:** översätter aldrig. Svenska och alla andra ämnen stannar på svenska.

## Tester
- **611 gröna, `check` ren.**
- **Nya tester:**
  - cirkulära svar
  - "materialet"
  - rättad premiss
  - elevens fråga orörd
  - `screen` i /exam och i lagringen
  - visningstext lika med frågan tas bort
  - `examLanguage`
- **Ändrade testfakes:** de gamla testernas fejkade svar var själva cirkulära ("Kort svar på Varför A"), så de fick riktiga svar.

## Begränsningar och risker
- **En körning per prov.** Antalet frågor varierar: kemi 10 och matte 8 av 12. Matte gav färre än O63:s 12, troligen för att varför-frågorna försvann och materialet inte bär fler (**antagande**).
- **Färre varför-frågor sänker R3 något.** Jag mätte inte R3 för hand. Ordregeln räknar "Hur räknar man …" som förståelse men "Hur många …" som fakta.
- **Cirkelregeln är en ordräkning.** Ett riktigt men kort varför-svar med bara ett nytt långt ord frågas om en gång, vilket kostar några öre.
- **Den talade texten kan ha siffror** ("Hur påverkade dåliga skördar 1788 folket?"). ElevenLabs läser årtal rätt på svenska enligt tidigare lyssning (**antagande** för den här frågan, inte lyssnat på grund av D180).
- **Engelska frågor läses med den svenska rösten** (Multilingual v2 känner av språket). Hur det låter är **inte lyssnat**, eftersom D180 inte tillåter testljud. Bör höras på Arons telefon.
- **Förhandsvisningen** (K65): tillägg 20:45 på Angelas begäran (A102, 57343bd). `preview: [{question, short, screen?: {question?, short?}}]` i `publish` och `search`, **verifierat live** med testkonto, och provet togs bort.
- **Importen** (`import_text`, ChatGPT) har ingen visningstext, eftersom texten som klistras in redan är det eleven läser.

## Nästa
- **Oscar:** O64 enligt kön. Ett omtest av O63 med domaren ger siffror för hand.
- **Angela Schrute:** A102, att visa `screen`.
- **Kevin:** väntar på kö. K6 väntar på Till Aron #15, och kostnadsförslagen K64 väntar på Deangelos ja.
