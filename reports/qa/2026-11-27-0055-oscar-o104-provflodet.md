# O104: provflödet från början till slut, spelat genom K122, och omtest av Q1/Q2, Oscar (moln)

> Modellsvaren är skrivna av Claude-agenter som spelar modellen, **inte av modellen i drift**. Det som går att lita på här är serverns kedja efter modellen (trim, slutkontroll, rättningens regler i kod, talformat) och promptarnas instruktioner. Hur Haiku och Sonnet i drift svarar är en **untested assumption**.

**Omfattning:**
- **22 fall** i `scripts/qa/o104/cases.json`, med svar i `replies/` och utfall i `out/`.
- **Prov från text (PX1–PX6):** historia, kemi, engelska, en påhittad planet (för att se påhittade fakta), en kort text som ber om 12 frågor, och `answers: false`.
- **Prov från foto (PF1, PF2):** egna JPEG-bilder med anteckningar på sv och en.
- **Svar och extrafråga (DA1, DO1):** `drill_answers` och `drill_one`.
- **Rättning av fritt svar (G1–G7):** rätt, halvt rätt, fel årtal, "vet inte", engelska, fel uträkning, felstavat.
- **Ledtråd (H1).**
- **Provläge (T1–T4):** start, rätt, halvt rätt och engelska.
- Två underagenter spelade utan att veta vad som bedömdes.
- Alla fall gick till `done` med HTTP 200. 0 ElevenLabs, 0 Claude-API, inga nätanrop.

## Q1/Q2 från O103 (**verifierat i återspelning**)
- **Q1:** "how do I make pancakes" ger nu prompten "Answer ONLY in English". Svaret blev engelskt, och "Source: Bbcgoodfood." läses upp. **Håller.**
- **Q2:** 1066 läses "den fjortonde oktober **tiohundrasextiosex**". **Håller.**
- **Verktyget:** K122 kör nu med språkomslaget, så felmeddelandena kommer på engelska med `x-earmind-lang: en` (D2, D3, D5).

## Utfall mot kriterierna
| Kriterium | Utfall |
|---|---|
| **Rätt språk** | Engelsk text ger engelska frågor och svar (PX3, PF2), med "before Christ" i talet och BC/AD i `screen`.<br>**Men:** rättningens återkoppling är alltid svensk, också för en engelsk uppgift (G5), och foto-provets anteckningar och frågor får ingen `<language>` (PF2), se E6/G-c |
| **Rimlig svårighet** | Frågorna är förståelsefrågor där texten bär dem.<br>**Men:** serverns trim tar bort just de frågor som bär orsak och definition, så provet tappar delar av texten (E1):<br>• PF1 har inget om cellkärnan;<br>• PX6 har ingen fråga om orsaken till klimatförändringarna;<br>• PX4 består bara av minnesfrågor |
| **Snäll men ärlig rättning** | Modellens återkoppling var snäll och ärlig: G1 2/2, G2 1/3 med vad som saknas, G4 "vet inte" utan skuld, G6 metodpoäng och rätt svar, G7 full poäng trots stavfel.<br>**Men två regler i koden gör rättningen fel:** G-a drar poäng från rätt svar, och G-b ger fel råd för årtal |
| **Inga påhittade fakta utanför texten** | PX4 (Zorbia) följde texten. DO1 definierade växthuseffekten ur skolkunskap, vilket prompten tillåter ("School knowledge only to name or define a concept the notes use"). Promptens "a concrete example when it helps" lockar till tillägg (P-c) |
| **Provläge** | T1 och T4 ger en konkret fråga med `quiz_key` (sv och en). T2 svarar "Rätt …" och T3 "Inte riktigt …" och förklarar. Talet är rätt ("sjuttonhundraåttio nio", "den fjortonde juli") |

## Fynd till Kevin
**Rättning (kod, **verifierat i test** med serverns egna funktioner):**
- **G-a (medel–hög): sifferkontrollen läser "en" och "ett" i facit som talet 1.**
  - `numericCheck("När en syra och en bas blandas … ett salt.", "syra och bas blandas och då bildas vatten och salt")` ger `{expected: 1, given: null}`.
  - Med bedömningen "+C korrekt svar" blir ett fullt rätt svar **E1 C0** i stället för E1 C1 (`correctPoints`).
  - Sifferkontrollen bör bara gälla facit som har en riktig siffra (eller ett tal i ord som är själva svaret), inte räkneordet i "en syra".
