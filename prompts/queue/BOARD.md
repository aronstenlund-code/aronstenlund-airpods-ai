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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (K18 del 2 och K6 redo, väntar på ElevenLabs-krediter: `python scripts/dispatch.py credits-ready.yml`) | väntar på kö, avslutad för dagen | K22 klar: lär av riktiga användare varje vecka (opt-in, rensat, k ≥ 2, ingen modell), testad på påhittade data; väntar på hemligheten SUPABASE_SERVICE_ROLE_KEY. K20 klar | 2026-11-10 10:50 | 20 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A26 Kellys R1–R6, sedan A16 och A19 | jobbar | 7 klara i dag, gröna i CI: A21, A18, A20, A22, A23, A24, A25; ej på enhet | 2026-11-10 10:45 | 7 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-angela.md`), fortsätter till 18:00 |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | stående uppgift (PLAN 2b), bara gratis offlinetester till 18:00 | jobbar; **BLOCKER hos Kevin: K21b ger tystnad på 18/40 nya krisfall i Auto** | O32 klar: BUGG, calc.ts tar bort parenteser ('(12+8)*2' blir 28 och läses upp). O31 klar: K19 länkbegäran känns igen 5/15, domänskyddet 9/9. O30 klar: ekofiltret äter 4/8 följdfrågor som citerar svaret. O29 klar: telefonskyddet 17/22 (Bris och 90101 läses som stora tal). O28 klar: minnesfiltret (server+app) stoppar 5/27 känsliga minnen. O27 klar: Rizz-filtret i kod stoppar 0/25 nya olämpliga rader (bara modellen skyddar). O26 klar: uppläsning av tal 34/45 ('6/6' blir 'sex/sex', 'ett bok'). O24 klar: frågor om Lumen 5/20, 'Erik 14 poäng' blir 'Erik den fjortonde poäng' (8/10 vanliga namn). O25 klar: K22-rensningen tar bort 3/22 personuppgifter och hoppar över 2/20 känsliga rader, och pushar själv till det publika repot (hemligheten är inte inlagd, så inget har läckt). O23 (O17b) klar: krissvaret 20/40, tysta 18/40, falska larm 10/40. O22, O21, O17, O20, O19, O11, O13 del 1, O18, O15, O12, O14 klara | 2026-11-10 11:10 | 22 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T9 skärmrunda efter A18/A22 + T8b del 1 (Lyssnar efter mikrofonfrågan) | jobbar, byt snart | T9: turen följer A18/A22:s knappord (första körningen fastnade på 'Fortsätt', turens fel) | 2026-11-10 10:05 | komprimerad, byt snart (T7, T8 klara, T9 pågår) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke18 väntar på Angelas A26; under tiden stående uppgift (sidan = appen) | jobbar | Ke19 klar: demorutan har D97:s två val (Förhör mig med inspelade Provlägessvar, Få A-svar = livedemon), Lighthouse 99/100/100/100. API 0 USD | 2026-11-10 10:47 | 12 punkter (Ke9–Ke19, Ke12b, Ke13b), en komprimering, byt snart, fortsätter till 18:00 |
