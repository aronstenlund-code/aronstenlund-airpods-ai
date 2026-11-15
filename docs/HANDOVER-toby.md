# Överlämning Toby 2 (repetitionsläget) till molnet, 2026-11-15 02:48
Lokala sessionen "Toby - repetion" lämnar över till "Toby (moln)". Allt nedan är kontrollerat 02:48 mot origin
och databasen. Simulator, aldrig enhet.

## Klart (rapporter på main)
- **T18 + D163/D164:** repetitionsspelaren i simulatorn, med paus 5 s, 5 min och 30 min.
  `reports/apptest/2026-11-14-0952-toby2-t18-d163-d164.md`
- **T21:** ny användare i A94:s första start. `reports/apptest/2026-11-14-1348-toby2-t21-ny-anvandare.md`
- **T23 + T22:** A99/A100 och EarMind. `reports/apptest/2026-11-14-1813-toby2-t23-t22.md`
- **A95 åt Angela Fable:** `apptest-a11y.yml`, gratis. Hon kör den själv.
- **Workflows på main:**
  - `apptest-repetition.yml` (T18; indata `pauses`, t.ex. `300,1800`)
  - `apptest-newuser.yml` (T21/T23 flödet; en push till `toby/**` stannar före Ser rätt ut, en manuell körning
    med `stop_after: none` sparar ett prov)
  - `apptest-states.yml` (T23/T22 i Debug-scener, gratis)
  - `apptest-a11y.yml`

## Pågår: T24 (hela flödet), inte på main
- **Kod:** grenen `toby/t24` = **b903f59**. Filerna `AppTests/E2E/Screens/FullFlowTests.swift`,
  `scripts/apptest/fullflow.sh` och `.github/workflows/apptest-fullflow.yml`.
  - Två simulatorer, fas a och b samtidigt.
  - A publicerar på "Central insamlingsenhet", Kiruna (ett kontor utan elever). Sedan väntar A på B:s
    `t24-found.txt`, och tar till sist bort publiceringen och provet själv.
- **Rapport:** `reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`, med fynd L1–L6 till Angela Schrute och
  V1–V4 till Angela Fable (båda har fått dem i sessionen).
- **Bästa körningen:** 43661618294. Allt gick utom "Mina svar" (bakom Starta EarMind, med mikrofonen) och städningen.
- **b903f59 är inte körd.** Den bekräftar Ta bort i dialogen och trycker aldrig på en knapp som inte går att trycka.
  Den körningen som pushen startade avbröts med avsikt.
- **Kvar för att stänga T24:**
  1. Arons besked om de två kvarlämnade testpubliceringarna (se nedan).
  2. En körning av b903f59, där publiceringen ska vara borta efter fas a (kolla `drill_publications`).
  3. Slå ihop de tre filerna till main, och kryssa T24 i kön.

## Kvar i databasen (beslut från Aron behövs, rör dem inte utan ja)
`public.drill_publications`, skola 35374123 (Central insamlingsenhet), båda "Nytt prov", Biologi, 22 nov:
- `36a3f569-bd57-489f-b1ec-247488328124` (00:23 UTC)
- `49e29092-40b3-4b23-9216-2e782d17ed5c` (01:30 UTC)

De publicerades av konton som bara fanns i simulatorer som nu är borta, så de går inte att ta bort från appen. Aron
har fått frågan: ta bort dem i databasen själv, eller låt Kevin göra det.

## Det som inte står i rapporterna
- **D180:** inga ElevenLabs-krediter. Kontrollera `public.test_accounts` (reason `header` eller `ci`) och
  funktionsloggen `test_request` innan något som gör ljud. Projektet är `xjczbzfkmbjdebwlccki`.
- **Simulatorn:** varje omstart av appen blir ett **nytt anonymt konto**. Antagandet är att Keychain inte sparar
  sessionen i det osignerade bygget. Starta därför aldrig om appen mitt i ett flöde som behöver samma konto.
- **XCUITest:**
  - Läs aldrig `UIPasteboard` i testet. iOS frågar testprogrammet om lov och körningen hänger.
  - Tryck aldrig på en knapp som inte går att trycka. XCTest stoppar då hela testet, och städningen med det.
  - Leta efter Start via kugghjulet "Inställningar". Ett importerat prov heter "Nytt prov", samma som knappen.
