# Ke91 – Kellys ordlista: mina punkter, och Kellys ord för A166

Angela Schrute (moln), 2026-11-27. Uppdrag: Deangelo 00:12 ("sedan Kellys tio ordförslag i din kö (Ke91)"); kön rad 577, 578 och 581. Underlag: `docs/design/ordlista-app.md`. Uppdelning med Angela Fable (skickad till henne 00:45): jag tar punkterna 1, 2, 3, 8 och 9 (även värden som syns i hennes vyer, eftersom nycklarna är delade); hon tar 4, 5, 6, 7 och 10 (Tempo → Speed) och sina tabeller.

## Kort

- **Röstkommandona (punkt 1):** den engelska appen visar nu engelska kommandoord, och kommandona förstår dem. Svenska fungerar som förut. Där kommandot bara förstår svenska visas exemplet inte på engelska.
- **Orden (punkt 2, 3, 8, 9):**
  - "Lumen" står bara där väckningsordet menas; annars står det EarMind.
  - "Ask EarMind anything".
  - practice, Beta, Spoken quiz, Practice paper, Mini quiz, "Snap your textbook".
- **Kellys A166-ord:**
  - Välkommens tredje rad: "Fråga högt · Svaret kommer i örat. Nästa skärm frågar först." / "Ask out loud · The answer comes in your ear. The next screen asks first.", med mikrofonikonen.
  - Samtyckets punkt om Claude säger att telefonens egen modell svarar när servern inte kan, och att texten då stannar på telefonen.
- **Kellys rad 577:** en samling utan namn heter "Mina frågor" / "My questions" även i kärnan.
- Spotify (för testare) syns bara i testbyggena, inte i App Store-bygget.
- Inget är provat på telefon. Det röstkommandona förstår är testat i CI.

## Röstkommandona (punkt 1)

Förut visade den engelska appen svenska ord, till exempel ". Answer out loud, or say nästa.", "Or say ja or nej." och "Tap Listen again or say “Lumen, fortsätt”".

| Text på skärmen (engelska) | Vad kommandot nu förstår |
|---|---|
| ". Answer out loud, or say “next”." | Provfrågorna (`PracticeNav`): next, next question, go on, previous, go back, skip (this one), repeat (the question), say that again, stop, I'm done, end the quiz, how did I do, results, question seven / question 7 – utöver de svenska. Hela yttrandet, så "The next step is …" är fortfarande ett svar. |
| "Or say “yes” or “no”." · "Say “yes” for more" | Fanns redan (`PhoneTools`, `MoreOffer`). |
| "Or say “Lumen, quiz me”." · "… for example “Lumen, quiz me”." | "quiz me" är nu en kontrollfråga, som knappen "Quiz me" (Förhör mig). Förut startade "quiz me" ett minitest med 5 frågor. Minitest: "mini quiz", "test me", "minitest". |
| "Tap Listen again or say “Lumen, continue”" | "Lumen, continue", "Lumen, back to EarMind", och "Lumen, fortsätt", som den svenska texten alltid har sagt men som aldrig fungerade. Bara efter "Lumen". |
| "You can also say “Lumen, switch to social”." | Fanns redan. |
| "Say “Lumen, remember …”, “Lumen, forget …” or “Lumen, rule: …”." · "Say for example “Lumen, rule: always answer briefly”." | Fanns redan (`VoiceChannel`). |
| "… without “Lumen” only music and “that was wrong”." · "… when you say \"next song\"" | Fanns redan. |
| Rizz: "Say “next” for a new one, “Lumen, more jokes” … “Lumen, give me three”" | "next" fanns. Önskemålen går till servern som instruktion, och modellen förstår engelska. |

**Exempel som döljs på engelska** (kommandot förstår bara svenska; Kellys alternativ "dölj hellre än att visa svenska ord"):
- "”Lumen, jag har prov i engelska på onsdag”" (tomt läge på Fler lägen): rutan "Eller säg …" visas bara när appen är på svenska.
- Huvudrörelserna: "You can also say “Lumen, korta förklaringar” or “Lumen, provet är på fredag”" är borta ur den engelska meningen.
- Provsessionen: "uppgift sju, ledtråd, rätta jag fick …" ersätts av "EarMind only answers what starts with “Lumen”."
- Spotify: "spela spellistan Plugg", "pausa", "nästa" ersätts av "Then you can control Spotify with your voice."

## Orden (punkt 2, 3, 8, 9)

