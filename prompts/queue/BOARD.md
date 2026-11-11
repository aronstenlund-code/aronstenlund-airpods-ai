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
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (A51 väntar på röstningen, A3 på K6; bevakar kön och nya fynd till 18:00) | väntar på kö | A50–A68 gröna, senast CI 43042721816 (ipa uppladdad till Arons test i kväll). A67/A68: Tobys T13 (ja under ström, frågetimern) | 2026-11-11 16:11 | 19 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kollar kön till 18:00) | väntar på kö | **O49:** rättelser 17/20, falska 0/30 (krav uppfyllt). **O48:** Haiku-rättelser 19/20 men 11/30 falska; appen skickar bara fasta ord, så ingen effekt i dag. **O47:** nya formuleringar rättelser 5/20, kommandon 4/10 (0 falska; O22-fallen 20/20). **O46:** ekofilter 12/12, rättelser 20/20, kommandon 9/10 (offline). **O45 15:30: O43 godkänd** — enordssvar i förhör tyst 40/40, sorl 34/35 utan fel betyg, tyst elev i sorl 0/20 falskt Rätt (var 2/20; listuppläsning → 'Vad sa du?'). I dag: K36–K40 godkända, O16, O34, O13 del 2, O42–O45. API ca 3,9 USD, ElevenLabs 367 tecken, Scribe ca 770 s | 2026-11-11 16:47 | 16 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (T10 väntar på Arons telefonsteg; kollar kön igen 17:00) | väntar på kö | T13 klar 16:25: förstagång grön (11 tryck), skärmtur grön (A64 rättade största text), mer → 1,7 s; kvar till Angela: ja → 13 s utan done.more, halv fråga 25–32 s, döv 20 s efter svar, tipset tog en fråga | 2026-11-11 16:25 | 7 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke39 klar 16:31: A64 största text godkänd (T13-turen), 2 låga rester. **G3 "Ljud sparas inte" och K1 saknar punkt hos Angela.** I dag Ke29–Ke39. API 0 USD, ElevenLabs 0 | 2026-11-11 16:31 | 11 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
