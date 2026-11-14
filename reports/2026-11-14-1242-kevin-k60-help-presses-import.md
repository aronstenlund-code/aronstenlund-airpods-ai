# K60: trycken i hjälp-AI:n och importens fynd (Kevin, 2026-11-14 12:42)

## Kort
- **(1) Hjälp-AI:n:** trycken står nu uttryckligen som "1 tryck = det långa A-svaret. 2 tryck = det korta A-svaret, en till två meningar. 3 tryck = paus." Det gäller i `docs/HJALP.md`, i den fasta texten och i `/help`-prompten. **Verifierat live (Oscars `scripts/qa/o58_help.py`, läst för hand):**

  | | Körning 3 | Körning 4 |
  |---|---|---|
  | Hur gör jag | 30/30 | 30/30 |
  | Utanför appen | 10/10 | 10/10 |
  | Knepiga | 4/4 | 4/4 |
  | Påhittade funktioner | 10/10 säger att det inte finns | 10/10 |
  | Förbjudna ord, för långa svar, fel | 0 | 0 |

  Skriptets egen nyckelordskontroll ger 28/30, eftersom den letar efter "1 gång" och "ändra". Den nya trycktexten säger "1 tryck", och borttagning görs med att svepa.
- **(2) Importen:** `import_text` följer de regler Angela och jag har kommit överens om (A96). Båda sidor läser samma fixtur, `testdata/import/o58-cases.json`, som Angela genererar ur Oscars `variants()`. **Verifierat:** 20/20 i Deno-testet och 20/20 live med Oscars `scripts/qa/o58_import.py`.

## (1) Hjälp-AI:n (Oscar O58 fynd 1–5)
- **Trycken (fynd 1, prio 1):**
  - Raden "Medan frågan spelas: …" är nu den uttryckliga texten ovan.
  - En ny rad förklarar att det långa A-svaret kommer med 1 tryck och det korta med 2. Den säger också att trycken fungerar under betänketiden (spec R2) och att svaren aldrig läses upp av sig själva.
  - Frågor om att höra, få eller lyssna på det långa eller korta svaret får nu den fasta texten i kod. Exempel: "hur får jag det långa svaret", "hur får jag höra svaret", "vilka tryck finns det".
  - Felsökning ("kommer inte fram", gamla AirPods) går som förut till modellen.
  - Prompten säger "Never swap them" och att "A-svaret" ensamt betyder det långa svaret.
- **Samtal (fynd 2):** HJALP.md säger att provet inte fortsätter av sig självt när samtalet är slut, utan när du trycker igen. 6 av 6 svar var rätt i körning 3 och 4.
- **Påminnelser och funktioner som inte finns (fynd 3–4):** ett nytt avsnitt, "Det här finns inte i Earmind", listar:
  - egna studiepåminnelser (med en hänvisning till Standardläget i beta)
  - flerval, svårighetsgrad, att hoppa över en fråga eller gå tillbaka
  - export, PDF, Google-inloggning, egen röst och Android

  Prompten säger att frågor om att göra något i Earmind alltid har `in_scope: true`. Resultat: "byta språk" och "flervalsfrågor" får nu "Det här finns inte i Earmind …" i stället för "Det kan jag inte svara på.".
- **Knappar som inte finns (fynd 5):** HJALP.md beskrev appen fel. Det fanns ingen knapp **Ändra**, och det rättade jag efter `Lumen/Features/Repetition/DrillView.swift`:
  - Man ändrar en fråga genom att trycka på den.
  - Man tar bort en fråga genom att svepa åt vänster och trycka **Radera**, eller under **Ändra ordning** med den röda knappen. Inne i frågan finns ingen knapp för att ta bort den.
  - **Ändra ordning** finns i menyn med tre punkter.
  - Menyn har bland annat Ändra ordning, Publicera prov och Ta bort provet. Där går ämne och årskurs inte att ändra, utan det görs under **Stämmer det här?**.
  - Rutan heter **Vilken årskurs?** (A88).

  Prompten förbjuder också knappar, gester och inställningar som inte står i texten. Att iOS visar "Radera" på svenska vid svep är **verifierat i docs** (systemets text för `.onDelete`), inte på telefon.
- **Spotify:** raden säger nu "då går trycken till den appen i stället för till Earmind".
- **Ingen inledningsrad före stegen:** "Så här börjar du:" före "1." tas bort i kod, så att 5 steg håller sig inom gränsen.
- **Status:** körning 1 och 2 (före de två sista rättningarna) hade ett fel var.
  - Körning 1: årskursen rättades via en påhittad "Ändra" i menyn.
  - Körning 2: man kunde ta bort en fråga "inne i frågan".

  Båda är rättade i HJALP.md. Körning 3 och 4 är 30/30 för hand. Den allra sista ändringen, raden om betänketiden, är **inte** omkörd.

## (2) Importen (Oscar O58 fynd 6–9, A96)
Gemensamma regler med Angela, som också står i `backend/README.md`:

| Regel | Vad tolken gör |
|---|---|
| 1. Svar i flera stycken | En tom rad avslutar inte svaret. Styckena slås ihop med mellanslag fram till nästa fråga. Ett eget stycke efter **sista** svaret som slutar på ? eller ! är prat från ChatGPT: det hamnar i `skipped` ("Avslutning, inte en del av svaret.") och ger en varning. |
| 2. Rubriker och formatering | "# …", "Fråga 2" utan kolon, kodblock och linjer (---, ***, ===) blir aldrig svarstext. De hamnar i `skipped` med radnummer och avslutar svaret. |
| 3. Fråga utan etikett | En rad som slutar på ? direkt före "Svar:" blir frågan, med varningen "Frågan saknade Fråga:.". |
| 4. Inget kortas | Över 3 000 tecken: varning. Över 4 000 tecken: `skipped` med "Svaret är för långt", i stället för att svaret kortas. `save` tar nu `long` upp till 4 000 tecken. ElevenLabs-kostnaden (D120) är skälet till taket. |
| 5. Dubbletter | Behålls, med varningen "Samma fråga som på rad N.". |

**Live:** 20 av 20 varianter är hela rätt, inklusive svar i två stycken, rubriker och en fråga utan etikett. Data: `reports/qa/data/2026-11-14-122807-o58-import.json`.

## Tester och kostnad
- **Tester:** `deno task test` ger 584 gröna, 22 fler än förra rapporten: 20 fixturfall och 2 regeltester. `check` är ren.
- **Kostnad Claude:** cirka 0,17 USD för sex körningar av Oscars 54 hjälpfrågor. Importen kostar 0 eftersom den inte anropar Claude.
- **Kostnad ElevenLabs:** 0 tecken.
- **Körningsfiler:** körningarna skrev sina filer i `reports/qa/data/` (Oscars skript skriver dit), med tid 1223–1243.

## Nästa
- **Oscar:** kör om O58 för att få en oberoende bedömning.
- **Angela:** Swift-sidan mot samma fixtur (A96).
- **Riktiga ChatGPT:** ett svar är fortfarande inte provat.
- **K6** väntar fortfarande på Till Aron #15.
