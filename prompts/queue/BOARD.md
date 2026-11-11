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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K43 klar; stående uppgift (PLAN 2b) | nattpass till 07:30 | K43 klar 20:48: testljud privat (bucket, /debug-audio, flik på qa.html, rensning efter 14 dagar), väntar på A76. 499 tester | 2026-11-11 20:48 | 9 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (kön klar utom A3, som väntar på K6) | bevakar kön | A75, A76 och A72 del 3 gröna i CI 43093258037. A76 laddar inte upp förrän appen kan logga in med e-post eller koppla kontot (Till Aron/Kevin i rapporten). Toby: T15c (A72 del 3), T16/T17 | 2026-11-11 21:38 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O52 omtest K44 (förmätning klar; Deploy backend för K44 köad sedan 21:24: 5 Actions-jobb igång, bl.a. iOS-bygge sedan 21:05, ingen ledig runner) | väntar på deploy | **O52 förmätning 21:47** (före K44): förnekar 7 funktioner som finns ('Jag kan inte sätta timers'), 8 tysta, 'studieassistent' 2. **O53 21:00: K43 testljud godkänd med fynd** (23/23 stängt; opt_in kräver bara e-postadress → lagringsmissbruk möjligt). **O52 20:58: 'vad är klockan' ger fel tid 0/5** ('tjugo över nio' kl. 20:57) — Kevin prio 1; Aron: fråga inte om klockan i kväll. O51s-regressionen rättad (12/12). K42b: klagomål 10/10, längd 10/10. Natt API ca 0,85 av 2 USD, ElevenLabs 0 | 2026-11-11 21:47 | 21 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b igen när A72 är [x]; stående uppgift under tiden | väntar | T15b 21:20 på A72 del 2: mikrofonen 12/12 ≤ 0,8 s, inga ekon; 7 av 11 väntar 8,7–21,2 s (A72:s 6-s-gräns syns inte, c1 släpps vid Scribe-stängning) | 2026-11-11 21:20 | 11 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke47 klar 21:48: sajtens Vad kan Earmind? efter capabilities.json. Ke46: A76 T1–T4 till Angela (T2 hög). I kväll Ke22, Ke40–Ke47. API 0 USD | 2026-11-11 21:48 | 20 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
