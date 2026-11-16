# A109: vyer för streak och påminnelse (D194, Kelly Ke65) (Angela Fable, moln)

2026-11-15 18:10. Logiken är Angela Schrutes A108 (D195, iOS build 43733896070), texterna Kellys Ke65
(`docs/design/repetition-texter.md` §14). **Inget är provat på telefon. Inga ElevenLabs-tester (D180).**

## Vad som byggdes
| Var | Vad | Fil |
|---|---|---|
| Efter första klara provet | Ett blad i systemets stil: "Vill du ha en påminnelse?", "EarMind kan påminna dig klockan 18 de dagar du inte har pluggat. Högst en gång om dagen.", **Påminn mig** (sedan iOS egen fråga), **Inte nu** (frågar aldrig igen) och fotnoten om Inställningar. Visas när spelaren har stängts (`model.asksForReminders`) | `ReminderViews.swift` (ny), `RepetitionHomeSection.swift` |
| Inställningar | Avsnittet **Påminnelse**: reglaget "Påminn mig att plugga", raden Tid (tidväljare) när den är på, fotnoten "Högst en gång om dagen, och bara de dagar du inte har pluggat." Är iOS notiser avstängda: "Notiser är avstängda för EarMind." och knappen Öppna Inställningar | `ReminderViews.swift`, en rad i `Settings/SettingsView.swift` |
| Start | "3 dagar i rad" räknar repetitionsflödets dagar (`model.practice.streak.current`), eller lyssningslägenas om den raden är längre | `RepetitionHomeSection.swift` |

- Bladet går inte att svepa bort: man väljer Påminn mig eller Inte nu, så att frågan inte försvinner av misstag.
- Att slå på reglaget i Inställningar låter iOS fråga om notiser om den inte har frågat (det är användarens eget tryck).
- En ändrad tid lägger om påminnelserna (`model.reschedulePracticeReminders()`).

## Till Deangelo och Angela Schrute
- **Två avsnitt om påminnelser i Inställningar.** Mitt avsnitt "Påminnelse" (kl. 18, repetitionsflödet) står ovanför
  det gamla "Påminnelser" ("Påminn mig varje dag", kl. 16, studieplanens 5 snabba frågor i lyssningsläget). Det syns på
  bilden `settings`. Det gamla är Angela Schrutes och jag har inte rört det. En användare som bara har
  repetitionsflödet ser två reglage som verkar göra samma sak. Förslag: visa det gamla bara när Fler lägen är påslaget.
- **Påminnelsens egna texter** (titel och rad i notisen) ligger i Angela Schrutes `PracticeReminderText` och ska bytas
  mot Kellys fyra fall i §14. Det är inte mina filer.

## Testresultat
- **iOS build 43735876827 grön** (min gren, med A109 före sista ändringen): device-bygget, varningar som fel,
  LumenTests. **iOS build 43737906164 grön** efter sista ändringen (bladets höjd). *Verifierat i CI.*
- **Sedd på bild av mig** (simulatorn, inte enhet): iPhone 17 Pro ljust och mörkt (Fable screens 43735883325), iPhone
  SE med största text (43735887673). `reports/2026-11-15-a109-bilder/`, grenarna `fable/screens-a109-17pro-1` och
  `fable/screens-a109-se-xxxl-1`.
- På iPhone SE med största text visade bladet bara rubriken i halv höjd. Bladet tar nu hela skärmen med de största
  textstorlekarna och går att skrolla. Sedd på bild av mig (43737911416, `a109-se-storsta-text-fragan.jpg`).
- **Inte testat:** att bladet verkligen kommer efter första klara provet (kräver ett helt varv), iOS egen fråga,
  att en notis kommer kl. 18 och öppnar provet. Det är Tobys T30. *Untested.*

## Kvar
- Kelly: granska bilderna. Toby: T30.

## Tillägg 2026-11-15 19:00: Kellys granskning (`reports/2026-11-15-1813-kelly-granskning-a109.md`)
**Inte provat på telefon. Inga ElevenLabs-tester.** Kelly godkände A109; texterna stämmer ordagrant.
| Fynd | Rättat | Sedd på bild |
|---|---|---|
| P1 (medel) bara ett påminnelseavsnitt i Inställningar | **Inte rättat.** Deangelo avgör; det gamla avsnittet är Angela Schrutes | – |
| P2 (medel) frågebladet klipps i största text | Innehållet skrollar, knapparna ligger fast nederst, och bladet tar hela skärmen med de största storlekarna | ja |
| P3 (låg) "?" ensamt på en rad | Mindre rubrikstil med de största storlekarna | ja |
| P4 (låg) bladet för högt på 17 Pro | Bladet är så högt som innehållet (390 punkter), och går att dra upp | ja (17 Pro och SE) |

- Bild: `reports/2026-11-15-a109-bilder/a109-fragan-p3-p4.jpg` (Fable screens 43739964928, 43739967798, 43739970576;
  grenarna `fable/screens-a109-17pro-2`, `fable/screens-a109-se-1`, `fable/screens-a109-se-xxxl-3`).
- **iOS build 43739959462 grön** (min gren, edf5d3a, med P3 och P4). *Verifierat i CI.*
- A109 kom till main först 18:25 (37adcf4): den första pushen krockade i tavlan och kön, och Toby och Kelly fick
  beskedet för tidigt. Toby upptäckte det.

## Tillägg 2026-11-15 19:20: grönt på main, Tobys T30 grön
- **iOS build 43741552382 grön på main** (9792eba, A109 med Kellys P2–P4). *Verifierat i CI.*
- **Tobys T30 är grön 5/5 utan fynd** (körning 43740073641, `reports/apptest/2026-11-15-1845-toby-moln-t30.md`):
  streaken och frågan om påminnelse i simulatorn. Kelly har godkänt bilderna. *Simulatorn, inte enhet.*
- Kvar: P1 (ett påminnelseavsnitt i Inställningar) hos Deangelo.

