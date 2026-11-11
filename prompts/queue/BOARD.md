# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-11 18:00.** Plan för dagen: `docs/PLAN-2026-11-11.md`.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (bevakar kön till 18:00) | väntar på kö | Omgång 14 klar 16:15: rättelsekontrollen 0/30 falska (var 11/30), 18/20 rätt. done.more efter fakta i Auto 8/8 (T13). I dag: K38, K37, K39, K36, K40b, K40, omgång 2–14. API i dag ca 4,2 USD | 2026-11-11 16:15 | 19 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (självständigt läge slut 18:00; A51 väntar på röstningen, A3 på K6) | klar för i dag | A50–A69 gröna, senast CI 43049646602 (ipa uppladdad till Arons test i kväll). Toby T14: ja/mer/gärna → långt svar 1,6–1,8 s (var 7–16 s). Kvar: en väntande fråga går ibland först när Scribe stänger (13–29 s), spåret står i överlämningen | 2026-11-11 17:22 | 20 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | **klar för dagen** (självständigt läge slut 18:00) | **16 punkter i dag:** K36–K40 godkända (O41-blockern i Standardläge rättad), Mina svar 0 falska träffar, enordssvar i förhör tyst 40/40 och falskt Rätt 0/20, rättelser 17/20 utan falska, K17 19/19. Öppet: 'ljud sparas inte' osant (ElevenLabs loggar), appen skickar bara fasta ord till /memory, kommandon med nya ord 4/10, O13 del 3 (ljud på Arons dator). API ca 3,9 USD, ElevenLabs 367 tecken, Scribe ca 770 s | 2026-11-11 17:25 | 16 punkter, ny session behövs (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | pausad, självständigt läge slut 18:00 | T14 klar 17:25: ja/mer/gärna → långt svar 1,6–1,8 s (var 7–17 s); kvar till Angela: tur väntar på Scribe 13–29 s, mikrofonen stängd 12–15 s efter svar. I dag 8 punkter (T5b, T7b, T8b, T11, T12, T8c, T13, T14) | 2026-11-11 17:30 | 8 punkter, ny session behövs (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; granskar Tobys T14 om den kommer före 18:00) | väntar på kö | 17:03: Angelas A69 rättade Ke39 S1/S2 (i koden). **G3 "Ljud sparas inte" och K1 "Dela historik" grå saknar punkt hos Angela.** I dag Ke29–Ke39 (11 punkter). API 0 USD, ElevenLabs 0 | 2026-11-11 17:03 | 11 punkter, byt (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
