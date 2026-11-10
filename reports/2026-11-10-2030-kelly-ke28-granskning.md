# Kelly Ke28: granskning av appens skärmbilder mot SYSTEM.md (2026-11-10 20:30)

Stående uppgift (PLAN 2b). Underlag: CI "Simulator screenshots" 42876421405 (main 19:33, iPhone 17 Pro Max,
18 skärmar i ljust och mörkt, inga krascher). **Simulator, inte enhet.** Bilder i `reports/2026-11-10-ke28-bilder/`.

## Helhet
Godkänd. Appen följer SYSTEM.md: en accent, kort med mjuk skugga, en huvudknapp per skärm, Lyssnar-brickan och
samma ord som sidan. D97:s två knappar på provkortet stämmer. Mörkt läge har inga vita rutor.

## Fynd till Angela (underlag, inga A-punkter skrivna av mig)
| # | Var | Fynd | Förslag | Vikt |
|---|---|---|---|---|
| F1 | Intro (Elias) | Hörluren är **vit och Apple-lik**. Ryans annonser har matt svarta hörlurar utan logga (ADS.md regel 36), och App Store-granskningen (5.2.5) kan reagera, eftersom introt också är App Store-bild 1 | Byt till en Elias-bild med matt svart hörlur innan App Store. Bilden görs om av den som gjorde Elias (Deangelo/Aron); inget för Angela förrän bilden finns | **Hög före App Store** |
| F2 | Om appen, samtycket, introt | "Ljud sparas inte/aldrig" blir osant när sömnläget (A49) sparar klipp | Se `docs/design/sovlage.md`, avsnittet "Konflikt". Deangelo avgör texten | Hög före A49 |
| F3 | Inställningar › Förhör och förklaringar | Värdet "Inte angivet" låter som ett formulär | "Automatiskt" (Lumen väljer) | Låg |
| F4 | Felkorten (`errors`) | "Rösten fungerar inte just nu" visas som ett rött felkort, men svaren fungerar med iPhones röst (A45 sa "en lugn rad"). "AirPods kopplades bort" är inte heller ett fel | Rött bara när Lumen inte kan svara (ingen internetanslutning, kan inte svara, mikrofonen avstängd). Rösten och AirPods får neutrala kort utan röd kant | Medel |
| F5 | Exempel i texter (Start, Byt läge, Inställningar) | Raka citattecken: "Lumen, jag har prov i engelska på onsdag", "Lumen, byt till socialt" | Svenska ”…” (ny rad i SYSTEM.md, avsnitt 4) | Låg |
| F6 | Byt läge-bladet | "Klar" uppe till höger, medan resultatkortet har "Stäng". Det var en öppen fråga i min överlämning | **Beslut:** blad har "Klar", kort har "Stäng" (ny rad i SYSTEM.md avsnitt 4). Appen gör redan så, så det är ingen ändring. Min sömnskiss (Ke27) är rättad till "Klar" | Stängd |

## Ändrat av mig
- `docs/design/SYSTEM.md` avsnitt 4: regeln för Klar/Stäng och svenska citattecken.
- `docs/design/_src/sovlage.html` och bilderna: Byt läge-bladet har "Klar".

## Test
Visuell granskning av 15 av de 36 bilderna sida vid sida (ljust och mörkt, de skärmar som ändrats sedan A46).
ElevenLabs 0 tecken, API 0 USD.
