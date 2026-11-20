# A153 – Spela aldrig bakom tangentbordet (D238) (Angela Fable (moln), 2026-11-19 20:17)

Tobys T53: vid största texten (AX5) låg Spela bakom tangentbordet, och det stora fältet hade inget sätt att stänga
tangentbordet. Uppdraget: Spela ska gå att nå utan att användaren själv döljer tangentbordet.

## Vad som är gjort

1. **Raden över tangentbordet har "Klar"** när det stora fältet har tangentbordet. Fältet har flera rader, så retur
   gör en ny rad; förut fanns inget som tog ner tangentbordet.
2. **Spela står i raden över tangentbordet när kortets egen Spela är skymd.** Samma knapp, samma ord, samma tryck.
   När kortets Spela syns har raden bara "Klar": en Spela åt gången (Kelly Ke72). Kortets egen Spela kliver undan
   (syns inte, och VoiceOver hittar bara en) medan radens står där.
3. **Kostnaden står i knappen** ("Spela i 10 min 120 krediter"), eftersom kortets kostnad också ligger bakom
   tangentbordet vid största texten (Kelly). Räcker krediterna inte är knappen **"Fyll på 120 krediter · du har 88"**
   och öppnar krediter-bladet.
4. **Vid de största textstorlekarna står "Spela" + kostnaden** på alla telefoner utom de bredaste. Radens egna ord
   växer med ungefär en tredjedel där, och hela knappen gick utanför båda kanterna på en iPhone SE. VoiceOver säger
   alltid hela: "Spela i 10 min. Kostar 120 krediter".
5. **I stilfältets rad står ▶ först**, på samma ställe som Spela (Kelly), och heter "Spela i 10 min" för VoiceOver.
   Bredvid den ryms tre av de fyra förslagen på alla telefoner utom de bredaste ("Viskande" ger vika). Räcker
   krediterna inte är ▶ grå och säger "Spela i 10 min, krediterna räcker inte" (Kelly).
6. **En remsa i kortets färg ligger under raden**, från där tangentbordets rad börjar ner till tangenterna. Raden är
   glas och flyter över listan; utan remsan syntes kortets text och knappar igenom. Remsan avslutar också listan där,
   så raden man skriver på hålls ovanför.
7. **Raden "Nytt prov / Öppna länk" kliver undan medan tangentbordet är uppe.** Den red upp på tangentbordet och tog
   53 punkter av rummet; på iPhone SE låg den över fältets egen Spela.
8. **Ett drag i listan på Start tar ner tangentbordet med fingret** (systemets vanliga beteende i listor).

Beslutet står i DECISIONS (D244).

## Tekniska detaljer

- `Lumen/Features/Repetition/SayKeyboard.swift` (ny): `hidesPlay(button:keyboardTop:)` (knappen är skymd om dess
  underkant ligger under tangentbordets överkant minus 4 punkter, eller om den har rullats bort uppåt; omätt knapp
  räknas som skymd), `top(from:)` (tangentbordets överkant ur systemets avisering), `stripHeight`, `isNarrow`,
  `costWords`, `playWords`, och `Geometry` (knappens och tangentbordets lägen utanför vyns tillstånd, så att
  kortet bara ritas om när svaret skymd/syns ändras).
- `SayViews.swift`: en `.toolbar` med `ToolbarItemGroup(placement: .keyboard)` utanför kortet (inne i kortet ärvde
  raden kortets mörka läge, ljusa bläck och monospace och gick inte att läsa på glaset); `keyboardPlay(compact:)`;
  kortets Spela mäts med `onGeometryChange` i skärmens koordinater.
- `RepetitionHomeSection.swift`: remsan i `safeAreaInset(edge: .bottom)` i stället för nedersta raden medan
  tangentbordet är uppe; `.scrollDismissesKeyboard(.interactively)` på listan.
- Mätt i bilderna (iPhone 17 Pro, iOS 26): systemets avisering ger tangentbordets överkant **med** raden över (491),
  tangenterna börjar vid 540, och skärmens eget innehåll slutar vid 525. Remsans höjd räknas ur de två mätta värdena
  (34 punkter där); på en telefon med hemknapp blir den en punkt och dess färg når ner.
- Tangentbordet och dess rad är mörka också i ljust läge, eftersom kortets fält alltid är mörka. Därför har remsan
  kortets färg och inte skärmens ljusa.

