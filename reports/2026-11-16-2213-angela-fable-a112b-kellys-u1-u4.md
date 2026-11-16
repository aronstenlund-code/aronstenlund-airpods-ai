# A112b: Kellys U1–U4 för A112 (D200) (Angela Fable, moln)

2026-11-16 22:13. Underlag: `reports/2026-11-16-2100-kelly-granskning-a112.md`. Bygger på A112
(`reports/2026-11-16-2059-angela-fable-a112-upplasningen-avstangd.md`).
**Inget är provat på telefon. Inga ElevenLabs-anrop (D180).**

## Vad som gjordes
| Fynd | Nu | Sedd på bild |
|---|---|---|
| U1 Starta prov lika för frågor och text | **Blå för båda** när uppläsningen är av. Appen frågar servern en gång till (kostar inget, K78). Går ljudet fortfarande inte att göra öppnas spelaren ändå, utan ljud, med texten. Också från provkortet på Start | ja (provets skärm ostartat, startat utan ljud, en text) |
| U2 inga ▶/⏸ när ljud saknas | Textspelaren visar bara ⏮ ⏭, markeringen och tryck på en mening. Tryckraden: "●● Nästa mening · ●●● Förra meningen". Raden "Pausad …" visas inte | ja |
| U3 svaret i en ScrollView, Avsluta fast | Svaret skrollar i spelaren med största text; Avsluta ligger fast nederst (gjort redan i A112) | ja (SE, största text) |
| U4 hur man går till nästa fråga utan ljud | Frågespelaren har knapparna **Förra frågan** och **Nästa fråga** ovanför Avsluta när den väntar på ljud som inte kommer | ja (17 Pro och SE, största text) |

## Hur det fungerar
- **Bara utan ljud.** Knapparna finns när spelaren väntar på en frågas ljud och uppläsningen är av. En fråga som
  spelas går inte att hoppa över (D142 gäller som förut).
- **Runt listan.** Efter sista frågan kommer första, och före första kommer sista. Platsen sparas, så Fortsätt
  kommer tillbaka dit.
- **Inget räknas för hand:** inget varv och ingen övad dag (D194 räknar spelade frågor).
- **AirPods-trycken** byter inte fråga i det läget; bara knapparna på skärmen. I textspelaren gör 2 och 3 tryck samma
  sak som ⏭ och ⏮, som förut.
- **Kontrollskärmen** ("Styr med dina AirPods") hoppas över när uppläsningen är av: det finns inget ljud att prova
  trycken mot.
- Provet är fortfarande ostartat på servern, och nästa Starta prov gör ljudet när saldot är tillbaka.

## Tekniskt
- `RepetitionPlayer.stepByHand(_:)`, `RepetitionSession.stepQuestion(by:)`, och `RepetitionModel.start` öppnar
  spelaren som text (`showAsText`) när `isReadingAloudOff` gäller och inget ljud finns. Det är Angela Schrutes
  filer; punkten lades på mig.
- Vyerna: `DrillView.swift`, `RepetitionPlayerView.swift`, `ReadingViews.swift`, `RepetitionHomeSection.swift`.
- Mellansteget där Starta prov doldes för frågor (på min gren, aldrig på main) är borttaget.

## Testresultat
- **2 nya tester** (`A112bStepByHandTests` i `LumenTests/A112ReadingAloudOffTests.swift`): spelaren utan ljud stegas
  för hand runt listan och platsen sparas, och en fråga som spelas hoppas inte över. Tillsammans med A112: 8 tester.
- **iOS build 43953213889 grön** (min gren, 06d5b41): device-bygget, varningar som fel, LumenTests. *Verifierat i CI.*
- **iOS build 43945005388 grön på main** (2803bf5, A112:s första version). *Verifierat i CI.*
- **Sedd på bild av mig** (simulatorn, inte enhet): Fable screens 43953233383 (iPhone 17 Pro, ljust och mörkt) och
  43953239346 (iPhone SE, största text). `reports/2026-11-16-a112-bilder/a112b-*.jpg`, grenarna
  `fable/screens-a112b-17pro-1` och `fable/screens-a112b-se-xxxl-1`.
- **Kelly har godkänt** U1–U4 från 17 Pro-bilderna (`reports/2026-11-16-2203-kelly-granskning-a112b.md`).
- **Inte testat:** att ett tryck på Starta prov verkligen öppnar spelaren som text mot servern
  (`x-earmind-test: unavailable`), och att knapparna byter fråga (bilderna är stillbilder; stegningen är testad i
  enhetstestet). Tobys T24 loggar det. *Untested i appen.*

## Kvar (Kelly, låga)
- **Förra frågan ska vara grå på första frågan.** I dag går den runt till sista. Ändras i nästa push.
- Kellys förslag Ke67: startsidan utan prov ska nämna läsläget. Nästa push.

## Nästa session
Läs Tobys T24 i läget unavailable (toby/t33) när A112b ligger på main.
