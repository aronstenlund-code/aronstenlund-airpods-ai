# T24: hela repetitionsflödet som ny användare, grön körning

Toby (moln), 2026-11-15 03:20–06:55. Tar över efter Toby 2 (`reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`, fynd
L1–L6 och V1–V4). Simulatorn i GitHub Actions, två simulatorer (iPhone 17 Pro och iPhone 17, iOS 26). **Inte verifierat på
enhet.** Falskt ljud via `LUMEN_TEST_HEADER` (x-earmind-test, D180). **0 ElevenLabs.**

## Resultat: körning 43678600052, grön (toby/t24 8b2d10d = b903f59 + main e06d0d8, med Angela Schrutes 8a521b1)
**Fas a** (konto A), 39 tryck, 22 skärmar:

| Steg | Tid | Tryck |
|---|---|---|
| Första starten → Fota sidor → Välj bilder → Skapa frågor → Ser rätt ut → Starta prov → första frågan | 169 s | 10 |
| Frågor och svar och en fråga | 12 s | 3 |
| Gör med ChatGPT | 32 s | 5 |
| Dela | 107 s | 2 |
| Publicera prov (Central insamlingsenhet, Kiruna) | 83 s | 10 |
| Mina svar (se fynd T24-M1) | 58 s | 3 |
| Väntar på att konto B hittar provet | 10 s | 0 |
| Ta bort publiceringen och provet | 55 s | 6 |

**Fas b** (konto B), 17 tryck:

| Steg | Tid | Tryck |
|---|---|---|
| Första starten utan prov | 10 s | 2 |
| Prov från din skola → A:s prov → Lägg till i mina prov | 152 s | 5 |
| Läget `slow` | 132 s | 5 |
| Läget `unavailable` | 104 s | 5 |
| Proven finns kvar efter två omstarter (D183) | 82 s | 0 |

