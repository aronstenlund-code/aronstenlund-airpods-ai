# Kelly Ke50: alla texter i repetitionsläget

Datum: 2026-11-13 20:19. Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke50.

## Vad som gjordes
- `docs/design/repetition-texter.md`: alla texter i repetitionsläget, ordnade per skärm (Hem, Nytt prov, Läser
  materialet, Stämmer det här?, Frågelistan, Redigera, kontrollskärmen, uppspelningen, låsskärmen, Fortsätt där du
  var?, Dela, BETA och Fler lägen samt fel och gränser). Kolumnen **Text** kopieras rakt in, och kolumnen **I koden nu**
  visar vad utkastet b669d02 (A79–A81, D147) säger när det skiljer sig.
- Tonen överst i filen: du-form, inga leverantörs- eller modellnamn, "Långt svar" i stället för "A+-svar", trycken
  alltid i ordningen 1, 2, 3 och böjning efter antal ("1 fråga").

## Viktigaste ändringarna mot koden
1. **Paus:** koden säger "Paus, och 3 igen för att fortsätta". Det motsäger D143/D147, där vilket tryck som helst
   fortsätter. Ny text: "Vilket tryck som helst fortsätter".
2. **Word-filer:** felet "Word-filer går inte att läsa än" ska bort, eftersom K45 `doc_text` läser .docx.
3. **"Starta prov går när ljudet är klart."** ersätts med "Gör ljud …" på knappen tills första frågans ljud finns
   (R1: spela i ordning).
4. **VoiceOver på Avsluta:** "Det enda som avslutar. Annars börjar listan om." ersätts med "Avslutar provet. Du kan
   fortsätta där du var nästa gång."
5. **Nya texter som saknas i koden:** inga AirPods anslutna, kameran nekad, inget nät (före och under), dagens gräns
   för ljud (K46), avbrott från en annan app, AirPods bortkopplade, sluta dela, mottagaren utan konto eller med
   avstängd delning, osparade ändringar och borttagning av ett prov.
6. **Ljudets förlopp** räknar filer: 3 per fråga med iPhonens röst (D147), 2 per fråga med serverns ljud (K46). Texten
   är densamma.

## Test
Texterna är inte inlagda i appen och inte provade på telefon (**untested assumption**). Vägen i Inställningar för
AirPods 1/2 är **ej verifierad** i iOS 26.

## Till Angela
Kopiera från `docs/design/repetition-texter.md`. Jag granskar texterna i samma veva som A78–A81, när skärmbilderna
finns i CI.

## Nästa
Granska A78–A81 mot `repetition.md` och `repetition-texter.md` när Angelas skärmbilder finns.
