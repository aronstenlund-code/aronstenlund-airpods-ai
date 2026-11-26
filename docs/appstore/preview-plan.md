# App Store-förhandsvideo: plan (Kelly (moln), Ke92, 2026-11-27)

**Bara en plan. Inget spelas in, laddas upp eller skickas in utan Arons ja** (TILL-ARON #27). Inget ElevenLabs (D180):
videon har ingen röst och inget ljud ur appen. Engelska först (D253); en svensk version görs efter samma plan.

## Apples krav (verifierat i Apples dokumentation, 2026-11-27)
- 15–30 sekunder, högst 30 bilder/s, H.264 (.mov/.mp4) eller ProRes 422 HQ, högst 500 MB.
- 6,9 tum stående: **886 × 1920**. Upp till tre videor per språk.
- Bara **film ur appen** ("footage captured on device", "only content within the app itself"). Inga händer, ingen
  telefon i bild. Text ovanpå får finnas och rekommenderas, eftersom videon spelar utan ljud. **Inga priser eller
  datum.** Musik bara med rättigheter.
- Affischbilden (det som syns när autouppspelning är av) är som standard **sekund 5**.

## Videon: "Learn it by listening" (26 s, engelska)
Scenerna är desamma som i App Store-bilderna (Ke90), men filmade, inte stillbilder. Texten står i Apple-stil (SF Pro Display Bold, mörk på `#f5f5f7`) i ett band överst, så att appens egen skärm syns oförändrad under. Varje text står i minst 2 s och har högst sex ord.

| # | Tid | Scen (bildflödet) | Det som rör sig i appen | Text på skärmen |
|---|---|---|---|---|
| 1 | 0–4 s | `repSayKeyboard` → `repSayCredits` | texten skrivs i det mörka fältet | **Type what you want to learn.** |
| 2 | 4–8 s | `repSayOnCard` | spelkortet: "● Playing in AirPods", tiden räknar ner | **It plays in your AirPods. Again and again.** ← affischbild vid 5 s |
| 3 | 8–11 s | `repSayPicked` | rösten väljs efter stilen | **Describe how it should sound.** |
| 4 | 11–14 s | `repSayCompress` → `repSayCompressed` | Compress, texten blir kortare, Undo syns | **Long text? Make it shorter.** |
| 5 | 14–18 s | `repTextNew` → `repPlayAnswer` | Nytt prov, sedan frågan och svaret i spelaren | **Snap your textbook. Press for the answer.** |
| 6 | 18–22 s | `listeningActivation` | "● Listening", nivåmätaren, orden "Help me" | **Question you're not prepared for? Say [ … ] so our AI activates.** (Arons mening, D259) |
| 7 | 22–26 s | `repOwnDeck` | korten med Record again, Practice | **Record it yourself. Completely free.** |

Övergångarna är raka klipp eller en toning på 0,2 s, utan zoom och utan effekter (A150: lugnt). Videon slutar på bild 7, så att sista bilden är appen och inte en logga.

**Inte med, med avsikt:**
- **Butiken och lanseringsbladet:** de visar priser och datum, vilket Apple inte tillåter.
- **Raden om låst skärm:** den är inte provad (D209), och appen startas med `say.hasPlayed`.
- **"1,500 credits":** krediterna är inget pris, men "gratis" står redan i bild 7. Kortare blir bättre.

## Ljud
**Utan ljud** är förvalet; Apple spelar videon tyst i listorna. Musik bara om Aron väljer ett spår med rättigheter
(t.ex. ur Apples egna). Ingen berättarröst och inget ur appens uppläsning (D180).

## Så spelas den in (när Aron säger ja)
1. Ett nytt Actions-flöde, likt `kelly-appstore-shots.yml`, på en macOS-maskin (D217):
   - iPhone 17 Pro Max, ljust läge, `-say.hasPlayed YES`.
   - För varje scen i tabellen: `xcrun simctl io <udid> recordVideo --codec h264 <scen>.mp4` i scenens tid plus 1 s.
   - Rådata på en egen gren.
2. Klippning med ffmpeg i molnet:
   - skala till 886 × 1920 (Simulatorns 1320 × 2868 har samma form, 9:19,5);
   - 30 bilder/s;
   - textbandet ovanpå (drawtext);
   - klipp enligt tabellen;
   - H.264 med 10–12 Mbit/s;
   - tyst ljudspår (AAC, 44,1 kHz), eftersom App Store Connect vill ha ett ljudspår.
3. Kontrollera längden (15–30 s), upplösningen och affischbilden vid 5 s, titta igenom och lägg filen och en bild per sekund i `docs/appstore/preview/`.

**Untested assumption:** att scenerna rör sig av sig själva när de startas med `-LumenScreenshot`. Rad 1 (skrivandet), 4 (Compress) och 5 (övergången till spelaren) kräver troligen en kort testkrok eller ett UI-test som trycker. Den biten ber jag Angela Fable om när inspelningen blir av.

## Svenska (efter samma plan)
| # | Text |
|---|---|
| 1 | Skriv det du vill kunna. |
| 2 | Det spelas i dina AirPods. Om och om igen. |
| 3 | Skriv hur det ska låta. |
| 4 | Lång text? Gör den kortare. |
| 5 | Fota boken. Tryck för svaret. |
| 6 | Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI. |
| 7 | Spela in själv. Helt gratis. |
