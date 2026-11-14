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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (kollar var 20:e minut); K6 väntar på Till Aron #15 | **K61 klar 14:42** (`reports/2026-11-14-1442-kevin-k61-quota-length-try.md`): kvoten styr antalet (drill quota.suggest till A99), ingen ordgräns, length_class per fråga, try räknas en gång. Tidigare i dag: K58–K60, empty_answer efter sökning (Toby: kör om T17). Inga öppna frågor till Deangelo. | 2026-11-14 14:42 | byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – · Angela Fable: – (A95 och A98-vyn klara 14:33) | väntar på kö · Angela Fable: väntar på kö; kollar kön och tavlan var 20:e minut | **14:34 A96 och A98-logiken klara, iOS build 43597560845 GRÖN (3e23e9c, ipa).** Importen 28/28 i appen och på servern (gemensam testfil med Kevin); Spela in i Mina svar i två steg, mikrofonen bara på Spela in svaret. Ej på enhet (Toby 2 testar A98). Kvar: A97 (Earmind väcker), Ke53 3–5 · Angela Fable: 2026-11-14 14:33 A95 (VoiceOver, kontrast, träffytor; granskning i CI) och vyn i A98 (Spela in i två steg) klara: **iOS build 43597560845 grönt (3e23e9c, ipa)**, Kelly har godkänt bilderna. Ej verifierat på enhet; VoiceOver på riktig telefon återstår. reports/2026-11-14-1357-angela-fable-a95-a98.md | 2026-11-14 14:34 | `reports/2026-11-14-1245-angela-a96-import.md` |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O60 klar | väntar på kö (kollar kön och tavlan var 20:e minut) | **14:52 O60 (D176):** 57/58 genererade frågor (98 %) är `normal` på 5 nya hållout-prov (median 560 tecken, max 830), och klassen från servern är rätt 3/3 (normal/longer/too_long). D175: 20 begärda gav 15. **Fråga till Deangelo (prio 3):** utan ordgräns är frågorna median 8 ord, och flera är två frågor i en ("…, och vad händer då?"). Ska det vara en fråga åt gången? | 2026-11-14 14:52 | `reports/qa/2026-11-14-1452-oscar-o60-langdklass.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: – (T17 väntar på ElevenLabs-kvoten, Kevin och fynd 8) · Toby 2: – (T21 klar) | Toby 1: stoppat: ElevenLabs-kvoten för Scribe slut 14:34 (Till Aron #16) · Toby 2: väntar på Arons telefonsvar (43543518435) och Deangelos besked om BETA-raden på Start | Toby 1: T17b: empty_answer kvar 4/20 webbfrågor efter cb92e6d; hela T17 ogiltig från w26 (kvoten) → reports/apptest/2026-11-14-1505-toby1-t17b.md · Toby 2: T21 klar i simulatorn (43594095637): 2 skärmar före kameran, ingen BETA i första starten, 9 tryck till första frågan; fynd Skriv text tomt utan fokus, Beta-raden på Start, ljud fastnade 3/6 en gång → reports/apptest/2026-11-14-1348-toby2-t21-ny-anvandare.md; A95 apptest-a11y.yml på main | Toby 1: 2026-11-14 15:01 · Toby 2: 2026-11-14 13:48 | Toby 1: T16, T19, T20 klara, T17b körd · Toby 2: simulatorn, inte enhet |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö; kollar var 20:e minut | A87/A83/A84/A92, största text och docs/HJALP.md granskade (H-1–H-5 till Kevin; H1/S1b på bild hos Angela Schrute); Ke49–Ke57 klara. API 0 USD | 2026-11-14 03:36 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
