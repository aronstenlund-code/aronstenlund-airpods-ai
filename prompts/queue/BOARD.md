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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | nattpass till 07:30 | Omgång 20 klar 00:50: intervju 19/19 (annonsen utan CV är inte elevens fakta). K44b, K44, O52 och O53 klara. 508 tester. API i natt cirka 4,5 USD | 2026-11-12 00:50 | 14 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (kön klar utom A3, som väntar på K6) | bevakar kön | A75, A76 (+ Ke46), A72 del 3 och A77 gröna i CI (43093258037, 43110609458). A76 laddar inte upp förrän appen kan logga in med e-post eller koppla kontot (Till Aron/Kevin). GitHubs Mac-kö är lång i kväll (1–2 h). Toby: T15c, T16/T17 | 2026-11-11 23:40 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kollar kön var 30:e min) | väntar på kö | **O54 01:10: Intervjuläget utan CV 7/12** — annonsens krav blir elevens fakta ('Jag har tidigare jobbat i lager'), Kevin prio 2. **00:02 K44b:** morgonrapport och Spotify rättade, '?.' borta; kvar 'hur gör jag för att få en morgonrapport' (modellen hittar på). **O52 23:29: K44 godkänd** — vad Earmind kan 39/40 (var 26/40), förnekanden 7→1, tysta 8→0; **klockan 5/5 rätt** (var 0/5); K43 opt_in kräver e-postkod. Kvar: morgonrapporten, Spotify 'Ja'. Natt API ca 1,2 av 2 USD, ElevenLabs 0 | 2026-11-12 01:10 | 24 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b på A72 del 3 köad i CI sedan 21:48; GitHub Actions står still för kontot (7 körningar köade, även backend-deploy) | väntar på CI | T15b 21:20 på A72 del 2: mikrofonen 12/12 ≤ 0,8 s, inga ekon; 7 av 11 väntade 8,7–21,2 s | 2026-11-11 23:50 | 11 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (4 tomma kontroller i rad; slutat kolla) | Kväll/natt: Ke22 annonsbilder, Ke40 exakta ikoner, Ke41–Ke43 granskning A73/A71, Ke44 stegbilder, Ke45 testlägesdesign, Ke46/Ke48 A76 (T1–T4 stängda i koden), Ke47 Vad kan Earmind? efter capabilities.json. Öppet: testlägets skärmar på bild, A71 hemskärmsikon i Tobys natttur. API 0 USD | 2026-11-12 00:27 | 21 punkter, byt (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
