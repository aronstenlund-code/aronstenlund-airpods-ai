# T48 – Köp i simulatorn (A134, A141, D218, D224)

Toby (moln), 2026-11-18 08:00. Simulatorn (iPhone 17, iOS 26, Xcode 26.6), riktig server med x-earmind-test, falskt ljud, 0 ElevenLabs, **inga köp gjorda**. **Allt nedan är verifierat i Simulator, inte på enhet.**

## Vad som gjordes
- Ny del i T36-testet: "Krediter: köpbladet (A134, A141)".
  - Kapseln på Start öppnar bladet Krediter, och testet läser vad som står där.
  - Testet trycker på Återställ köp.
  - Finns produkter gör testet ett StoreKit-testköp: ett avbrutet och ett genomfört. Annars skriver det varför köpet inte görs.
- Testschemat i `AppTests/E2E/project-e2e.yml` har `storeKitConfiguration: StoreKit/Lumen.storekit` i run.

## Resultat (körningar 44253148974 och 44257957713 på toby/t48)
- **Bladet Krediter:** "1 500 krediter kvar" (kapseln "1,5k krediter kvar", A139).
  - Avsnitten Bjud in ("Få 2 000 krediter · när en kompis har spelat sin första text") och "Så räknas det" finns, liksom Villkor, Integritet och Återställ köp. Det här är OK.
- **Fyll på (100, 500, 2 000, Bäst värde) och Varje vecka (Veckokort) syns inte.** Appen fick inga produkter.
  - StoreKit-filen i schemats run-del når inte ett UI-test, eftersom xcodebuild tar den för tester bara från en testplan.
  - På riktigt betyder det att utan svar från App Store (inget nät, ingen inloggning) står inga paket och ingen rad om varför. Möjligt fynd till Angela Fable.
- **Återställ köp:** ingen rad på 20 s (Simulator utan Apple-konto). Varken "Det fanns inga köp att hämta." eller "Det gick inte att hämta köpen …". Möjligt fynd till Angela Fable.
- **Testköp, avbrutet köp, raden "Köpet är gjort men kunde inte läggas in …" och "· Fyll på" vid Spela:** inte testat (untested assumption). Utan produkter finns ingen köpknapp, och testkontot har för många krediter för "Fyll på".
  - Det täcks av Fables enhetstester med fejkad butik (A134ShopTests) och av Arons prov på telefonen.

## Övrigt i samma körningar
- **"Det tar längre tid än vanligt."** (Fables nya ord, T50) kom vid första Spela på ett nytt konto i båda körningarna. Testet trycker på Försök igen en gång.
- **Tryck på texten på kortet:** i 44257957713 öppnade trycket inte spelaren (inget "Varv"), trots att kortet spelade och inget blad låg över. I sex andra körningar öppnade det. Möjligt fynd (sällsynt) till Fable.

## Nästa session
- En testplan för E2E-schemat med StoreKit-filen, om ett riktigt testköp i Simulator behövs (Deangelo avgör).