- **G-b (medel): K1.7 skriver över återkopplingen för varje fel "bart tal", också årtal.**
  - "Vilket år blev Sverige ett arvrike?" med svaret "1523" gav "Svaret stämmer inte, och utan uträkning finns ingen metod att ge poäng för. **Visa hur du räknar, steg för steg.**" (`exam/handler.ts:680`).
  - Modellens användbara rättelse försvann ("1523 är året då Gustav Vasa blev kung").
  - Regeln bör bara gälla räkneuppgifter.
- **G-c (låg–medel):** rättningen säger "spoken Swedish sentences" också för en engelsk uppgift (G5). `lang` skickas men når inte modellen.
- **G-d (låg):** övningsläget säger "Never the full solution" men också "the feedback also says the correct answer and why". Det står också "one or two" mot "two or three" meningar. Ordningen avgör, men det står inte.

**Provets kedja (kod, **verifierat i återspelning**):**
- **E1 (medel): trimmet tar bort de enda orsaks- och definitionsfrågorna.**
  - `trimQuestions` tar bort sista frågan bland lika poäng, och `isRecall` känner bara svenska frågeord.
  - Följder: PF1 utan cellkärnan, PX6 utan orsaksfråga, PX4 bara minnesfrågor, och PF2 (engelska) behöll "When did…" och tog bort "Which ideas…".
  - Förslag: täck materialets meningar (inte bara frågetyper) när frågor tas bort, och lägg in engelska frågeord.
- **E2 (medel): när slutkontrollens omskrivning avvisas** (längre än originalet + 4 ord) används dess `sources` ändå på **den gamla** frågan. Det ledde till att en fråga felaktigt togs bort som `sameSource` (PX4).
- **E3 (medel): `dropNearSame` är för grov.** "Varför har jordens medeltemperatur stigit?" togs bort som nästan samma som "Hur mycket har jordens medeltemperatur stigit?" (PX6), fast de frågar olika saker.
- **E4 (låg–medel): påfyllda frågor hamnar alltid först** (del 0 före −1), inte i materialets ordning (PX1, PX4, PX6, PF2).
- **E5 (låg): meningsdelaren kräver versal eller siffra efter punkt.** "… i vatten. pH-skalan går …" blev en mening (PX2).
- **E6 (låg–medel): foto-prov får ingen `<language>` i anteckningar och frågor**, bara i svaren (PF2). Text-prov får den (PX3).
- **E7 (låg):** påfyllningen ber om saknade + 2 frågor också när de oanvända meningarna inte räcker, och `<used_sentences>` räknar meningar vars frågor senare togs bort (PX6).
- Dessutom ersätts `questions_possible` alltid med slutantalet. Det verkar meningen, men står inte i prompten.

**Provläge (prompt):**
- **T-a (låg–medel):** `<last_assistant_turn>confirmation</last_assistant_turn>` skickas när förra turen var en kontrollfråga (T2, T3). Systemprompten säger då "take it as 'yes'", vilket krockar med noten att svaret gäller kontrollfrågan.
- **T-b (låg):**
  - ingen REL-tagg passar ett svar på en kontrollfråga;
  - noten nämner ‹profile› som inte skickas;
  - engelskt förhör har svenska utlösare i noten och en svensk sammanfattning;
  - "A-nivå" står mot "svar med ett ord".

**Provets promptar (låg):**
- **P-a:** planen säger "exactly questions_possible plus at most 6 extra", och `<count>` är begärt + 6, så modellen ser aldrig det begärda antalet.
- **P-b:** "tre av fyra frågor varför/hur" står mot "Varför bara när materialet säger orsaken", för korta faktatexter.
- **P-c:** svarsprompten säger "a concrete example when it helps" och samtidigt "Never add … examples the question did not ask for".
- **P-d:** inget sägs om förkortningar som BC/AD, romerska siffror, pH och ATP i talet.

## Inte prövat
- Hur riktiga modellen läser riktiga foton (handstil, sneda sidor).
- `parse` för ett uppladdat prov med poäng och bedömning.
- Provets ljud och kostnad vid spara (`/drill`).
