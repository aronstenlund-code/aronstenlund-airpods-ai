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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | nattpass till 07:30 | K44 klar och driftsatt 23:20 (kan 30/30, identitet 6/6, aldrig studieassistent). O52 klockan i kod (live 5/5) och O53 driftsatta. 505 tester, regression 90,5 % | 2026-11-11 23:20 | 12 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A77 klar, väntar på CI c02539f | bevakar kön | A75, A76 (+ Kellys Ke46 T1–T4), A72 del 3 och A77 pushade. A76 laddar inte upp förrän appen kan logga in med e-post eller koppla kontot (Till Aron/Kevin). Toby: T15c, T16/T17 | 2026-11-11 21:56 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O52 omtest K44 väntar: Deploy backend (1d5237a, e3fedc0) **fortfarande köad 22:52** fast GitHub-störningen inte längre är listad. Kevin/Aron: GitHub › Actions › Deploy backend › Cancel run, sedan Re-run all jobs | väntar på deploy | **O52 förmätning 21:47** (före K44): förnekar 7 funktioner som finns ('Jag kan inte sätta timers'), 8 tysta, 'studieassistent' 2. **O53 21:00: K43 testljud godkänd med fynd** (23/23 stängt; opt_in kräver bara e-postadress → lagringsmissbruk möjligt). **O52 20:58: 'vad är klockan' ger fel tid 0/5** ('tjugo över nio' kl. 20:57) — Kevin prio 1; Aron: fråga inte om klockan i kväll. O51s-regressionen rättad (12/12). K42b: klagomål 10/10, längd 10/10. Natt API ca 0,85 av 2 USD, ElevenLabs 0 | 2026-11-11 22:52 | 21 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b igen på A72 del 3 (vantan), köad i CI (Actions-kön full) | pågår | T15b 21:20 på A72 del 2: mikrofonen 12/12 ≤ 0,8 s, inga ekon; 7 av 11 väntade 8,7–21,2 s | 2026-11-11 21:50 | 11 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke48 klar 22:22: A76 T1–T4 stängda, A77 godkänd. I kväll Ke22, Ke40–Ke48. API 0 USD | 2026-11-11 22:22 | 21 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
