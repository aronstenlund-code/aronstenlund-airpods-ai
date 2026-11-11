# Överlämning Toby (apptest), 2026-11-11 16:25
Sessionen (start 10:15, molnet) gjorde T5b, T7b, T8b + A50, T11, T12, T8c och T13 (7 punkter: byt). Kvar: T10:s telefonsteg (Aron).

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
- Till Angela (T13): "ja" utan `done.more` väntar 7–13 s innan "utveckla", halv fråga väntar 25–32 s (Scribe-stängning,
  "words waiting: false"), döv 20 s efter svar, tipset tog c1. Kevin: `done.more` för korta faktasvar. Kör om retest + more då.
- Läs nattens skärmtur på main (03:30, alla sju lägen med A50–A60-stegen).
- Oro (skriven i båda rapporterna): A49 Sömnläge sparar ljud i 30 dagar; fynd 1 sparar en "röstprofil" utan avsikt.
- Grenen `toby/t5b-t7b-t8b-2` är flyttad till main (bara mina filer).