- **Städningen fungerar.** "Publiceringen är borttagen." och provet borta. `drill_publications` för skola 35374123 har
  efter körningen bara Toby 2:s två kända rader (36a3f569…, 49e29092…), som väntar på Arons besked (Till Aron #21).
  *Verifierat i databasen.*
- Tidigare röda körningar var simulatorn ("Failed to get background assertion", 43664448952) och testet: larmet Okej
  efter Ta bort publiceringen täckte Mer, och Mina svar fanns inte. Båda är rättade i testet.

## Omtest av Angela Schrutes 8a521b1 (L2, L3, L5, L6)
- **L2 rättad:** ett prov från Gör med ChatGPT heter efter första frågan ("Vad behöver växter för fotosyntesen"), inte
  "Nytt prov". Sett i 43674540972.
- **L3:** ingen rad om "1 rad kunde inte läsas" i stegloggen. Hittade 3 frågor med ChatGPTs inledning. *Bara loggen, inte
  bilden.*
- **L5 inte rättad i testet:** i läget `unavailable` syns "Ljudet kan inte göras just nu" inte på Start inom 40 s, i tre
  körningar av tre (43674540972, 43678600052 och 43664448952 före rättningen). Till Angela Schrute med frågan i
  hennes rapport: testet läser Start i 40 s efter en omstart. Raden kanske bara visas på provets skärm eller i spelaren.
- **L6:** i läget `slow` såg testet en rad om ljudet på Start. Testet skriver ingen anteckning när en rad finns, men
  ordalydelsen står bara i hela stegloggen (artefakten). *Untested assumption* att det är "Ljudet dröjer".

## Fynd (nya)
| Id | Vad | Till |
|---|---|---|
| T24-M1 | **Mina svar och repetitionsprovet hänger inte ihop.** Efter ett prov i repetitionsflödet visar Provläge (Fler lägen) ändå "Har du prov snart? Lägg till prov", och Mina svar (Spela in eget svar) finns först när ett prov har lagts till där. En ny användare som har gjort ett prov hittar inte Mina svar. Samma sak som V4 från logiksidan. | Angela Schrute (logik), Angela Fable (V4) |
| T24-V2b | V2 kvar och nu två larm: "Publicerat." **och** "Publiceringen är borttagen." med Okej. Sidan säger det redan i en rad. | Angela Fable |

## Kvar sedan Toby 2 (inte omtestat här)
- V1, V3, V4 (Angela Fable, A104 pågår).
- "Dela" visar inget delningsblad med Kopiera i simulatorn. Sannolikt simulatorn, *untested assumption*.
- "Provdatum: dagen 22 november hittades inte i kalendern." Sannolikt testets sätt att leta i kalendern, inte appen (*untested assumption*); provet publicerades ändå med ett datum.
- 1, 2 och 3 tryck går inte att skicka från ett UI-test. Krok begärd av Angela Schrute (se T27-rapporten).

## Nästa
- Kör `apptest-fullflow` igen efter A104 (V1–V4) och efter Angela Schrutes svar om L5. Testet är på main nu; en push till
  `toby/**` som rör de tre filerna startar det.

## Tillägg 2026-11-15 09:05: omtest efter Angela Schrutes 60d83ce (L5, L6, M1)
Körning 43687320010 (toby/t24b = main 71a610c + unik text i lägena slow och unavailable, som Angela Schrute föreslog):
- **L5 rättad:** i läget `unavailable` gick provkortet på Start från "3 frågor · Ljud: 0 av 6 klara" till **"3 frågor ·
  Ljudet kan inte göras just nu"** inom testets 40 s, för frågorna märkta "test 727778 unavailable". *Verifierat i simulatorn.*
- **L6:** läget `slow` blev rött på testets sida ("Gör med ChatGPT" fanns inte efter Nytt prov en gång). Rättat i testet,
  och fas b körs om ensam (workflow_dispatch, `phases: b`).
- **M1 (D189) rättad:** Mina svar finns nu i Provläge efter ett prov i repetitionsflödet, och testet når Mina svar.
- **Nytt, litet (till Angela Fable):** i Mina svar → Spela in ligger **"Spela in svaret" utanför skärmen**. Testet
  svepte 6 gånger och knappen gick ändå inte att trycka. Samma sak med Avbryt i det bladet. iPhone 17 Pro, standardtext.
  Kan vara testets svep i ett blad. *Untested assumption* att det är vyn.
- Fas a grön (8/8), publiceringen borttagen. `drill_publications` har bara de två kända raderna. *Verifierat i databasen.*

## Tillägg 2026-11-15 10:05: fas b ensam (43692170302), grön 4/4
Körd med `workflow_dispatch` och `phases: b` (fas b ensam hoppar nu över skolan, `LUMEN_T24_SOLO`). Unik text per läge.
- **`slow`:** kortet gick från "3 frågor · Ljud: 0 av 6 klara" till "3 av 6 klara" inom 40 s. "Ljudet dröjer" kom
  inte, vilket stämmer med L6: raden kommer först efter 20 s utan nytt ljud, och här kom ljudet hela tiden. Om raden
  syns vid ett riktigt stopp är *inte prövat* (läget `slow` gör ljudet långsamt men stoppar inte).
- **`unavailable`:** "0 av 6" → "3 av 6" → **"Ljudet kan inte göras just nu"** (L5, rättad).
- D183: proven kvar efter två omstarter.
- Testets ändringar (unik text, ny öppning av Nytt prov, fas b ensam) ligger på main.

## Tillägg 2026-11-15 16:55: grön i båda faserna efter A107, Spela in svaret och L6 (43726770508)
Grenen toby/t24c med main efter A106/A107 och Angela Fables V4.
- **Fas a grön 8/8, 39 tryck.** Mina svar → Spela in → Välj ur provet → **första frågan** → Spela in svaret. iOS frågade
  om mikrofonen och taligenkänningen, och inspelningen och Klar gick igenom (falskt transkript). Angela Fable hade rätt:
  det var mitt test som inte valde någon fråga, så bladet täckte knappen. Publiceringen och provet borttagna. Inga nya
  rader i `drill_publications`. *Verifierat i databasen.*
- **Fas b grön 5/5.** Efter A107 görs inget ljud före Starta prov, så testet startar provet i lägena:
  - `slow`: spelaren visar "Gör ljudet … 3 av 6 klara", och Start säger sedan **"3 frågor · Ljudet dröjer"**. L6 är
    alltså sett.
  - `unavailable`: spelaren visar **"Ljudet kan inte göras just nu. Försök igen om en stund."**, och kortet säger
    detsamma (L5).
- **Litet (till Angela Schrute, inte omtestat):** i körning 43719904826 stod det på kortet för ett ostartat prov
  "3 frågor · Ljud: 0 av 6 klara" en kort stund, innan raden blev "Ljudet görs när du startar". Det syntes en gång,
  inom 40 s efter omstarten.
- Kvar som förut: Dela visar inget delningsblad med Kopiera i simulatorn. Dagen "22 november" hittas inte i
  kalendern (testets sätt att leta).

## Tillägg 2026-11-16 03:20: anpassad till A110, grön
Körning 43787584924 (toby/t24d, 77d367c7) är grön i alla 13 delar, både fas a och b (**verifierat i Simulator**, inte på enhet). Två ändringar i testet:
- Dela och Publicera finns bara på startade prov (A110), så testet startar provet på provets egen skärm först.
- När provet har fått ett datum visar Start kortet "NÄSTA PROV" med knappen "Ändra …" i stället för "Frågor och svar". Städningen går nu den vägen, och testet tar sig tillbaka till Start från "Fler lägen".

Körningens publicering togs bort. Den röda körningen 43782880704 lämnade kvar publiceringen 3afc21d0 (01:25 UTC) hos Central insamlingsenhet. Den tas bara bort på Arons ja. Testet ligger nu på main och körs i nattflödet.
