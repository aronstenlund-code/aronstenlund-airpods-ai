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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (kollar var 20:e minut); K6 väntar på Till Aron #15 | **K64 klar 18:01** (`reports/2026-11-14-1801-kevin-k64-queue-texts-test-modes-cost.md`): inget ljud som ingen fråga använder, Kellys 402-text, testlägen unavailable/slow. **Till Deangelo:** ja/nej till förslag 1 (långa svaret görs under uppspelningen, 3 frågor i förväg: 198 krediter vid spara i stället för cirka 3 190), 2 (vid första trycket: cirka −56 %) och 3 (70 ord: −20 %). | 2026-11-14 18:01 | byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (A99, fynd 8, A97, A101 klara 18:40) · Angela Fable: – (A100, A99:s vyer och A101 i mina vyfiler klara 17:31) | väntar på kö (A3 väntar på K6; nästa: A87-punkten, Ke53 3–5) · Angela Fable: väntar på kö; kollar kön och tavlan var 20:e minut | **18:40 A99-logiken, T17-fynd 8, A97 (Earmind väcker) och A101 (EarMind) klara, iOS build 43617962807 GRÖN (dd140f0, ipa).** Nytt prov föreslår det som finns kvar, längdklass från servern, mitt-i-meningen-namnet bara med frågeord och paus. Ej på enhet; inga ElevenLabs-tester (D180). Kvar: Ke53 3–5 · Angela Fable: 2026-11-14 18:36 A100, A99:s vyer och A101 i mina vyfiler klara: **iOS build 43617962807 grönt (dd140f0, ipa)** med allt, Kelly har stängt A99/A100, Toby 2:s T23/T22 gröna. Inga ElevenLabs-tester. Ej verifierat på enhet. reports/2026-11-14-1731-angela-fable-a99-a100.md | 2026-11-14 18:40 | `reports/2026-11-14-1637-angela-a99-t17f8-a97.md` |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O62 klar | väntar på kö (kollar kön och tavlan var 20:e minut) | **18:16 O62: JA, testerna tar inga ElevenLabs-krediter.** Spara, ta bort, publicera och dela som test. Loggen 16:49–17:16 UTC har 0 rader om ElevenLabs eller ljudkön (137 testanrop), och 78 nya filer har alla teströsten och 0 krediter. K64: borttagna provs filer blir "unused", `slow` och `unavailable` fungerar, kvottexten är den nya. K63: EarMind 9/9 i /help och 0 gamla stavningar. Inga nya fel | 2026-11-14 18:16 | `reports/qa/2026-11-14-1816-oscar-o62-inga-krediter.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: – (testerna till main när inget iOS-bygge kör) · Toby 2: – (T23 och T22 klara) | Toby 1: väntar på kön · Toby 2: väntar på kö och Arons telefonsvar | Toby 1: T17c utan ElevenLabs: T17 48/50 och 0/50, 0 empty_answer; webb 20/20; fynd 8 10/10; A97 20/20; T16 0/10 → reports/apptest/2026-11-14-1850-toby1-t17c.md · Toby 2: T23 och T22 gröna (43617719005, 43617764929): falskt ljud bekräftat (ci), ingen BETA före första provet, Nytt prov 15 sedan 12, ikonen EarMind → reports/apptest/2026-11-14-1813-toby2-t23-t22.md | Toby 1: 2026-11-14 18:46 · Toby 2: 2026-11-14 18:13 | Toby 1: T16, T17, T19, T20 klara · Toby 2: simulatorn, inte enhet |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö; kollar var 20:e minut | A87/A83/A84/A92, största text och docs/HJALP.md granskade (H-1–H-5 till Kevin; H1/S1b på bild hos Angela Schrute); Ke49–Ke57 klara. API 0 USD | 2026-11-14 03:36 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
