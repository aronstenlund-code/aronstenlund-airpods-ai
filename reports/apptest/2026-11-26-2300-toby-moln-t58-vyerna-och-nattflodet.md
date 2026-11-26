# T58 del 2: Spela in själv genom vyerna, och nattflödet mot main (Toby (moln), 2026-11-26 23:00)

Uppdrag: Deangelo 2026-11-26 22:41 (effort high). Del 2 av T58 är en E2E genom vyerna (A165): skapa samling, fråga och svar, låtsasinspelning, öva, krediterna oförändrade, inga nätanrop, och bladet när servern svarar 402 eller `provider_quota`. Sedan körs hela nattflödet mot main, och testerna som blivit röda av A164–A167 rättas. 0 ElevenLabs.

## 1. I testprocessen (OwnDeckE2ETests): grön

Körning 45905700391, Apptest own deck, `toby/t58b` a8fe8048 = main med A166. Simulator iPhone 17 Pro, iOS 26.5, Xcode 26.6. Samma fyra fall var gröna igen i 45908945834.

| Fall | Utfall | Anrop | Krediter |
|---|---|---|---|
| make-record-practise | ok | 0 under övningen | 1500 → 1500 |
| seeded-practise (`-SeedOwnDeck 1`) | ok | 0 | 1500 → 1500 |
| sheet-credits (`/exam` 402 `quota_exceeded` med `fits` 1) | ok | 2 × `/exam` (stoppade i testet) | 1500 → 1500 |
| sheet-modelDown (`/exam` 503 `provider_quota`) | ok | 2 × `/exam` (stoppade i testet) | 1500 → 1500 |

- **Bladet vid 402:** första nejet ger bladet "Slut på krediter?" / "Spela in dina egna frågor och svar – helt gratis.". Inte nu stänger det. Nästa nej för samma tillfälle visar inget blad. Inget prov görs.
- **Bladet vid `provider_quota`:** titeln är "Kan inte skapa prov just nu?" med samma rad. Knappen sätter `opensDecks`, så Start öppnar Spela in själv. Nästa nej visar inget blad.
- **Övningen** (verifierat i CI):
  - Spelaren gick question 0 → thinking 0 → (ett tryck) answer 0 long → question 1 → thinking 1 → question 0, ett helt varv.
  - Kort 1 hördes med egen inspelning och kort 2 med telefonens röst.
  - Inspelningarna ligger i `Application Support/OwnDecks/audio`, utanför säkerhetskopian. Provlagret ändrades inte.
- **En gång röd:** körning 45902890074 fastnade på "question 0" i 90 s, med samma kod som är grön före och efter. **Untested assumption:** att telefonens röst (AVSpeechSynthesizer) i Simulatorn ibland tar för lång tid. Jag håller ögonen på det i nattflödet.
- T57 väntar nu på Kellys nya ord: "Rättat på telefonen: Rätt." / "Checked on your phone: Right.".

## 2. Genom vyerna (OwnDeckFlowTests, XCUITest)

Körning 45908945834. Runnerns nät är avslaget (`networksetup`) från samlingens skärm tills spelaren har spelat.

| Steg | Utfall |
|---|---|
| Ny installation: Välkommen → Fortsätt → samtycket (A166) → Senare → Start | ok |
| Start: `home.ownDecks` "Spela in själv – helt gratis" öppnar en ny samling | ok |
| Namn, fråga och svar i första kortet | ok |
| Spela in → Stoppa för frågan och svaret (`-FakeOwnRecorder 1`) | ok, "Spela upp frågan, 2 sekunder" och "Spela upp svaret, 2 sekunder" |
| Lägg till fråga, kort 2 med bara text | **röd i testet:** kort 2:s Svar fick aldrig tangentbordet (rättas, se nedan) |
| Öva utan nät | spelaren öppnas utan nät: "Fråga 1 av 1, Egen inspelning" (kort 2 saknade svar, så bara kort 1 kan spelas) |
| Start efteråt | samlingen "T58 Biologi, Egen inspelning · 2 frågor", krediter "1,5k krediter kvar" före och efter |

Rättningen av steget med kort 2: ett fält som växer finns mer än en gång i trädet, så testet tar nu fältet bland textvyerna och det sista för det nya kortet (52256b2b). Det körs när en macOS-maskin är ledig; **resultatet läggs till här**.

Inget fynd i appen hittills. Bladet testas i processen, inte genom vyerna: UI-testet kan inte få servern att säga nej när det behövs, och ett nytt konto kan inte be om ett prov (se 3).

## 3. Nattflödet mot main

Senaste natten (45803901837, main acd66539):

| Test | Utfall |
|---|---|
| T27 | grön |
| T29 | grön |
| T30 | grön |
| T36 | grön |
| T24 | röd sedan 2026-11-21/22 |
| T28 | röd sedan 2026-11-21/22 |

- **T24 och T28 röda (verifierat i CI, skärmens text):**
  - Ett nytt konto i Simulatorn har 1,5k krediter, och Nytt prov säger "Ett prov med 3 frågor kostar cirka 2,0k krediter. Du har 1,5k.". Skapa frågor är grå med Fyll på, vilket är rätt enligt A154.
  - Välkomstkrediterna (5 000) kräver App Attest, som Simulatorn inte har.
  - Därför faller allt efter Skapa frågor: Frågor och svar, Gör med ChatGPT, Dela, Publicera, Mina svar och Läs upp texten ("Stämmer det här? not shown in 180 s").
  - Det är inte A164–A167 och inte ett fel i appen. Det kräver Kevin: ett pris för testtrafiken eller välkomstkrediter utan App Attest. Raden står i `prompts/queue/kevin.md`.
- **A166 (ny första start) i testerna:**
  - Skärmturen fotar nu samtycket och går vidare med Senare (`firstStart.later`).
  - T24 går Senare → Start → Nytt prov, eftersom Nytt prov inte längre öppnas av sig självt efter Fortsätt.
  - Ändringarna ligger på `toby/a166-tests`. De andra flödena (A107, T27, T28, T30, T36) trycker redan på Senare efter Fortsätt.
  - Nattflödet med `tests_ref=toby/a166-tests` körs när macOS-maskinerna är lediga; **resultatet läggs till här**.
- **Skärmturen med id:n i Inställningar** (från A164) ligger på main (c949861c): pro-light och liten-light gröna, 47 bilder och 0 saknade (45794689351).
  - **Att se över:** på SE tog Start cirka 15 min i turen, mot 1 min dagen innan. Varje tryck på Start väntade cirka 2 min, medan Inställningar var lika snabbt som förut. Det kan vara något på Start som aldrig blir stilla, så att XCUITest väntar. **Untested assumption.** Jag jämför med nattens tur innan jag skriver det som ett fynd.

0 ElevenLabs, inga anrop till /answer. T1 är fortfarande röd med flit (D180). Allt är Simulator, aldrig en verifiering på enhet. **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.
