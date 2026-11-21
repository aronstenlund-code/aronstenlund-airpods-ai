# T3: skärmturen röd på main – varför, och omskriven för dagens app

Toby (moln), 2026-11-20 16:10 – 2026-11-21 06:30. Uppdrag från Deangelo 16:10. Gren `toby/t3-tour`. **Simulatorn, inte enhet.** 0 ElevenLabs: turen sätter nu `LUMEN_TEST_HEADER=1` och spelar ingenting. Högst 2 macOS-maskiner (D217). T1 (ljudkedjan live) är orörd.

## Varför den faller: testet, inte appen
- Körning 44717752624 (main, 2026-11-20 10:15) visar samma sak i alla 7 konfigurationer: 12 bilder och 14 missar.
  - Missarna står i `ScreenTourTests.swift:567`, som är turens `miss()` → `XCTFail`.
  - De första missarna: "intro: 'Testa nu' not found", "'Fråga vad som helst' not shown" och "add-exam step of the first start not shown".
  - Sedan missar varje steg på Start: "Fler lägen", "Starta Lumen", "Socialt", "Rizz 18+", "Intervju", "Inställningar", "Få A-svar till provet" och "Lägg till prov".
- **Den har varit röd på main varje natt sedan 2026-11-12** (43196679068, 43579500116, …, 44717752624), alltså långt före A153 och A154. Sedan A94 (2026-11-14) är orsaken den som står nedan. Orsaken till 11–12 november har jag inte läst om.
- Orsaken är att turen följde appen före A94/A115. Den väntade på det gamla introt ("Testa nu" → "Fråga vad som helst" → lyssnande Frågor). Sedan A94 är första starten Välkommen → Fortsätt → Nytt prov → Senare, och Start är Säg i AirPods (A115). Turen nådde därför aldrig Start, och allt efter missade.
  - Det står redan i `reports/apptest/2026-11-15-1435-toby-moln-skarmturen-a94.md`. Omskrivningen sköts då upp som Beta-arbete.
- Inget app-fel hittades. Angela Fable behöver inte göra något.

## Den nya turen (bara testkod: `AppTests/E2E/Screens/ScreenTourTests.swift`, `scripts/apptest/screens.sh`)
Den går den väg en användare går i dag, med 0 uppspelningar, 0 köp och 0 lyssnande lägen:
1. **Välkommen**, två bilder → Fortsätt.
2. **Nytt prov** direkt efter Välkommen, två bilder → Senare.
3. **Start** för ett nytt konto.
4. **Säg i AirPods** med en text, med tangentbordet uppe och Spela ovanför (A153) → Klar → texten och kostnaden. Fältet töms igen efteråt.
5. **Krediter** från kapseln, två bilder (paketen, Bjud in, Så räknas det, Villkor, Integritet, Återställ köp) → Klar.
6. **Nytt prov:s formulär** (A154), två bilder → Avbryt.
7. **Hitta prov från din skola**, som är en egen sida och nås med tillbaka-knappen, och **Klistra in en länk**.
8. **Inställningar**: sex bilder av listan och varje sida en gång, med två bilder per sida.
   - Sidorna: Anteckningar, Förberedelser, Egna kommandon, Integritet, Historik, Minne, Studiekort, Feedback, Röstkommandon och Om appen.
   - Under Avancerat: Rå transkription och svar, och Diagnostik.
9. **Konto → Radera konto**: frågan "Radera kontot?" fotograferas och besvaras med Avbryt. Inget raderas.
10. **Fler lägen · Beta** öppnas bara om Start visar raden. Ett nytt konto utan prov i dag ser den inte, och det skrivs då som en anteckning, inte som en miss.

