# Kelly (moln): granskning av A112 (D200: uppläsningen avstängd, texten fungerar)

Underlag: `reports/2026-11-16-a112-bilder/` (a112-efter-rattning.jpg är den senaste; 17 Pro ljust och mörkt, SE
största text). **Simulatorn, inte enhet.** Inga ElevenLabs-anrop.

## Resultat: godkänd med U1–U3 (medel) och U4 (låg)
Raden "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." står en gång, under Starta prov och i
spelaren. Hela svaret under varje fråga i listan, i textfärg, är bra: det är det som ersätter ljudet. Inget rött och
inget som låter som ett fel. Den gamla meningen i `repetition-texter.md` är ersatt (ny rad för D200).

| # | Nivå | Var | Fynd | Rättning |
|---|---|---|---|---|
| U1 | medel | repOffUnstarted / repOffText | Starta prov är **blå för frågor men grå för en text**. Samma läge, två svar. | Samma för båda. Mitt förslag: blå i båda, och spelaren visar texten (frågor: fråga och svar; text: den löpande texten) och går framåt med trycken som vanligt. Går det inte för en text, dölj knappen i stället för grå, som D198 gör med Dela. |
| U2 | medel | repOffTextPlay | Spelaren för en text visar ⏸ och tryckraden som om något spelas, fast inget ljud finns. | Utan ljud: ▶/⏸ bort. Kvar: ⏮ ⏭ (byt mening), markeringen och "Tryck på en mening för att börja där." Tryckraden: "●● Nästa mening · ●●● Förra meningen". |
| U3 | medel | repWaitingProblem, SE största text | Svaret kapas med "…" ("cellandninge…"). Nu när svaret är innehållet måste det synas helt. | Svaret i en `ScrollView`, Avsluta fast nederst. |
| U4 | låg | repWaitingProblem | Hur man kommer till nästa fråga utan ljud syns inte (bara Avsluta). | Om trycken byter fråga: raden "● Nästa fråga" (eller det som gäller) under texten. Säg i rapporten hur det fungerar, så skriver jag texten. |

## Nästa steg
Angela Fable: U1–U3, och svar på U4.
