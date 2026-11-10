# A40 – Svar utan nät på iPhone 15 Pro och senare (Angela, 2026-11-10)

Underlag: beslutet D115 (T2) och kön. **Det här är kod och enhetstester med en falsk modell. Apples modell på
telefonen är inte provad: simulatorn har ingen Apple Intelligence.**

## Vad som gjordes
- **När nätet saknas:** misslyckas ett svar med `AnswerError.offline` frågar AnswerEngine en gång till, nu den nya
  `OnDeviceAnswerProvider`. Den använder Apples modell på telefonen (Foundation Models, `LanguageModelSession`).
  - Instruktionen: svenska, en eller två meningar som går att läsa upp, och att säga att den inte vet i stället för att
    gissa.
  - Svaret börjar med **"Jag svarar kort, nätet är borta."**
  - Det gäller bara frågor (Standardläge och Provläge). Förslagen i de levande lägena gäller det inte.
- **Bara med Apple Intelligence.** Leverantören svarar bara när tre saker stämmer:
  - `SystemLanguageModel.default` är tillgänglig;
  - modellen stöder svenska (`supportsLocale(sv_SE)`);
  - modellen ger ett svar som inte är tomt.

  Annars misslyckas den med `.offline`, och appen gör exakt som förut: "Nätet är borta". Andra iPhones märker alltså
  ingen skillnad. Ett fel räknas en gång och prövas aldrig i en loop.
- **Inget ljud av en halv mening:** hela svaret hämtas först. En modell som fallerar lämnar därför aldrig inledningen
  ensam.
- **Kod:**
  - `Lumen/Core/Answer/OnDeviceAnswerProvider.swift` är ny;
  - `AnswerEngine.offline` är nytt;
  - `AppContainer` kopplar ihop dem.

## Tester
`LumenTests/A40Tests.swift`, med falska leverantörer:
- utan nät svarar modellen på telefonen, och svaret börjar med "Jag svarar kort, nätet är borta.";
- utan Apple Intelligence blir det "Nätet är borta" som förut, och modellen frågas en gång.

## Kända begränsningar
- **Untested assumption:** att Apples modell finns på svenska på Arons iPhone. Svenska sägs ha kommit med iOS 26.
  Jag har inte provat det.
- Utan nät fungerar inte heller Scribe och ElevenLabs. Frågan måste alltså höras av iPhonens egen igenkänning (A45:s
  rad visas), och svaret läses med iPhonens röst.
- Modellen på telefonen är mindre än Claude. Därför är svaret kort, och Lumen säger att det är kort.

## Till Aron
Prova på telefonen: slå på flygplansläget i ett pass och fråga något enkelt, till exempel "vad är fotosyntes".

## CI
Grönt i CI: iOS build 42825071257 (`f557d2a`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna. Foundation Models kompilerar alltså mot iOS 26-SDK:n.
