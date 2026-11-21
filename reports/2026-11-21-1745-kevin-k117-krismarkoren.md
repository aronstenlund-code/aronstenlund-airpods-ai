# K117 (D256): modellens krismarkör kontrolleras när koden inte ser fara

Kevin (moln), 2026-11-21. **0 ElevenLabs.** Testkonton.

- **Tester:** **842/842**.
- **Commit:** 66e2a2bb, deployad av deploy-backend 368.

## Vad som ändrats
- **När kontrollen körs:** modellen markerar kris (`[[KRIS]]` först i svaret, `[[KRIS]]` senare i svaret, eller Autos `self_harm_risk`), men kodens kristest (`crisisLevel`) hittar inget i frågan och inte hos de andra som pratar. Då körs samma kontroll som för svaga träffar (`CRISIS_CHECK_PROMPT`, högst 5 tokens, 4 s) en gång på frågan.
- **Bara ett tydligt "nej"** ignorerar markören. Svaret får vara "nej" eller "Nej." och inget annat.
  - Allt annat ger krisvaret som förut: fel, tidsgräns, "ja", tomt svar, "Osäker" och "Nej?? ja".
  - Loggarna: `crisis_marker_ignored`, `crisis_marker_kept` och `crisis_marker_check_failed`.
- **Efter ett tydligt "nej":**
  - **Markören först i ett direktläge**, och modellen skrev inget mer: svaret görs om en gång. En ny markör ger krisvaret utan ny kontroll.
  - **Autos `self_harm_risk`:** svaret efter metaraden läses som vanligt, också texten som kom i samma bit som raden. Metan skickas utan krisflaggan.
  - **En sen markör** (efter text): texten står kvar, och krisvaret läggs inte till.
- **Orört:**
  - Kodens egna starka träffar (krisvaret direkt, inget modellanrop).
  - O17 (svaga träffar kontrolleras som förut).
  - O42 (korta telefonkommandon).
- **Tillsammans med K116:** "recept på ris" med en ignorerad markör går vidare som ett sökt recept. Det hålls inne tills källan finns, annars blir det den fasta meningen.
- **Två äldre tester ändrades.** I K23-testerna i `answer/k21_test.ts` svarade den falska kontrollen alltid "nej", också på tydliga indirekta tecken ("allt känns meningslöst nu"). Den svarar nu "ja", så som `CRISIS_CHECK_PROMPT` är skriven att svara på indirekta tecken. Krisvaret kommer som förut.

## Tester (`answer/k117_test.ts`)
- "recept på ris" med markör och kontrollen "nej" ger receptet med källa.
- Fel, tidsgräns, "ja", tomt, "Osäker" och "Nej?? ja" ger krisvaret.
- En andra markör efter "nej" ger krisvaret, med en enda kontroll.
- En sen markör med "nej" ger bara texten; med "ja" kommer krisvaret.
- Auto med "nej" ger svaret efter metaraden.
- En tydlig krisfras får krisvaret i koden, utan modellanrop.

LIVE

## Till Deangelo: en fråga om språket i /answer (D253)
- **Hur det är i dag:** när både `language` och `lang` skickas vinner `language` (`answer/validate.ts`). Angela Fables app skickar `language` = språket man pratar och `lang` = valet i appen, som är engelska tills man väljer svenska. En svensk som har kvar engelska i appen och frågar på svenska får alltså svar och talregler på svenska.
- **Enligt D253** ("lang från valet ska styra både svarsspråk och talregler") skulle svaret i stället bli engelska.
- **Fråga:** ska valet vinna även när man pratar ett annat språk? Ett förslag är att svaret följer språket man pratar men felmeddelanden och appens texter följer valet, som nu.
- Jag ändrar inget förrän du svarat.

## Svar till Angela Schrute (lyssnarpasset)
- Gränsen per pass ligger på sidan, 30 minuter. Servern kan inte stänga Scribe-sockeln, eftersom den går direkt mellan webbläsaren och ElevenLabs.
- Servern begränsar antalet pass (20 per nät och dygn, 150 för webben), inte tiden.
- Hela svaret finns i hennes kö.

## Till Oscar
- Räkna `crisis_marker_ignored` i live-evalen (function_logs) som en egen rad, så att en verklig miss syns.
- Ett ignorerat fall där frågan ändå var ett krisfall är ett allvarligt fynd och ska till mig och Deangelo direkt.
