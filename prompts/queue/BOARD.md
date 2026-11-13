# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-12 07:30.** Aron är vaken till ca 23 och testar appen, sedan sover han. Vänta ändå inte på honom: frågor skrivs under "Till Aron". Ordning: kön, sedan stående uppgift.

Deangelo läser tavlan före varje statusrapport till Aron. **Varje session uppdaterar bara sin egen rad**:
- när den tar en punkt,
- när den blir klar (resultatet i en mening med siffror),
- när den fastnar eller väntar.

Kolumnerna:
- **Modell** och **Effort**: det sessionen faktiskt kör på, enligt skärmen eller `/model`.
- **Kontext**: punkter klara i sessionen, "komprimerad" eller "byt snart" (README punkt 7).
- **Senast**: tid för senaste uppdatering (ÅÅÅÅ-MM-DD HH:MM).

| Session | Modell | Effort | Gör nu | Status | Senaste resultat | Senast | Kontext |
|---|---|---|---|---|---|---|---|
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K45 (frågornas längd, R3) | arbetar | **K48 klar 20:27: A/B/C i `docs/rost-blindtest/`** (samma tre meningar, appens röst; v2, v3 och Flash i slumpad ordning, facit bara i `FACIT.md` för Deangelo), 1 488 ElevenLabs-tecken ≈ 0,10 USD. K46 och K47 driftsatta och testade live (ljud 6/6 på 10 s, 0 nya tecken för annat konto och vid import, RLS 404/0 rader). K45 driftsatt: frågor 4–8 s, alla svar inom 24 s, Claude ≈ 0,06 USD per prov; R3 (≤5 ord) 56 % ännu inte nått | 2026-11-13 20:27 | 4 punkter |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (kön klar utom A3, som väntar på K6) | bevakar kön | A75, A76 (+ Ke46), A72 del 3 och A77 gröna i CI (43093258037, 43110609458). A76 laddar inte upp förrän appen kan logga in med e-post eller koppla kontot (Till Aron/Kevin). GitHubs Mac-kö är lång i kväll (1–2 h). Toby: T15c, T16/T17 | 2026-11-11 23:40 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55 (repetitionsläget) | väntar på K45 | **Testbanken klar 19:55:** 10 påhittade prov (10 ämnen) med material som 17 foton, 3 PDF, 3 .docx och 3 texter, 64 lärandemål med nyckelord och 50 ämnen som ligger utanför materialet (R2), plus 53 provuppgifter med facit; 0 USD | 2026-11-13 19:55 | ny session |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: T15b och T17 (BETA-lägena, Toby 2 har T18) · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: läser T15b-körningen 43486740267, väntar på T17 före/efter A75 (43489819098/43489814229) · Toby 2: checklistan `docs/TEST-ARON-REPETITION.md` klar; väntar på Angelas gröna A78 för simulatortestet | Toby 1: – · Toby 2: T18-checklistan (6f36a92, 300c101) | Toby 1: 2026-11-13 20:24 · Toby 2: 2026-11-13 20:25 | Toby 1: ny session · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på A78–A81-bilder för granskning | Ke49 design och Ke50 texter för repetitionsläget klara (`docs/design/repetition.md`, `repetition-texter.md`). API 0 USD | 2026-11-13 20:19 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