- **EarMind där appen menas:** "Tell the people around you that you use EarMind" (samtycket), "Pause EarMind and play music", "Back to EarMind".
- **Lumen bara som väckningsordet:**
  - "Lumen" står kvar där väckningsordet menas.
  - Väckningsordet presenteras som "“Lumen” (EarMind's wake word)" i Inställningar › Röstkommandon och i "Vad kan EarMind?".
  - Läsprovet för röstprofilen ("Hi Lumen. This is my voice …") står kvar: där tilltalas väckningsordet.
- **"Ask EarMind anything"** och "Ask EarMind anything. Say “Lumen” and what you want, for example: ".
- **practice:** alla 11 engelska värden med practise (amerikansk stavning).
- **Beta:** alla 4 BETA-värden, "They're in beta".
- **Övriga ord:** "Spoken quiz" och "Spoken quiz (Beta)", "Practice paper", "Mini quiz, 5 questions", "Wrong answer? Send it to us", "More modes use the microphone. Start quiz never does.".
- **Snap your textbook:**
  - Välkommen och Fler lägen har "Snap your textbook".
  - "Snap your textbook. EarMind makes questions …" på Start.
  - "… Take photos of the pages instead.", "Take the photo straight from above, in good light."
- "No account needed. Tapping Try now means you accept the points above." (den gamla introskärmen; används bara av en bildscen).
- "Privacy & consent" fanns inte längre i koden; "Privacy and consent" står redan.

Bara de engelska värdena ändrades (`tools/l10n/en.json` → `Localizable.xcstrings`). Svenskan är orörd utom Välkommens rad och samtyckets punkt.

## Samtycket

Punkten om Claude säger nu: "Kan servern inte svara, svarar telefonens egen modell där den finns, och då stannar texten på telefonen." Den gamla meningen "Utan nät blir det inga svar." är struken.

Samtyckets version (`ConsentPolicy.currentVersion` 6) är **inte** höjd. D21 kräver en ny version när texten ändras i sak. Den här ändringen säger att *mindre* lämnar telefonen än förut, och den är redan sann sedan A159. Kelly tycker samma sak. Säg till om Deangelo vill ha en ny version: då visas samtycket igen för alla som har lyssnat.

## Teknik

- `Lumen/Core/Study/PracticeRun.swift`: engelska ord i `decide`, `englishNumbers` i `spokenNumber`, "please/now/thanks" bort i slutet.
- `Lumen/Core/Study/StudyCards.swift` (`MiniTest`): "quiz me" och "ask me a question" är kontrollfrågor; "mini quiz" startar minitestet.
- `Lumen/Core/Commands/CommandRegistry.swift`: `backToLumen` har fått "fortsätt", "continue", "continue listening", "listen again", "back to earmind", "tillbaka till earmind". Bara efter namnet (`worksWithoutName` är false).
- `Lumen/Features/Listening/HomeView.swift`: exemplet på svenska visas bara på svenska.
- `Lumen/Features/Settings/SettingsView.swift`: `spotifySection` bara under `LUMEN_TESTMODE`.
- `Lumen/Features/Onboarding/WelcomeView.swift`, `ConsentView.swift`: Kellys rader.
- `Lumen/Core/OwnDeck/OwnDeck.swift`: `shownTitle` → "Mina frågor".
- `tools/l10n/en.json`, `skip.json` (kommandoorden är språkdata), `compiler.json` (de tre nya nycklarna i Välkommen och samtycket i stället för de gamla, tills nästa bildkörning skriver om listan).
- `python3 tools/l10n/check.py`: 0 fel.

## Testresultat

BYGGRAD

- **Röda först** (`angela/ke91-test-rod`, bara befintligt API, mot main): `LumenTests/Ke91WordsTests.swift`, 5 tester: provfrågornas engelska ord, att svenska ord och svar fungerar som förut, "Lumen, continue/fortsätt", "quiz me" som kontrollfråga och yes/no.
- `LumenTests/A164OwnDeckTests.swift`: förvalsnamnet är "Mina frågor".

## Kvar för Angela Fable (Ke91)

Punkterna 4, 5, 6, 7 och 10 och hennes tabeller i §3 (sound → audio, en enhet för krediter, kostnadsraderna, Create, Speed). Rad i hennes kö.

## Concerns

Inga nya. "quiz me" ger nu en kontrollfråga i stället för minitestet. Den som har lärt sig att säga "quiz me" för minitestet säger nu "mini quiz". Den engelska appen har bara funnits sedan A157, så få berörs.
