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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (väntar på K45–K48) | väntar på underlag: K45–K48, `docs/design/repetitionslage.md` och D142–D145 finns inte i repot (Till Aron #11). `git push` ger 403 "verify your email" (Till Aron #12): committar lokalt | **Omgång 21 klar lokalt 17:50:** evalens webbkälla läses från `done.source` (5 falska anmärkningar/natt borta), intervjusvar i du-form blir jag-form i kod; 511 tester; ej driftsatt. Claude 0,09 USD, ElevenLabs 0 tecken | 2026-11-13 17:50 | ny session, 1 punkt |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (kön klar utom A3, som väntar på K6) | bevakar kön | A75, A76 (+ Ke46), A72 del 3 och A77 gröna i CI (43093258037, 43110609458). A76 laddar inte upp förrän appen kan logga in med e-post eller koppla kontot (Till Aron/Kevin). GitHubs Mac-kö är lång i kväll (1–2 h). Toby: T15c, T16/T17 | 2026-11-11 23:40 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | repetitionsläget: testbank klar, O52/O53 | väntar på underlag (Till Aron #11): `docs/design/repetitionslage.md`, D142–D145, K45 finns inte i repot | **Testbanken klar 17:42:** 10 påhittade prov, 53 uppgifter med facit, 68 godtagbara och 67 felaktiga svar (`scripts/qa/repetition_bank/`), 0 USD | 2026-11-13 17:42 | ny session |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b på A72 del 3 köad i CI sedan 21:48; GitHub Actions står still för kontot (7 körningar köade, även backend-deploy) | väntar på CI | T15b 21:20 på A72 del 2: mikrofonen 12/12 ≤ 0,8 s, inga ekon; 7 av 11 väntade 8,7–21,2 s | 2026-11-11 23:50 | 11 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (4 tomma kontroller i rad; slutat kolla) | Kväll/natt: Ke22 annonsbilder, Ke40 exakta ikoner, Ke41–Ke43 granskning A73/A71, Ke44 stegbilder, Ke45 testlägesdesign, Ke46/Ke48 A76 (T1–T4 stängda i koden), Ke47 Vad kan Earmind? efter capabilities.json. Öppet: testlägets skärmar på bild, A71 hemskärmsikon i Tobys natttur. API 0 USD | 2026-11-12 00:27 | 21 punkter, byt (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