- **Bildbiblioteket:** lägg till bilden direkt efter `simctl boot`, och vänta upp till 60 s. Vår bild hamnar överst
  till vänster och är inget `Image`-element. Tryck på koordinaten, beräknad från exempelfotona.
- **Skriv text** (TextEditor) får inget fokus i simulatorn. Använd Välj bilder eller Gör med ChatGPT.
- **E2E-målet är gemensamt:** kompilera ny E2E-kod på en `toby/**`-gren först. Avbryt skärmturen (T3) och
  iOS-bygget som en push till `toby/**` också startar.
- **Klockan:** filnamn och tavlan skrivs i svensk tid (UTC + 1).

# Överlämning Toby (apptest), 2026-11-11 17:30
Sessionen (start 10:15, molnet) gjorde T5b, T7b, T8b + A50, T11, T12, T8c, T13 och T14 (8 punkter: byt). Kvar: T10:s telefonsteg (Aron).

## Det som inte står i rapporterna
- **Ingen GitHub-token i molnsessionen** (`gh` ogiltig, `git credential fill` nekas). Läsning går ändå utan token:
  `curl https://api.github.com/repos/<repo>/actions/runs/...`, `/jobs/<id>/logs` och `/artifacts/<id>/zip` (med `-L`).
  `workflow_dispatch` går **inte**. Starta därför körningar med en push till `toby/**` som rör flödets sökvägar.
  Egen gren: retest `fragor,block`, firstuser `skip`, skärmturen tre lägen. `Screens/**` startar tur + firstuser.
- **Pusha aldrig om en rebasad gren** (det kräver force). Slå ihop main i stället: `git merge origin/main`.
- **Klockan:** containern går på UTC. Svensk tid = UTC + 1. Tavlan skrivs i svensk tid.
- **Appens logg i UI-test:** `firstuser.sh` startar `simctl spawn log stream` med `private_data:on` och sparar
  `logs/<väg>-app.log`. Det fungerar och visar klartext. Bygg in samma sak i `screens.sh` om turen behöver den.
- **Lyssnar visar gamla sessioners svar.** Räkna alltid *nya* svar (antal etiketter före/efter), aldrig "texten finns".
- **Firstuser har två frågor i slingan** (lead 6 s + 20 s paus: första frågan cirka 26 s in i sessionen).
- **Retest-blocket kör med talet av** ("uppläst 0" väntat). "avsluta" i b2 är A19.2:s sammanfattning, avsiktlig.
- **Artefakter kan ge `ServerBusy: Egress is over the account limit`** (XML i stället för zip). Vänta 30 s och försök igen.
- **En push som rör `Screens/**` avbryter skärmturen som kör på grenen.** Vänta in turen (cirka 60 min för 3 lägen) innan du pushar `FirstUserTests.swift`.
- **Flödet efter A60:** första passet slutar på Start. Bladen kommer i olika ordning (A52, dela, A54), och `startSheets()` tar dem i en slinga.
  Provläge utan prov ger formuläret "Lägg till prov", där Avbryt startar Provläge.
- **More-testet:** "ja" och "mer" i de första fallen lär appen långa svar (A56/K13.2), och det följer med till senare fall. Nollställ längden per fall innan nästa T7-körning.
- **T7b:** "Efter ordet"-tiden går att läsa ur `Turn timing` (`heard→call`) i `more.json`.

## Öppna trådar
- Till Angela (T14): turen väntar på Scribe-stängning (hel fråga 25,7 s, halv 29 s), mikrofonen stängd 12–15 s efter
  tvåmeningssvar, c2 fel ämne. Mer-fönstret klart (1,6–1,8 s). Retest: öka pausen till ~20 s innan nästa körning.
- Läs nattens skärmtur på main (03:30, alla sju lägen med A50–A60-stegen).
- Oro (skriven i båda rapporterna): A49 Sömnläge sparar ljud i 30 dagar; fynd 1 sparar en "röstprofil" utan avsikt.
- Grenen `toby/t5b-t7b-t8b-2` är flyttad till main (bara mina filer).
