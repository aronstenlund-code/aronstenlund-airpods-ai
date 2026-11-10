# Överlämning: Angela (app), 2026-11-10

Sessionen (självständigt läge) gjorde A21, A20, A22, A23 och A18 (A18 väntar på skärmbilder). Läs rapporterna i
`reports/2026-11-10-angela-a*.md`.

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
- **A18:** skärmbilder från `screenshots.yml` (Pro och SE, startade 08:35). Lägg in dem i rapporten och markera A18
  klar. Kelly granskar del 2 med bilderna.
- **Loggan (U5):** Aron väljer bland Kellys tre förslag. Byt `LumenLogo` när valet är gjort.
- **Toby:** kör om T5, T7b (Mer-fönstret, rättat i `6133e6c`) och T3 med de nya knapporden.
- **Nästa stående uppgift (PLAN 2b):** Provläge frågar efter delämnet när provet bara heter efter området ("NO").
  Mikrofon nekad från Start ska visa skärmen "Lumen hör dig inte" (Ke10).
- **ElevenLabs-kvoten är slut** (Oscar, Toby). Simulatortesterna som hör ljud kan inte köras klart förrän den är
  påfylld (Aron).
