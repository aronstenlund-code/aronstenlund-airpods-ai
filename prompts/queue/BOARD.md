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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (pass slut 18:00; kön tom utom K6) | väntar på kö | Pass slut 18:00. I dag: K38, K37, K39, K36, K40b (O41 BLOCKER), K40 (förhörssvar efter ljud) och stående omgång 2–15. Oscar godkände O41, K37, K38, K40 och rättelser (O49). API i dag ca 4,3 USD | 2026-11-11 18:00 | 19 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A71 steg 1: AppIcon (glasklotet D) | pågår | Kväll: A71 steg 1 → A73 → A72 → A71 steg 2 (Ke40). Senast: A50–A70 gröna (CI 43057820636) | 2026-11-11 18:49 | 21 punkter (samma session), byt snart |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | **klar för dagen** (självständigt läge slut 18:00) | **16 punkter i dag:** K36–K40 godkända (O41-blockern i Standardläge rättad), Mina svar 0 falska träffar, enordssvar i förhör tyst 40/40 och falskt Rätt 0/20, rättelser 17/20 utan falska, K17 19/19. Öppet: 'ljud sparas inte' osant (ElevenLabs loggar), appen skickar bara fasta ord till /memory, kommandon med nya ord 4/10, O13 del 3 (ljud på Arons dator). API ca 3,9 USD, ElevenLabs 367 tecken, Scribe ca 770 s | 2026-11-11 17:25 | 16 punkter, ny session behövs (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | pausad, självständigt läge slut 18:00 | T14 klar 17:25: ja/mer/gärna → långt svar 1,6–1,8 s (var 7–17 s); kvar till Angela: tur väntar på Scribe 13–29 s, mikrofonen stängd 12–15 s efter svar. I dag 8 punkter (T5b, T7b, T8b, T11, T12, T8c, T13, T14) | 2026-11-11 17:30 | 8 punkter, ny session behövs (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (självständigt läge slut 18:00) | I dag Ke29–Ke39: loggorna som vektor, Start + Vad kan Lumen?, Mina svar, Earmind på sajten (99/100/100/100, 1 504 kB), första passet (Ke35), största text (SYSTEM.md 10); granskat och godkänt A50, A52–A61, A64, A69 (kod), T8c/T13. **Öppet: G3 "Ljud sparas inte" och K1 saknar punkt hos Angela.** API 0 USD, ElevenLabs 0 | 2026-11-11 17:35 | 11 punkter, byt (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
