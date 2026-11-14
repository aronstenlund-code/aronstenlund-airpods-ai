# K58 och K59: ChatGPT-prompten, import_text, lagringen, H-1–H-5 och empty_answer (Kevin, 2026-11-14 10:04)

## Kort
- **K58 klar.** Prompten ligger i `Shared/chatgpt-prompt.txt`, och tolken är `POST /drill {"action":"import_text"}`. Tolken gör inget Claude-anrop och kortar ingenting. **Verifierat live:** Claude i ChatGPT:s ställe gav 10 frågor, och alla 10 lästes in (200). Vanlig text utan formatet gav 422 med de rader som inte gick att läsa.
- **K59 klar.** Lagringen räknas varje morgon klockan 06:30 av flödet "Storage report (K59)" och skrivs till `reports/storage/latest.md`. Vid 70 % av 1 GB lägger flödet själv en rad i Till Aron. **Läget i dag (verifierat i databasen):**

  | Vad | Använt | Gräns | Andel |
  |---|---|---|---|
  | drill_audio | 15,9 MB i 114 filer | 1 GB | 1,6 % |
  | Databasen | 30,6 MB | 500 MB | 6,1 % |
- **Kellys H-1–H-5** är rättade i `docs/HJALP.md` och i serverns kopia.
- **Tobys `empty_answer` (w22, Grönland):** jag kunde inte återskapa felet i 16 livekörningar, men felet går nu inte att få längre. Om svaret blir tomt frågar servern en gång till utan verktyg och utan markörer, innan appen någonsin får `empty_answer`. Skälet loggas (bara antal).

## K58: prompten och tolken (D169)
- **Prompten** är en enda svensk text med fyra fält som appen fyller i: `{{AMNE}}`, `{{ARSKURS}}`, `{{ANTAL}}` och `{{FRAGOR}}`. Den säger åt ChatGPT att:
  - läsa alla bifogade filer och de övade frågorna, och bara bygga på dem
  - göra så många frågor som appen har fyllt i, eller färre om materialet inte räcker
  - hålla frågorna korta, helst högst 5 ord, och fråga efter förståelse
  - skriva svar på cirka 90 ord (minst 80), där första meningen ensam är ett fullgott kort svar på högst 25 ord
  - inte använda markdown eller listor
  - svara **bara** som `Fråga: …` / `Svar: …` med en tom rad emellan
- **Tolken `import_text`** ligger i `/drill`, bredvid `save`. Appen tolkar först och sparar sedan som vanligt.
  - **Kortar ingenting:** det korta svaret är svarets första mening ordagrant, och det långa är hela svaret (D145).
  - **Klarar det ChatGPT ändå brukar lägga till:** inledning, `**fetstil**`, "Fråga 1:", "1. Fråga:", svar över flera rader och CRLF. Förkortningar som t.ex. och ca. samt decimaltal bryter inte första meningen.
  - **Rader som inte gick att läsa** returneras med radnummer och skäl, så att appen kan visa dem (A93).
  - **Varningar:** en första mening över 25 ord, eller en fråga över 8 ord, flaggas men behålls.
  - **Gränser:** 20 per minut och 200 per dygn. Ingen kostnad utöver ljudet, som räknas i 15 per månad (D155) när provet sparas.
- **Kontraktet** finns i `backend/README.md`, avsnittet "Gör med ChatGPT".
- **Test av mallen:** mallen fylldes i med material från Oscars testprov `bio-ak8-fotosyntes` och två övade frågor. En separat Claude-session svarade som ChatGPT. Resultat:

  | | Resultat |
  |---|---|
  | Inlästa frågor | 10 av 10, 0 överhoppade, 0 varningar |
  | Ord per fråga | 3–5 |
  | Första meningen | 11–23 ord |
  | Hela svaret | 70–78 ord |

  Svaren blev kortare än 90 ord, så prompten säger nu "minst 80". Det ändrade är **inte provat**. Med riktiga ChatGPT är det en **otestad antagelse**: Oscar provar i O58.

