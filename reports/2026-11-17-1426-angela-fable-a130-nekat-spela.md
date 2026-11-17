# A130 (D212), A129 (D211) och ett borttaget prov som kom tillbaka (Angela Fable, moln)

Klart 2026-11-17 14:26. **Verifierat i CI och på simulatorbild, inget på enhet.** 0 ElevenLabs (D180).

## Vad Aron såg 13:48
Säg i AirPods, 764 tecken, kapseln "1 fråga kvar", raden "Räknas som 1 fråga". Spela gjorde ingenting. Servern
svarade 402 (månadens frågor slut) på varje tryck, appen visade inget under fältet, och varje tryck skapade ett nytt
ostartat prov. Skärmbild: `reports/apptest/aron-2026-11-17-1348-spela-inget-hander.png`.

## Vad som är rättat
### A130: ett nekat Spela är aldrig tyst
- **Raden under fältet:** när Spela inte öppnar spelaren står serverns egen text där (halvfet, i stället för
  kostnadsraden), följd av påfyllningen ur serverns datum: "Du har gjort 15 av 15 frågor med ljud den här månaden.
  Fylls på den 1 december." Har servern ingen text står "Det gick inte att spela just nu. Försök igen om en stund."
  Raden läses upp av VoiceOver och försvinner när texten ändras.
- **Inget nytt prov per tryck:** fältet höll själv reda på vilket prov texten hörde till, och det minnet försvann
  när Start ritades om. Nu håller modellen reda på det (`RepetitionModel.lastSaid`): samma text startas om på samma
  prov, och sparas inte igen.
- **Serverns tal:** "Räknas som N frågor" räknas med serverns tecken per fråga ur kvotsvaret, inte appens fasta 800.
  Kapseln visade redan serverns tal.
- **Byts i A131 (D213):** texterna här är i frågor. Arons beslut 13:59 gör dem till krediter per tecken; det byggs
  ovanpå detta när Kevin har skrivit fälten (K90).

### A129: provets eget id i första sparningen
`drill.client_id` = provets lokala UUID (gemener), bara när servern inte har gett provet ett id. Kevins K88 svarar
då med det prov som redan finns om samma id kommer igen.

### Ett borttaget prov kom tillbaka (Tobys T36, Kevins logg)
Togs ett prov bort medan ljudet fortfarande följdes fick lägesfrågan som var på väg svaret "finns inte", och appen
lade då tillbaka provet och sparade det som nytt och ostartat. Nu sparas inte ett prov som är borttaget på telefonen.

## Tester
- **iOS build 44087342486 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- Nya tester i `LumenTests/A122LockedPhoneTests.swift`: raden vid nekat Spela (serverns ord, påfyllningen en gång,
  aldrig tyst); texten räknas med serverns tal; tre tryck på Spela mot ett fejkat 402 ger ett prov på telefonen, en
  sparning och serverns rad; första sparningen bär provets eget id, senare serverns; ett prov som tas bort medan
  ljudet följs kommer inte tillbaka.
- **Bilder** i `reports/2026-11-17-a130-bilder/` (grenarna `fable/screens-a130-17pro-1`, `fable/screens-a130-se-xxxl-1`):
  raden syns på 17 Pro i ljust och mörkt. På SE med största text ligger den under skärmens kant; man rullar dit.

## Inte mitt, eller inte gjort
- **Varför servern sa 402 med 1 fråga kvar** är Kevins utredning (K89). Jag har skrivit till honom hur appen räknar.
- **De ostartade proven från Arons tryck** (196454b4, bddfc4eb) ligger kvar på hans konto och syns som kort på Start.
  Jag raderar ingenting; Aron kan ta bort dem i appen.
- Ett nekat prov ligger kvar på telefonen som ostartat kort (D212 punkt 3 säger att det inte ska sparas: serverns
  del är Kevins; appens del görs med A131, när servern säger kostnaden före sparningen).

## Otestat (antaganden)
- Inget riktigt 402-svar har gått genom appen efter rättningen; testet använder ett fejkat.
- Inget på enhet.

## Prova på telefonen (Aron, med nästa app)
1. Skriv en text i Säg i AirPods och tryck Spela. Antingen hörs den, eller så står det en rad under fältet som säger
   varför och när det fylls på. Det ska aldrig hända ingenting.
2. Tryck Spela tre gånger till på samma text. Det ska inte komma fler kort på Start.

## Nästa session
- A131 (krediter per tecken) när Kevins fält finns. Kelly granskar orden.
