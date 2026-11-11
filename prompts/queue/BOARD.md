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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (bevakar kön till 18:00) | väntar på kö | Omgång 13 klar 15:38: rättelser med nya ord 5/20 → 18/20 (Haiku-kontroll, 0 falska). Omgång 12 (O43 falskt 'Rätt') godkänd av Oscar O45. I dag: K38, K37, K39, K36, K40b, K40, omgång 2–13. API i dag ca 4,1 USD | 2026-11-11 15:38 | 18 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (A51 väntar på röstningen, A3 på K6; bevakar kön och nya fynd till 18:00) | väntar på kö | A50–A66 gröna, senast CI 43032984385 (ipa uppladdad till Arons test i kväll). A66: ett blad per öppning, Har du prov snart? med Inte nu | 2026-11-11 15:13 | 17 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kollar kön till 18:00) | väntar på kö | **O47:** nya formuleringar rättelser 5/20, kommandon 4/10 (0 falska; O22-fallen 20/20). **O46:** ekofilter 12/12, rättelser 20/20, kommandon 9/10 (offline). **O45 15:30: O43 godkänd** — enordssvar i förhör tyst 40/40, sorl 34/35 utan fel betyg, tyst elev i sorl 0/20 falskt Rätt (var 2/20; listuppläsning → 'Vad sa du?'). I dag: K36–K40 godkända, O16, O34, O13 del 2, O42–O45. API ca 3,9 USD, ElevenLabs 367 tecken, Scribe ca 770 s | 2026-11-11 15:31 | 14 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T13: skärmturen kör, rapport pushad | pågår | T13 15:55: förstagång grön (11 tryck), mer → 1,7 s (done.more); kvar till Angela: ja → 13 s utan done.more, halv fråga 25–32 s, döv 20 s efter svar | 2026-11-11 15:55 | 7 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke38 klar 14:57: T8c visar att Ke35 fungerar (Start först, Provläge 4 tryck, ett blad per öppning); K1 Dela historik grå. **G3 "Ljud sparas inte" saknar fortfarande punkt.** A64 väntar på bilder. I dag Ke29–Ke38. API 0 USD | 2026-11-11 14:57 | 10 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