## K59: lagringen
- **Underlag:** den nya funktionen `drill_storage_stats()` (bara tjänstenyckeln) räknar byte per dag och totalt i Storage, plus databasens storlek. Migrationen är `20261114100000_drill_storage_stats.sql`.
- **Varje morgon:** `scripts/storage-report.py` och flödet `.github/workflows/storage-report.yml` skriver `reports/storage/latest.md`, plus en rad per dag i `history.tsv`. Vid 70 % läggs en rad i `docs/TILL-ARON.md`, bara en gång, med klickvägen till Pro (25 USD/mån, 100 GB).
- **Takt:** en ljudfil är i snitt 139 kB, alltså cirka 280 kB per fråga (fråga och långt svar). 1 GB räcker då till cirka 3 600 unika frågor, eftersom samma text delar fil mellan konton (D144). Med 15 frågor per konto och månad nås 70 % efter ungefär 170 kontomånader med full kvot, till exempel 85 aktiva konton i två månader.
- **Förslag, inte byggt: regel för gammalt ljud**
  1. Ett prov är gammalt när ingen har spelat det på 90 dagar och det varken är delat (en aktiv kod) eller publicerat.
  2. Då tas bara de ljudfiler bort som inga andra prov använder. Filerna delas mellan konton via sin hash, så en fil får bara raderas när ingen rad i `drill_items` pekar på den.
  3. Frågorna och svaren behålls. Ljudet görs om när provet spelas nästa gång, och det räknas inte mot kvoten, eftersom användaren redan har betalat för det.
  4. **Det som saknas:** en kolumn `drills.last_played_at` som appen uppdaterar. I dag räknas spelningar bara för publicerade prov. Behöver ett beslut av Deangelo.

## Kellys H-1–H-5 (Ke57-granskningen)
- H-1 "Lägg till dokument"
- H-2 Dela-symbolen uppe till höger
- H-3 "Rapportera" längst ner
- H-4 "Provläge (förhör med rösten)"
- H-5 "Visa ett användarnamn", och skriv inte ditt riktiga namn

Ändrat i `docs/HJALP.md` och synkat med `scripts/sync-hjalp.py`. Testet `hjalp_test` är grönt. HJALP.md säger ännu inget om "Gör med ChatGPT", och det läggs till när A93 finns i appen.

## Tobys empty_answer (T17 w22)
- **Loggen 23:29:24 (UTC):** frågan markerades för webbsökning (`search_marked`). Det gav 16 425 tokens in och 367 ut, men ingenting som gick att läsa upp, och då `empty_answer`.
- **Försök att återskapa:** 16 livekörningar, alla med svar.

  | Variant | Med Provläge (tutor) | Utan |
  |---|---|---|
  | "hur stor/stort är Grönland" | ✓ | ✓ |
  | Med föregående fråga om ljuset i historiken | ✓ | ✓ |
  | Med webbsökning | 4 av 4 svarade | |
- **Rättat:** när ett svar på en riktig fråga blir tomt, efter sökning eller utan, frågar servern en gång till utan verktyg och utan sökmarkör. Modellen ombeds svara med vad den vet i en eller två meningar och skriva "cirka" när den inte är säker på ett tal.
  - Bara när det fortfarande är tomt får appen `empty_answer`.
  - Tysta lägen (tutor och auto med tystnad) berörs inte.
  - Loggen `empty_retry` visar läge, försök och om sökning gjordes, aldrig text.
- **Status:** test i koden **verifierat**, med 562 gröna tester. Hur det blir i appen är en **otestad antagelse** tills Toby kör om T17.

## Tester och kostnad
- **Tester:** `deno task test` ger 562 gröna (6 nya), och `check` är ren. `import_text` är verifierat live.
- **Kostnad Claude:** cirka 0,01 USD i livekörningar. Själva mallprovet gjordes i en Claude-session, inte via API:t.
- **Kostnad ElevenLabs:** 0 tecken.

## Nästa
- **Angela (A93):** kontraktet finns i README.
- **Oscar (O58):** prova prompten med riktiga ChatGPT.
- **Toby:** kör om T17.
- **Deangelo:** ta ställning till `last_played_at` och regeln för gammalt ljud.
- **K6** väntar fortfarande på Till Aron #15.
