# Överlämning: Angela (app), 2026-11-10

Sessionen (självständigt läge) gjorde A21, A18, A20, A22, A23, A24 och A25. Alla är gröna i CI, men ingen är
provad på enhet. Läs rapporterna i `reports/2026-11-10-angela-a*.md`. Resten av kön väntar på Kevin (A3/K6, A16/K15,
A19/K17+K19).

## Det här står inte i rapporterna
- **Ingen Mac.** CI (`ios-build.yml`) är kompilatorn, ca 15–20 min per körning. Hjälpskript: `ghapi.sh`, `waitsha.sh`
  och `waitrun.sh` (minnet `lumen-project-setup`).
  - Varje push som rör app-kod avbryter körningen som pågår, också andras pushar. Samla dina ändringar.
- **Delat index och delad autostash:**
  - Andra sessioner har två gånger fått med mina ostagade ändringar i sina commits (Oscars `bda589a`), och en gång har
    en rebase burit dem i sin autostash.
  - Committa med `git commit -- <filer>`.
  - Säger `git pull` "Cannot rebase onto multiple branches": kör `git fetch origin main && git rebase --autostash
    origin/main`.
- **Swift-fällor som kostade en CI-runda i dag:**
  - `switch` som implicit retur fungerar inte efter en `if` i samma getter; skriv `return switch`.
  - `#expect` kan inte anropa en muterande metod. Lägg resultatet i en `let` först.
  - `FakePlaybackService.stop()` nollställer `isSpeaking`, och en ny tur kör `interrupt()`.
- **Numrering:** Deangelo numrerar om i kön samtidigt. Läs kön precis före commit. A22 är min stående uppgift och A23
  hans proffsfixar.
- **Designsystemet** (`docs/design/SYSTEM.md`) gäller. `gridPaper()` ritar nu kortet, `questionFont` är ingen handstil
  och `ConversationMode.color` är blå. Gamla namn finns kvar så att alla skärmar följer med.

## Öppna trådar
- **A18:** klar, med skärmbilder i `reports/2026-11-10-a18-skarmbilder/`. Kelly granskar del 2 med bilderna.
  Introbilden fotades före rättelsen i `ddec2ad` (Elias stack ut under kortet), så fota om den.
- **Loggan (U5):** Aron väljer bland Kellys tre förslag. Byt `LumenLogo` när valet är gjort.
- **Toby:** kör om T5, T7b (Mer-fönstret, rättat i `6133e6c`) och T3 med de nya knapporden.
- **Nästa stående uppgift (PLAN 2b):**
  - Tobys T8 fynd 5: Provläge utan prov frågar fem saker. Det är beslutet D83, och Kelly har fått det som design.
  - Röstens namn med beskrivning när K14:s röster har beskrivningar.
  - En `SessionEvent` för "fönstret öppet" och "mikrofonen öppen", som Toby ber om i T7.
- **ElevenLabs-kvoten är slut** (Oscar, Toby). Simulatortesterna som hör ljud kan inte köras klart förrän den är
  påfylld (Aron).
