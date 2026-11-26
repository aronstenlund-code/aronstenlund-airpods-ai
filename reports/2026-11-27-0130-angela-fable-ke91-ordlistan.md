# Ke91: Kellys ordlista i repetitionsvyerna (engelska)

Angela Fable (moln), 2026-11-27. Beställt av Deangelo 00:10 ("Kellys tio ordförslag"). Underlag:
`docs/design/ordlista-app.md` (Kelly, Ke91). **Bara engelskan är ändrad; svenskan är som förut.**

## Vad som är ändrat (mina vyer)

- **sound → audio** i allt skapat ljud: "Creating audio …", "Audio: 4 of 6 ready", "The audio is created when you
  start", "The audio downloads when you start", "· audio ready", "Shared/Published when the audio is ready", "Previews
  are free. A new voice means new audio.", "1 character of new audio", "If you save a change, only this question gets
  new audio.", fel- och nätrader om ljud. **Kvar som "sound":** "The sound stays on your phone" (egen röst, Kellys
  undantag), "How should it sound?" och integritetstexterna (Angela Schrutes).
- **Make → Create:** "Create", "Create questions", "Create with ChatGPT" (också i raden om ChatGPT).
- **practise → practice** överallt i katalogen (amerikansk stavning, Kellys regel för båda).
- **BETA → Beta**, "They're in beta and keep getting better."
- **Tempo → Speed** ("Speed", "Speed, normal", "Speed, 1.25 times").
- **Röstbladets rubrik:** "Röster" / "Voices" (förut "Svenska röster" / "Swedish voices"); katalogen har ett språk.
- **"To review" → "Under review"**, "Come prepared to the quiz" → **"Be ready for your quiz"**, "Something wrong?
  Write it" → **"Something wrong? Tell us"**, "Opens the set" → **"Opens the quiz"**, "Get others' quizzes" →
  **"Find quizzes from your school"**, "Shows what costs what" → **"Shows what things cost"**, "1 per … characters" →
  **"1 credit per … characters"**, "Quiz name" / "Quiz name, optional" → **"Quiz name (optional)"**, "Not enough
  credits for a/the quiz" → **"Not enough credits for this quiz."**, "Photograph your material …" → **"Snap your
  textbook. EarMind creates questions and answers …"**, "… Photograph the pages instead." → **"… Take photos of the
  pages instead."**

74 engelska texter är ändrade (`tools/l10n/en.json` → katalogen).

## Inte gjort, och varför

- **Punkt 5 (frågor bredvid krediter) är gjord i mina vyer:** konton som räknar krediter ser nu "Inga krediter
  kvar." / "Du har inga krediter kvar. Nya krediter kommer den 1 …" ("You're out of credits. They refill on … 1.") i
  Nytt prov, ChatGPT-importen och hjälpchatten, och raden om "en fråga per påbörjade 800 tecken" visas bara för konton
  som räknar frågor. Kostnadsraderna (punkt 6) visade redan krediter för de kontona ("Costs 120 credits. Repeats are
  free."); fråge-varianterna finns kvar bara för en server som räknar frågor. Om inga sådana konton finns kvar kan de
  tas bort helt – ett beslut för Deangelo/Kevin.
- **"You can lock your phone. You'll still hear it in your AirPods."** Kelly säger att det inte är provat på telefon
  (D209) och vill att raden döljs tills Aron har provat. Det är en sanningsfråga, inte ett ord, och raden har stått
  sedan A115; jag har inte tagit bort den. **Fråga till Deangelo:** ska den döljas tills Aron har provat?
- Röstkommandona, "Lumen" → EarMind, Välkommen, Hem (Fler lägen) och Inställningar är Angela Schrutes.

## Test

- 2 nya enhetstester (`LumenTests/Ke91WordsTests.swift`): de engelska orden, att svenskan är oförändrad, och att den
  egna inspelningen fortfarande säger "sound".
- KÖRNINGEN
- 0 ElevenLabs.

## Kvar

- Engelska skärmbilder för App Store tar Kelly i sitt flöde.
