# A118 (D208): Kellys K1–K3 för A115–A117 (Angela Fable, moln)

Klart 2026-11-17 03:05. **Verifierat i CI och på simulatorbild, inget på enhet.** 0 ElevenLabs (D180).

## Vad som är gjort
- **K1, en prisrad:** bladet "Frågor kvar" visar "En fråga · 1" så länge serverns tabell ger samma tal för alla
  längdklasser. Ger servern olika tal kommer de tre raderna (Vanlig, Lite längre, Mycket lång) tillbaka. Talen
  läses ur kvotsvaret (K82), inget är hårdkodat. (`CreditsText.rows`)
- **K2, största text:** platshållaren är "Skriv här" vid tillgänglighetsstorlekarna. Knapparna i Säg-fältet läggs
  med `ViewThatFits`: en rad; annars +, Hur länge och tempo på en rad och Spela under; annars varje knapp på egen
  rad. Inget kapas med "…". (`SayViews.swift`)
- **K3, bladets höjd:** full höjd vid största text; annars 64 % av skärmen (kan dras till full), så att fotnoten
  ryms.
- **R1 (Kellys omgång 2):** "En gång" syntes inte i knappen på 17 Pro. Orsaken var `Label` i menyknappen, som
  tappade orden, inte `ViewThatFits`. Nu är det bild och text i en `HStack`.
- **R2:** den vita bilden av bladet på 17 Pro är omtagen. Tomma bilder har varit fångstfel i körningen, inte appfel.

## Avvikelse från Kellys K2
På iPhone SE med största text ryms +, Hur länge och tempo på **en** rad med Spela under, så `ViewThatFits` väljer
det och inte en knapp per rad. Inget kapas. Kelly godkände K2 på den formen i omgång 2.

## Tester
- **iOS build 43996508869 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- Testet för prisraderna är utbytt mot två: en rad när alla längder kostar lika; tre rader (1 / 1,5 / 2) när
  serverns tal skiljer sig. A116/A117-filen har nu 8 tester.
- **A116/A117 på main: iOS build 43987825974 grön.**
- **Uppföljning 03:37: A118 på main, iOS build 44000481484 grön. Kelly godkände bilderna (omgång 3).**
- **Bilder** i `reports/2026-11-17-a118-bilder/` (grenarna `fable/screens-a118-17pro-3` och
  `fable/screens-a118-se-xxxl-3`): 17 Pro ljust och mörkt, SE största text ljust och mörkt. Sedda: en prisrad,
  fotnoten ryms, "En gång" syns, "Skriv här", inget kapat.

## Otestat (antaganden)
- **Menyn bakom "+" finns inte på bild** (Kelly bad om det). Bildflödet startar appen i en scen och kan inte trycka;
  det behöver ett UI-test (Tobys T36) eller en scen som visar menyns rader utfällda.
- Varianten med en knapp per rad i Säg-fältet har ingen bild (ingen skärm i körningen är så smal).
- Inget på enhet.

## Kända brister
- På SE med största text börjar "Räknas som 1 fråga" under skärmens kant när fältet har mycket text; man rullar dit.

## Nästa session
- Kelly ser bilderna. Toby: T36 med +, länk och kreditkapseln.
