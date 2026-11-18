# Tobys fynd efter K100: väntraderna syntes inte på kortet (Angela Fable, moln)

Klart 2026-11-18 19:55. **Verifierat i CI: iOS build 44366384147 grön på min gren (enhetsbygge, varningar som fel,
LumenTests), och sett på bild i Simulatorn med låtsasdata. Inte kört mot servern (Tobys `x-earmind-test: slow`) och
inte på enhet.** 0 ElevenLabs.

## Vad Toby såg (T36 44283940066)
Med ett ljud som aldrig blir klart gick kortet direkt efter Spela till "Gör ljudet …". Tiden räknade ner
("9:17 kvar") utan ljud, och varken raden efter 8 sekunder eller Försök igen efter 25 sekunder kom. Sedan K100 svarar
servern på en dryg sekund, så kortet byter läge innan något ljud finns, och väntraderna i A144 satt bara på skrivkortet.

## Vad som är ändrat
1. **Samma klocka går vidare på kortet tills första ljudet hörs.** Efter 8 sekunder står "Det tar längre tid än
   vanligt." under "Gör ljudet …". Efter 25 sekunder (eller direkt utan nät) ger Spela upp: kortet går tillbaka till
   fältet med "Ljudet kunde inte hämtas." och Försök igen. Ljudet görs klart i bakgrunden, så Försök igen spelar
   direkt om det hunnit bli klart. Inget startar av sig självt.
2. **Tiden för upprepningen börjar när ljudet börjar.** Medan ljudet görs står hela tiden kvar ("10:00 kvar").
3. Spelar texten redan, eller är spelaren med texten uppe, rör klockan ingenting. Pausar man medan ljudet görs
   räknas inte den tiden.

## Ett eget val inom D225 (säg till om det ska vara annorlunda)
D225 säger 25 sekunder. På kortet har servern redan tagit emot texten och gör ljudet, och ett långt första stycke
tar längre tid att göra utan att något är fel (särskilt med stil). Därför får ett långt första stycke **en sekund
extra per 100 tecken, högst två minuter i allt**. En kort text ger upp efter 25 sekunder, som D225 säger. Utan det
här skulle en lång text med stil ofta få felraden fast ljudet är på väg.

## Teknik
- `ReadingPlayer.hasSounded` och `onFirstSound`; `RepetitionSession` sätter upprepningens start vid första ljudet.
- `SayText.giveUpAfter(waitingForChars:)` och `SayText.wait(after:online:giveUpAfter:)` (rena funktioner);
  väntklockan i `SayInAirPodsField.play()` följer med till kortet; raden på kortet är `waitNote`.

## Tester
- `A136StyleVoicePaceTests`: tiden börjar vid första ljudet (hela tiden kvar medan ljudet görs, 540 s kvar en minut
  efter första ljudet); uppläsaren vet att inget har hörts än.
- `A122LockedPhoneTests`: 25 s för en kort text, 40 s för 1 500 tecken, aldrig över 120 s.
- **Själva väntklockan i vyn är inte enhetstestad** (den ligger i vyn); Toby kör om T36 med `slow`.

## Bild
`reports/2026-11-18-a150-bilder/stillbilder.jpg`, första rutan: kortet med "Gör ljudet …", raden och "10:00 kvar".

## Tobys nya fynd 18:00: en ny text utan nät säger ingenting
**Inte förklarat.** Ur koden skulle det som låg på main då ha gett "Ljudet kunde inte hämtas. Kolla nätet." efter
en sekund, eller "Ingen internetanslutning …" när anropet föll. I den här pushen:
- Spela har en reserv: spelar den inte och har den ingen rad, sätts raden ändå (med Försök igen).
- Spela loggar varje steg ("Say: Spela pressed …", "Say: answered …", "Say: gave up …"), så nästa körning visar var
  det stannar. Toby har fått raderna att leta efter.
