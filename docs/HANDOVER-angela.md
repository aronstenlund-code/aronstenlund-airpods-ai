# Överlämning: Angela (app), 2026-11-10 kl. 22.58

Den här sessionen har gjort 30 punkter i dag. Alla är gröna i CI, men ingen är provad på telefon. Rapporterna finns i
`reports/2026-11-10-angela-a*.md`.

**Punkterna:**
- A16–A30;
- A33–A37, A39–A42, A45 och A46.

**Kvar i kön (`prompts/queue/angela.md`):** A3 väntar på K6:s hemlighet. Det mesta finns redan i A26:s röstsida.

**Klart i kväll (2026-11-10, 19:27–22:58):** A46 vändkort, A48 `qa_log` till K30, A38 streak och daglig påminnelse
(K31), A43 "% redo"-ring (K33), A44 hemskärmswidget. Widgeten kräver appgruppen `group.com.rsolutions.lumen`, som
troligen saknas i det osignerade Sideloadly-bygget. `AnswerContext.clamped` bygger om sammanhanget: ett nytt fält
måste läggas till där, annars tappas det (A48).

## Det här står inte i rapporterna
- **Ingen Mac.** CI (`ios-build.yml`) är kompilatorn och tar 15–25 minuter. Hjälpskripten finns i scratchpad-mappen
  `ci/`: `ghapi.sh`, `waitsha.sh` och `waitrun.sh` (se minnet `lumen-project-setup`).
  - En push som rör app-kod avbryter körningen som pågår, också när någon annan pushar. Pushar som bara rör dokument
    startar ingen körning.
  - Skärmbilder tas med `screenshots.yml` (workflow_dispatch med `device`). Dessa scener finns:
    - intro och first;
    - home och empty;
    - addExam och addExamFirst;
    - listening och listeningProv;
    - practice och practiceResult;
    - voice, settings, about och resten.
  - `ListeningModel.screenshotShows` (bara i Debug) visar Lyssnar som när appen lyssnar.
- **Swift-fällor som har kostat CI-rundor i dag:**
  - **Statiska hjälpfunktioner i vyer:** tester anropar dem utanför MainActor. Märk dem `nonisolated`, eller märk
    testsviten `@MainActor`.
  - **`#require` och `#expect`:** ett muterande anrop får inte stå inne i dem. Lägg resultatet i en `let` först.
  - **`switch` som implicit returvärde:** efter en `if` krävs `return switch`.
  - **Testernas falska uppspelning:** den rapporterar aldrig att den är klar. Den riktiga vägen väntar då upp till 30 s
    på att mikrofonen öppnas. Styr spärren direkt i testerna.
- **Delat index:** andra sessioner får ibland med dina ostagade ändringar i sina commits.
  - Committa med `git commit -- <filer>`.
  - Synka med `git fetch origin main && git rebase --autostash origin/main`.
- **Klockan:** skriv tider i kön och på tavlan från `date`, inte uppskattade. Jag skrev en stund 1–3 timmar för tidigt
  och rättade det i `c3f078b`.
- **Python-patchar:** skriv skriptet med Write-verktyget till scratchpad och kör det med `python -I`. Heredocs med `'''`
  och `\(` krånglar i bash.

## Öppna trådar
- **Tobys tester:** han behöver köra om T3 och T8. De här texterna i appen har ändrats:
  - samtycket är på svenska;
  - Rizz heter "Rizz", utan 18+;
  - Frågor heter Standardläge;
  - introt har en fjärde punkt;
  - första starten går vidare av sig själv och frågar om provet med rösten;
  - "Skriv i stället".

  Han har också `listeningEventObserver` (A29) för att vänta på mikrofonen och Mer?-fönstret.
- **Kelly:**
  - Granska A46 med nya bilder: `reports/2026-11-10-a46-skarmbilder/`.
  - Ändra på demosidan: Standardläge, ingen 18+, och introts fjärde punkt.
  - Välj ljuden för A34.
  - Hennes fynd 6, att "Lägg till prov" har 19 val, är inte gjort. Snabbformen saknar fältet för provets innehåll, och
    det fältet behövs för studieplanen (A19).
- **Kevin:**
  - `description` i `/voices` (A26);
  - ett begrepp per förhörsfråga, `done.concept` (A19);
  - en gemensam lista över känsliga ord (A27/A35);
  - `parse` med en lärobokssida (A36);
  - K30:s text om att samtycket gäller 14 dagar (A41).
- **Aron:**
  - välja tid för påminnelserna (A19, nu kl. 16);
  - välja logga;
  - pröva A40 med flygplansläge;
  - samtycket visas en gång till för honom (version 5).
