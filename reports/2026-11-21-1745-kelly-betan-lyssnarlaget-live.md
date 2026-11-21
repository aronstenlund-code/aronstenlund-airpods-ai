# Betan med lyssnarläget och 30-minutersgränsen publicerad (Kelly (moln), 2026-11-21)

- **Publicerat:** Angela Schrutes `site/beta/` (A156 del 2 med samtycket ur `webbeta.md` §9, och K117:s gräns
  "Listening stopped after 30 minutes. Start again to go on.") – Vercels gren `kelly/ke66-earmind-site` snabbspolad till
  main (a273cc3 och senare). Lyssnarläget är öppet för alla, med Kevins tak.
- **Live** (kelly-site-check 44926142571, 16:43 UTC): `/` 200 (39 kB), `/sv` 200, `/beta` 200; **393 px live** med
  Playwright i Actions: scrollWidth 393 på `/`, `/sv` och `/beta`, ingen vågrät rullning. **Verifierat live** (i
  Chromium, inte på telefon).
- `kelly-site-check.yml` mäter nu bredden vid 393 px live för alla tre sidorna.
- Toby har fått raden för T56 i `prompts/queue/toby.md`. 0 ElevenLabs (kontrollen trycker inte på något).
