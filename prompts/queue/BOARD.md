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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön klar utom K6) | väntar på Aron (Till Aron #15) | **K50 klar 21:21**; **K6 21:35:** ElevenLabs-nyckeln saknar behörigheten voice_generation, 0 tecken använda (`reports/2026-11-13-2135-kevin-k6-voice-permission.md`). Klickväg i Till Aron #15 | 2026-11-13 21:35 | 8 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | A82 (repetitionsläget, tar över A78–A81) | arbetar | **A82 del 1 pushad 20:35 (d728931):** mocken bytt mot K45–K47 och serverns ElevenLabs-filer, Kellys R1–R12 och Ke50-texterna, Starta prov när första frågan har ljud, första passet till Nytt prov, skärmbildsscener rep*. CI kör. Toby 2 har fått API:t till T18 | 2026-11-13 20:40 | ny session |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55 (repetitionsläget) | väntar på K45 | **Testbanken klar 19:55:** 10 påhittade prov (10 ämnen) med material som 17 foton, 3 PDF, 3 .docx och 3 texter, 64 lärandemål med nyckelord och 50 ämnen som ligger utanför materialet (R2), plus 53 provuppgifter med facit; 0 USD | 2026-11-13 19:55 | ny session |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: T15b och T17 (BETA-lägena) · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: omkörningar i CI: T15b 43500509722, T17 efter A75 43500516427, baslinje 43500524261 · Toby 2: checklistan `docs/TEST-ARON-REPETITION.md` klar; väntar på Angelas gröna A78 för simulatortestet | Toby 1: första körningen: T15b väntan 0/10 över 4 s och mikrofonen 10/11 inom 1 s, men 10/12 besvarade (uppvärmning); T17 föll på testet (1 m dämpades av A10, sorlet hade en fråga), rättat i e26228c · Toby 2: T18-checklistan (6f36a92, 300c101) | Toby 1: 2026-11-13 21:22 · Toby 2: 2026-11-13 20:25 | Toby 1: 1 punkt · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (A82 granskad, B1/B2 till Angela) | Ke49–Ke52 klara: repetitionslägets design och texter, demosidans utkast (inte publicerat), Publicera prov (). API 0 USD | 2026-11-13 21:17 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
