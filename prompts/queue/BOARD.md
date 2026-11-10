# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-10 18:00.** Aron är borta och kan inte svara.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; nästa session: stående uppgift K4-loopen) | slutat (PLAN 2e: två komprimeringar), överlämning `docs/HANDOVER-kevin.md` | K25–K27 klara och driftsatta (CI 42804686846, 42805093491, 42805896061): siffror O26 45/45, räknaren 0 fel, Rizz-nätet O27 25/25, känsliga minnen O28 27/27, självfrågor 20/20, eko 12/12, länkar 15/15. K23 (BLOCKER) klar: kris i Auto 44/44. API i dag 0,004 USD | 2026-11-10 12:27 | två komprimeringar: ny session behövs |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | stående uppgift (PLAN 2b); A3 väntar på K6 | jobbar | A27 klar (O28: appens skyddsnät för minnen 47/47, O24: Om appen säger var frågorna sparas), grönt i CI 42800157819. I dag 11 punkter, alla gröna, ej på enhet | 2026-11-10 13:25 | 11 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (gratis offlinepunkter genomgångna; omtest när Kevin rättat K21b, calc-parenteser, K22) | väntar på Kevin; **BLOCKER K21b: 18/40 nya krisfall tysta i Auto**; Aron: lägg inte in service-role-hemligheten (K22) | O34: verklighetsbanken +44 fall (körs när budget finns). O33 klar: klocka/zoner/datum i kod 11/11 rätt. O32 klar: BUGG, calc.ts tar bort parenteser ('(12+8)*2' blir 28 och läses upp). O31 klar: K19 länkbegäran känns igen 5/15, domänskyddet 9/9. O30 klar: ekofiltret äter 4/8 följdfrågor som citerar svaret. O29 klar: telefonskyddet 17/22 (Bris och 90101 läses som stora tal). O28 klar: minnesfiltret (server+app) stoppar 5/27 känsliga minnen. O27 klar: Rizz-filtret i kod stoppar 0/25 nya olämpliga rader (bara modellen skyddar). O26 klar: uppläsning av tal 34/45 ('6/6' blir 'sex/sex', 'ett bok'). O24 klar: frågor om Lumen 5/20, 'Erik 14 poäng' blir 'Erik den fjortonde poäng' (8/10 vanliga namn). O25 klar: K22-rensningen tar bort 3/22 personuppgifter och hoppar över 2/20 känsliga rader, och pushar själv till det publika repot (hemligheten är inte inlagd, så inget har läckt). O23 (O17b) klar: krissvaret 20/40, tysta 18/40, falska larm 10/40. O22, O21, O17, O20, O19, O11, O13 del 1, O18, O15, O12, O14 klara | 2026-11-10 11:12 | 24 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T9 skärmrunda efter A18/A22 + T8b del 1 (Lyssnar efter mikrofonfrågan) | jobbar, byt snart | T9: turen följer A18/A22:s knappord (första körningen fastnade på 'Fortsätt', turens fel) | 2026-11-10 10:05 | komprimerad, byt snart (T7, T8 klara, T9 pågår) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Granska A30-bilderna och Ke18 steg 2–3 när bilderna är pushade (A30 CI) | jobbar | Ke21 klar: 18+ borta för Rizz på sidan och i skissen (D112). Ke20 klar. API 0 USD | 2026-11-10 12:40 | 14 punkter (Ke9–Ke21, Ke12b, Ke13b), två komprimeringar, byt snart, fortsätter till 18:00 |
