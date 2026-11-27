# Kevin (moln) – O106 L1 / D272: lyssnarläget frågar grinden, och hjälpens engelska knappnamn

**Datum:** 2026-11-27 05:30. **Uppdrag:** Deangelo 03:34.
**Regler:** inga riktiga modellanrop, 0 ElevenLabs. **Svit:** 922/922. **Driftsatt:** push till main.

## D272: varje fråga i lyssnarläget går genom grinden

### Fyndet
K68:s direktväg (`isClearQuestion`: frågeord, "?" och minst tre ord) hoppade över frågegrinden i lyssnarläget (`mode: auto`). Därför besvarades frågor mellan människor högt, till exempel "Vad ska vi äta ikväll?".

### Rättningen
- Frågan går fortfarande direktvägen, så att svaret är lika snabbt som förut. Samtidigt startar **en grind**: ett anrop till Haiku med max 5 token och cachad systemprompt (`LISTEN_GATE_PROMPT`), som svarar ja eller nej.
- Inget sägs förrän grinden har sagt ja. Säger den nej blir det tyst: `is_question: false`, `answered: false`, `not_for_assistant: true`. Svarsanropet avbryts.
- **Svarar grinden inte** (fel, eller ingen svar inom 2,5 s) svaras frågan som förut. En riktig fråga går alltså aldrig förlorad.
- **Frågor riktade till appen väntar aldrig på grinden:**
  - med namnet ("Lumen, …");
  - en handling till telefonen;
  - aktiveringsordet och knappen, som appen skickar som `push_to_talk` (A162: `answerLast` blir `push_to_talk`, verifierat i appens kod).
- Övriga vägar i lyssnarläget går redan genom Auto-promptens grind och är oförändrade.

### Hastigheten (verifierat i test)
- Grinden och svaret körs samtidigt, så den första byten kommer efter den långsammare av dem, inte efter båda i följd.
- I testet: svar 200 ms och grind 50 ms gav 244 ms totalt. Efter varandra hade det varit över 250 ms.
- I drift svarar grinden med ett enda ord, medan svaret behöver en hel första mening. Grinden bör därför oftast bli klar först. Det är en untested assumption tills det mäts live med modellanrop.
- **Kostnad:** ett extra litet Haiku-anrop för varje sådan fråga i lyssnarläget. Systemprompten är cachad och svaret är ett ord, så det rör sig om cirka 0,00003 USD per fråga (uppskattning).

### Oscars 28 fall omkörda med K122 (verifierat i återspelning)
- Grinden spelades av mig: A02, A16 och A25 ja; A12, A26, A27 och A28 nej.
- Oscars sparade svar ligger nu på anrop 2.
- **A26–A28** ("Vad ska vi äta ikväll?", "Hur mår din mamma nu?", "Var lade du mina nycklar?") besvaras inte längre.
- **A02, A16 och A25** besvaras som förut.
- De övriga 21 fallen är oförändrade. De gick aldrig direktvägen.

Test: `answer/o106_gate_test.ts`.

## Hjälpens engelska knappnamn (Oscars omtest av O105)

- **Dela** (Share), **Publicera prov** (Publish quiz) och provflödets övriga knappar har nu engelska namn inom parentes i HJALP.md, med appens egna texter:
  - Nytt prov, Fota sidor, Välj bilder, Skriv text och Lägg till dokument;
  - Skapa frågor, Stämmer det här?, Gör om med rättelsen och Ser rätt ut;
  - Ändra ordning, Klar, Lägg till fråga och Låt EarMind skriva svaret;
  - Starta prov och Avsluta;
  - Visa ett användarnamn, Prov från din skola, Lägg till i mina prov och Rapportera.
- `hjalp.ts` är synkad.
- Test: `help/o105_help_test.ts`.

## Inte gjort (låga, inte beställda nu)

- **L2:** `isCutOff` saknar ägande ord (hennes, hans, deras, sin).
- **L3:** "2031" läses både "trettioen" och "trettioett" i samma svar.
- **L4:** `answer_type_hint` sätts till "study" för retoriska frågor och för klockan och flygtid.
- **L5:** RELATION-exemplen, översättningsregeln mot "vad betyder" och `reply_hint`.

## Nästa

- **Oscar:** omtest av L1. Gatade fall har nu grinden som anrop 1 (`LISTEN_GATE_PROMPT`, svar ja eller nej) och svaret som anrop 2.
- **Live:** när krediterna är tillbaka, mät grindens svarstid mot svarets första token.