## Testresultat

- **9 nya enhetstester** (`LumenTests/A153KeyboardTests.swift`): skymd/syns med Tobys mått (knappen på 670–714 av
  874), omätt knapp, tangentbordets avisering, remsans höjd, smal rad, kostnadens och knappens ord. **Verifierat i
  CI**: iOS build 44588569598 på min gren (bygget för enhet utan varningar, alla enhetstester). Main-bygget: se
  tillägget nedan.
- **Sett i Simulator (bilder), inte på enhet:** iPhone 17 Pro och iPhone SE (3:e generationen), standardtext och
  största text (AX5), ljust och mörkt. Sex scener per uppsättning. Sju bildrundor; det som rättades efter bilderna
  står under "Vad bilderna visade".
- Bilderna till Kelly: `reports/2026-11-19-a153-bilder/` (åtta ark: `17-pro-standard-ljust.jpg`,
  `17-pro-storsta-text-ljust.jpg`, `se-standard-ljust.jpg`, `se-storsta-text-ljust.jpg` och samma i mörkt). I varje
  ark, från vänster: långt kort med stora fältet i fokus, samma med stilfältet i fokus, kort text, för få krediter
  (88 kvar, 120 kostar), för få krediter med stilfältet i fokus.
- 0 ElevenLabs. Ingen server, inget ljud.

## Vad bilderna visade (och som rättades)

- Raden "Nytt prov / Öppna länk" låg ovanför tangentbordet och över kortets Spela (SE).
- "Klar" och stilförslagen ärvde kortets utseende och gick inte att läsa på glaset.
- Kostnaden som egen text i raden klipptes till "12…".
- Hela knappen med kostnad gick utanför skärmens kanter på SE vid största text.
- På SE blev remsan 0 punkter hög, så kortets text syntes bakom raden.

## Kända fel, begränsningar, risker

- **Inget är provat på en riktig telefon.** Tryck på knapparna i raden, haptik och VoiceOver är inte prövade; bilderna
  visar bara att de står där och går att läsa.
- **Inte prövat i Simulator heller:** att raden byter mellan "bara Klar" och "Spela + Klar" medan man rullar kortet,
  och att ett drag i listan tar ner tangentbordet. Det följer av koden men är inte sett.
- Bredden där alla fyra stilförslag ryms bredvid ▶, och där hela "Spela i 10 min" ryms vid största text, är satt till
  de bredaste telefonerna (kortet minst 398 punkter). Det är mätt på 17 Pro (402) och SE (375); en iPhone med 393
  eller 440 punkters bredd är inte fotad (**untested assumption**).
- I stilfältets rad visas ingen kostnad och ingen "Fyll på" (inget rum bredvid förslagen).
- Tobys tester: raden "Nytt prov" finns inte medan tangentbordet är uppe, och kortets Spela är dold för VoiceOver
  (och därmed för XCTest) när radens Spela står där. Toby har fått beskedet.

## Kvar

- Kellys granskning av bilderna på main.
- Tobys T53 på 17 Pro och SE mot main.
- A154 (D239) är nästa punkt i min kö.

## Nästa session

Läs Kellys svar och Tobys T53. Om raden inte byter rätt när kortet rullas: börja i `lookAtPlay()` i SayViews
(den får knappens läge av `onGeometryChange` och tangentbordets av aviseringen).

## Tillägg 2026-11-20 11:35: grönt på main, godkänt av Kelly, prövat med tryck av Toby

- **iOS build 44598313619 på main är grön** (A153). **Verifierat i CI.**
- **Kelly har godkänt** slutversionen (kostnaden går att läsa, remsan är tät också på SE vid största text, ▶ står
  först i stilraden).
- **Toby har nått Spela med riktiga tryck i Simulatorn** vid största text med tangentbordet uppe, utan att testet
  döljer tangentbordet: iPhone 17 Pro (T53 44691016971) och iPhone SE (44700938846). Det som förut bara var sett på
  bild är därmed prövat med tryck. Fortfarande inte på en riktig telefon.
- Loggraden "Say: Spela cannot be pressed (an earlier press is still waiting)" kommer efter varje tryck (knappen
  väntar på svaret). Det är inte ett andra tryck; orden är missvisande och ändras nästa gång filen rörs.
