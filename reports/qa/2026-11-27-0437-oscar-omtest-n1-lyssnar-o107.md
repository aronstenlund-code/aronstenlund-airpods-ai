# Omtest: grinden N1, lyssnarsvaren och O107, Oscar (moln)

**Resultat:** Kevins rättningar håller (**verifierat i återspelning, harness och test** med serverns egna funktioner).
- Kevins rapport: `reports/2026-11-27-0700-kevin-lyssnarsvar-o107.md`.
- **A15, A19 och G4** fick nya svar mot de nya promptarna, eftersom de gamla var skrivna mot de gamla.
- 0 ElevenLabs, 0 Claude.

| Område | Efter |
|---|---|
| **N1** grindens första ord | "nej, det är en fråga till kompisen" ger tyst, "Nej det är privat" ger tyst och "ja, det är en kunskapsfråga" ger svar. Grindens exempel är nu nya ("Ska vi gå hem nu?", "Har du sett min laddare?", "Do you want some tea?"), inte mina testfall. **Rättat** |
| Kortregeln för frågor i rummet | Prompten säger "at most three short sentences, the core only", och `max_tokens` är 440 och 336. A15 (väder och klimat) gav tre korta meningar. **Rättat i prompten.** Obs: koden kortar inte. Mitt gamla svar på fem meningar lästes fortfarande upp i sin helhet, så det beror på modellen |
| A19 | Med ledtråden fact blev det "klockan tjugotvå och trettiosex på torsdagskvällen, sex timmar efter …". **Rättat** |
| A17 | "tvåtusen trettioett" båda gångerna. **Rättat** |
| **F1** rättningens sifferkontroll | "fem miljoner" mot "5 miljoner fler" ger `expected 5000000`, equal. G4 ger **E1 C1**. Två rötter ger ingen kodkontroll, och "x är 2" ger **E1** med "leta också efter den andra roten" (G3). "minus 3" mot "x = −3" ger equal, och "3" ger not equal. **Rättat** |
| **F2** engelsk talram | P6 ger "Question one. Name the gas … It gives one point.", och PT2 likaså. **Rättat** |
| **F3** formler i uppgiftstexten | "tre x plus fem är lika med tjugo", "x i kvadrat plus två x minus åtta är lika med noll", "roten ur fyrtionio plus en halv gånger sex", "H två S O fyra", och "(milj.)" blir "(miljoner)". Poängen delas upp ("två poäng, en E-poäng och en C-poäng"). **Rättat.** Litet: P1 fråga två saknar punkt efter "en C-poäng" |
| **M-1** hälsa i minnet | "Tar penicillin", "Har hörselnedsättning" och "Går på KBT" stoppas nu. **Rättat** |
| **M-4** ändring utan "jag" | "provet i kemi är flyttat till nästa onsdag" uppdaterar nu provet till onsdag 3 december 2026. **Rättat** |
| M-2 och M-3 | Telefon, adress, e-post och andras uppgifter sparas fortfarande. Det är inte gjort enligt D113 A5 (M-2), och M-3 väntar på beslut. Det står kvar som öppna frågor till Deangelo och Aron |

## Kvar
- M-2 och M-3 (beslut).
- PF1 (foto-provet om cellen utan cellkärnan).
- O106 L2, L4 och L5 (låga).
- Att koden inte kortar svar på frågor i rummet (lågt, värt att veta).
