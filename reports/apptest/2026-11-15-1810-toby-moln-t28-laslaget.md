# T28: läsläget i appen, blockerat av /exam read (422)

Toby (moln), 2026-11-15 14:40–18:10. Simulatorn i GitHub Actions (iPhone 17 Pro, iOS 26). **Inte verifierat på enhet.**
Falskt ljud (D180, `LUMEN_TEST_HEADER`), tryck via Angela Schrutes krok (`LUMEN_TEST_PRESSES`). **0 ElevenLabs.**

## Testet (på grenen toby/t28, inte på main)
`AppTests/E2E/Screens/ReadingFlowTests.swift`, `scripts/apptest/reading.sh` och `.github/workflows/apptest-reading.yml`.

Stegen:
1. Nytt prov → Läs upp texten → material → Skapa uppläsning → Ser rätt ut.
2. Spelaren: 1 tryck pausa och fortsätt, 2 tryck nästa mening, 3 tryck förra meningen, tryck på en mening.
3. Avsluta och platsen på Start.
4. Utan nät: omstart, platsen kvar och Fortsätt.

Appens rader "Reading: …" i loggen visar vad spelaren gjorde.

## Hur långt det kom (7 körningar)
| Körning | Stopp | Var felet låg |
|---|---|---|
| 43719634329 | Simulatorn startade inte appen | simulatorn |
| 43719634329 (2) och 43724201975 | Skriv text har inget tangentbordsfokus, `typeText` stoppar testet | testet (simulatorn, samma som i T21) |
| 43726716738 | Menyns ikon "Klistra In" tryckt i stället för menyvalet | testet |
| 43729359230 | Väntade på Skapa frågor, men i textläget heter knappen Skapa uppläsning | testet |
| 43731914476 | Bildbiblioteket utan rutnät | testet/simulatorn |
| 43734582143 och 43737115752 | **Materialet kom in via Välj bilder och Skapa uppläsning trycktes, men `/exam read` svarade 422** | **servern** |

## Fynd K-T28 (till Kevin)
- **Vad som händer:** `/exam` med läsläget (K70, `read.ts`) svarar **HTTP 422 `drill_unreadable`** på bilden som
  `/exam` för frågor läser utan problem.
  - Samma bild gav 3 frågor i T24 i dag (43726770508).
  - Bilden görs av `scripts/apptest/material_png.swift`: en PNG med ett stycke på cirka 200 tecken, "Fotosyntes.
    Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre
    bildas och släpps ut. Sockret ger växten energi och byggmaterial."
- **Appens logg:** `exam read: HTTP 422, 527899 bytes sent, 3980 ms` (16:59:07 UTC). Serverloggen har `POST | 422 |
  /functions/v1/exam` (16:32:26 UTC i körningen före).
- **Trolig orsak:** `read.ts` rad 221 kastar 422 när `parseRead` inte hittar något stycke (`kind === "para"`) i
  modellens svar. Modellen svarade alltså något som inte tolkades som stycken. Det kan vara formatet, eller att ett
  så kort material blir bara en rubrik. *Untested assumption*: jag ser inte modellens svar.
- **Appen gör rätt:** Nytt prov säger "Det gick inte att läsa materialet. Fotografera rakt ovanifrån i bra ljus, eller
  klistra in texten." och visar Försök igen. Inget fynd till Angela.

## Inte prövat än
1, 2 och 3 tryck i läsläget, tryck på en mening, platsen efter omstart och läsläget utan nät. Allt väntar på K-T28.

Det går fort att köra om när Kevin har rättat:
- en push till `toby/t28`, eller
- `workflow_dispatch` av `apptest-reading.yml` på `toby/t28` (cirka 25 minuter).

## Om simulatorn
Skriv text går inte att fylla i från XCUITest: fältet får inget fokus och inklistringen fastnar inte. Testet använder
därför bilden. *Verifierat i simulatorn*, inte ett fel i appen på telefon (Aron skriver där).

## Rättelse 2026-11-15 19:55: fyndet K-T28 var mitt testfel
Alla T28-körningar skickade **527899 byte** till `/exam read`: 422-körningarna, 200-körningen och 422 i dag 18:37:18 UTC.
Testet har hela tiden valt iOS exempelfoto med ett vattenfall, aldrig materialbilden. Den första 422 var alltså **rätt**
svar på ett foto utan text.
- Kevins reserv (6430d5d) gjorde att vattenfallet beskrevs i stället. Det blev hans T28b, rättat i 367eaf5, så ett
  foto utan text ger åter 422 och räknas inte mot kvoten.
- Kevin är meddelad.
- Testet väljer nu rutan i rutnätet som inget exempelfoto täcker. Vår bild är inget `Image`-element (T24).

Det som fungerade i 43740301853, då texten blev bildbeskrivningen på 2 meningar:
- platsen på Start ("Du var på mening 2 av 2") efter Avsluta;
- efter omstart utan nät finns platsen kvar, och Fortsätt läser från mening 2;
- 1 tryck pausar;
- i slutet stannar 3 tryck på sista meningen och 1 tryck blir Börja om (D188).
