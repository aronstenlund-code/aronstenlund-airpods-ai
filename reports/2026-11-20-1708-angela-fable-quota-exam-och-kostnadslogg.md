# Priset ur /drill quota i Nytt prov, och loggen för kostnadsanropet (Angela Fable (moln), 2026-11-20 17:08)

Två rader från Kevin efter A154 (Deangelo 16:47): (1) `exam`-fältet i `/drill quota` är live, använd det i Nytt
prov; (2) Tobys T55 visade cirka 2 500 i appens `cost`-anrop för tre frågor, medan serverns väg kostade
1 091–1 474: ta reda på vad appen skickar mer innan något rättas, och logga raderna.

## 1. Nytt prov vet vad som ryms när det öppnas

- Appen skickar svarslängden (`long_words`) i `/drill quota` och läser `exam: {per_question, min_questions,
  long_words}` ur svaret. Koden för det kom med A154; nu finns fältet på servern (Kevins K113: 642 vid 90 ord, 894
  vid 130).
- Följden: ett nytt konto med 1 500 krediter får rutan "Ett prov med 3 frågor kostar cirka 2,0k krediter. Du har
  1,5k." med "Fyll på" **direkt när Nytt prov öppnas**, innan något material valts. Förut kom den först efter Skapa
  frågor.
- Ryms mellan 3 och 11 frågor står antalet på det som ryms från början, med raden "Krediterna räcker till N frågor."
  under stegaren.
- Appen räknar aldrig priset själv. Ett pris för en annan svarslängd än den som är inställd används inte, och en
  server utan fältet lämnar kvar det appen fick veta av serverns senaste nej.
- Ändringen i koden är liten: läsningen av kvoten är utbruten till `RepetitionModel.take(_:askedLongWords:)`, så att
  den går att testa.

## 2. T55-kostnaden: trolig förklaring, och loggen som visar det

**Trolig förklaring (inte belagd än): provet hade fler än tre frågor.** Tobys test räknar texter på skärmen som
slutar med frågetecken. Formuläret "Stämmer det här?" visar högst fem frågor, och färre får plats på skärmen, så
"3 questions" är vad som syntes, inte hur många frågor provet hade. Appen bad om 12 (det står "Antal frågor, 12" i
körningens logg). 2 450 delat på fem frågor är 490 per fråga, vilket är just det pris Kevin mätte på servern (högst
491). Kevins egen gissning var också "fler rader".

**Det jag har läst i koden (verifierat i koden, inte i en körning):**
- Appen skickar `long_words` 90 i `exam drill`, `drill_answers`, `save` och `cost`.
- `cost` skickar samma rader som `save`: fråga, kort svar och långt svar per fråga. Servern räknar frågans och det
  långa svarets tecken för varje rad.
- Servern sätter ihop det långa svaret så att det börjar med det korta, ordagrant, och kapar det vid 90 ord. Appen
  lägger bara det korta svaret först om det långa inte redan börjar med det. Jag hittar ingen väg där appen gör
  svaren längre.

**Inget är rättat i kostnaden**, eftersom inget fel är belagt.

**Loggen (bara längder, aldrig texterna):**
- Vid `cost`: `Exam cost: asks about N rows, long_words 90: questions … chars, long answers … chars (… words), … in
  all`, sedan en rad per fråga (högst 12) med frågans, det korta och det långa svarets längd och om det långa börjar
  med det korta, och till sist `Exam cost: the server says …`.
- När svaren kommer från servern: `Exam answers: row N: the server's short … chars, long … chars (… words), starts
  with short yes/no; kept … chars`.
- En körning utan `user-path` når kostnadsanropet. Med `user-path` stoppas ett nytt konto före genereringen.

## Annat i samma ändring

Loggraden efter ett tryck på Spela sa "an earlier press is still waiting", vilket Toby läste som ett andra tryck. Den
säger nu "a press is waiting for its answer".

## Testresultat

- **Testerna skrevs först.** Fyra nya i `LumenTests/A154ExamRoomTests.swift` (nu 19): Nytt prov vet vad som ryms när
  det öppnas, priset följer svarslängden, en kvot utan pris lämnar det som var känt, och kostnadsanropets loggrader
  (bara längder).
- **Verifierat i CI:** iOS build 44766838827 på min gren är grön (bygget för enhet utan varningar, alla
  enhetstester, Release-bygget), med main ihopslaget. Main-bygget: se tillägget nedan.
- **Inte sett:** rutan vid öppnandet mot riktiga servern, och loggraderna i en körning. Tobys nästa T55 visar båda.
- 0 ElevenLabs.

## Kända fel, begränsningar, risker

- Förklaringen till T55-kostnaden är en slutsats ur talen och ur hur testet räknar. Visar loggen tre rader och ändå
  2 500 är den fel, och då visar samma logg var längden kommer ifrån.
- Ett nytt konto med 1 500 krediter kan fortfarande inte göra något prov förrän välkomsten är på (Team ID,
  TILL-ARON #31). Det sägs nu redan när Nytt prov öppnas.

## Kvar

- Tobys T55: rutan vid öppnandet, och en körning utan `user-path` med loggraderna.
- Kevins svar när radantalet är känt.

## Nästa session

Läs Tobys körning. Tre rader och 2 500: läs `Exam answers:` (serverns längder) mot `Exam cost:` (appens) för att se
var svaren blev längre. Fler rader: skriv det till Kevin och stäng frågan.

## Tillägg 17:58: grönt på main

**iOS build 44772435935 på main är grön** (bygget för enhet, alla enhetstester, Release-bygget). **Verifierat i CI.**
Rutan vid öppnandet och loggraderna är fortfarande inte sedda i en körning; Toby har inte kört T55 sedan ändringen.