Tre saker i turen var trasiga på iOS 26, och de hittades på vägen:
- Sheetens Klar (en toolbar-knapp) är inte ett barn till navigationsfältet. Den gamla kontrollen trodde därför att Inställningar var stängt och öppnade bladet igen före varje rad, så varannan rad tappades (44787390248).
- En tillbaka-knapp vald på etiketten kunde vara Starts egen kugge "Inställningar" bakom bladet (44795539606). Nu väljs en knapp i navigationsfältets vänstra kant, och annars används ett svep från kanten.
- På iPhone SE och en gång i pro-dark (44809087832):
  - En rad längst ner i bladet räknades som träffbar, men trycket öppnade ingenting (Feedback och förslag, Om appen, Radera konto). Nu dras raden upp till mitten innan den trycks. Radera konto trycks en gång till om ingen fråga kom.
  - `swipeDown` högst upp i bladet stängde hela Inställningar, och sökningen fortsatte sedan över Start ("Integritet och samtycke not found"). Nu dras listan långsamt nedåt en tredjedel av skärmen, och sökningen stoppas om bladet stängts.
  - Varje rad i turloggen har nu sekunder sedan start, eftersom liten-light tog 76 min utan att loggen visade var.
  - Nästa försök med en kontroll av listans slut stoppade sökningen efter 2–3 svep (44846862625, 44862440315). Felet satt i testet: den första laddade cellen flyttar sig inte. Nu används samma 25 + 25 svep som i den gröna körningen. Om ett svep stänger bladet öppnas Inställningar igen och söks från toppen. Raden dras upp till mitten bara vid ett nytt försök och för Radera konto (den låg på y 811–847 av 874 i bladets nederkant).
  - Jobbets tidsgräns är höjd från 180 till 240 min. Sju konfigurationer tog över 180 min, så den sista (mikrofon nekad) hann inte köras.
- `screens.sh` skriver nu turens egna steg (tap, back, note, MISS) i jobbloggen. Artefakterna går inte att hämta härifrån, för proxyn nekar blob-värden.

## Resultat
| Körning | Konfigurationer | Resultat |
|---|---|---|
| 44717752624 (main, gamla turen) | alla 7 | röd: 12 bilder, 14 missar i var och en |
| 44761053846 | pro-light | röd: 15 bilder, 3 missar (tillbaka från Hitta prov) |
| 44764309413 | pro-light + pro-dark-storsta-text | röd: inställningsraderna (30/12 och 26/14), 49 min vid största text |
| 44787390248, 44795539606 | pro-light | röd: 10 och sedan 6 missar, se ovan |
| **44804596958** | **pro-light** | **grön: 47 bilder, 0 missar, 14 min** |
| 44809087832 | alla 7 | stoppad vid 180 min. Gröna: pro-light, pro-light-storsta-text, pro-dark-storsta-text, liten-light (76 min, men rader öppnades inte). Röda: pro-dark (Radera konto frågade inget), liten-dark (bladet stängdes). Mikrofon nekad kördes inte |
| 44835830516 | liten-dark, pro-dark, liten-light, mikrofon nekad | SE gröna båda (47 bilder, 0 missar, 13–16 min). På Pro missades Minne och Röstkommandon, och det var mitt eget fel: raden låg ovanför, och de långsamma dragen nedåt kom inte tillbaka från listans slut. Radera konto i pro-dark frågade inget, två gånger |
| 44846862625 | alla 7 | röd på Pro: Minne och Röstkommandon hittades inte (mitt fel, se ovan). SE och största text gröna |
| 44862440315 | pro-light, med felsökningsrader | trädet visade listan högst upp och sökningen stoppad efter 2–3 svep: orsaken till missarna |
| **44864538295** | **alla 7** | **grön: 47 bilder och 0 missar i alla sju, 132 min (04:07–06:19 UTC), testcommit 0b8fdf82** |

Testbeläggning (detta skrivs med bilder i CI, **Simulatorn, inte enhet**):
- **Verifierat i CI-loggen:** alla 47 steg nåddes i alla sju konfigurationer (iPhone 17 Pro och iPhone SE 3, iOS 26), ljust och mörkt, största text och mikrofon nekad. Frågan "Radera kontot?" kom och fick Avbryt, och inget raderades.
- **Inte sett:** själva bilderna. Artefakten `apptest-screens` går inte att hämta härifrån, för proxyn nekar blob-värdet. Avvikelser mot skisserna är därför inte granskade i den här omgången.
- **Untested assumption:** på SE står "Om appen tap missed, retry 1–3" i båda körningarna. Bilden `…-om-appen` på SE kan därför visa listan i stället för sidan. Den räknas inte som miss, eftersom tillbakavägen fungerade.

## Sammanslaget
`toby/t3-tour` är ihopslagen med main (merge-commit med `[skip ci]`) när inget main-bygge körde. Nattkörningen 02:30 UTC kör nu den nya turen. Jobbets tidsgräns är 240 min, och hela turen tar cirka 130 min.

## Kvar
- En snabbare väg till Om appen på SE, så att bilden säkert är sidan. Den kan man se i artefakten.
- Lyssningslägena (Frågor, Provläge, Intervju, Socialt) finns inte i turen. De nås bara via Fler lägen · Beta, som ett nytt konto inte ser. Om Deangelo vill ha dem med behövs ett prov först (som T24 gör) eller en scen hos Angela Schrute. De lyssnar dessutom, så de är inget för en tur utan ljud.
