# Angela: Toby 2:s T24-fynd – ett kontobyte raderade alla prov på telefonen (D183)

Datum: 2026-11-14 23:12. Roll: Angela (app). Inget är **verifierat på enhet**. Inga tester mot ElevenLabs (D180).

## Felet
- `RepetitionModel.refresh()` raderade varje uppladdat prov som inte fanns i serverns lista, med motiveringen "borttaget
  på en annan telefon".
- Byts kontot blir listan tom, och då försvann alla prov från telefonen. De finns kvar på servern under det gamla
  användar-id:t, men går inte att nå.
- Kontot kan bytas på två sätt:
  - refresh-token nekas, och appen skapar en ny anonym användare;
  - sessionen sparas inte i Keychain.
- Toby 2 såg det i simulatorn (T24, körning 43639763574): ett nytt konto vid varje omstart, och Biologiprovet och en
  ChatGPT-import försvann.

## Ändring (09885ad)
- **Provets ägare:** `Drill.ownerID` är kontot som äger provet på servern, alltså `sub` i token (`SupabaseAuth.userID`).
  Det sätts första gången det kontots lista visar provet. Prov som hämtas från listan får det direkt.
- **Radering:** `RepetitionModel.listDecisions` raderar ett prov bara när samma konto listar och provet saknas. Det är
  fallet där provet tagits bort på en annan telefon med samma konto.
- **Behålls och loggas:**
  - prov från ett annat konto, en ny anonym användare eller ett okänt konto;
  - prov från före ändringen, som inte har någon ägare.
- **Loggas:** när refresh-token nekas och en ny anonym användare skapas (`Log.answer`).
- **Beslut D183.** Öppen fråga till Architect: ska ett behållet prov laddas upp igen under det nya kontot? Det kostar
  nytt ljud. Eller ska kontot återställas på annat sätt? I dag spelas provet från ljudet som redan finns på telefonen,
  men synken mot servern fungerar inte för det.

## Test
- Nya tester i `A79A81RepetitionTests`:
  - `anAccountChangeNeverDeletesTheExams`: ett annat kontos tomma lista och ett okänt konto raderar ingenting;
  - `listDecisions`: samma konto raderar, ett annat konto behåller, och ett gammalt prov utan ägare stämplas när det syns
    i listan;
  - `theUserIDIsTheTokensSubject`.
- `anExamFromAnotherPhoneIsAdded` gäller fortfarande: borttaget på en annan telefon med samma konto försvinner här också.
- **CI:** iOS build 43645181127 (09885ad) är grön, och `A79A81RepetitionTests` gick igenom.
- **Untested assumption:** i Tobys osignerade simulatorbygge (CODE_SIGNING_ALLOWED=NO) sparar Keychain inte sessionen,
  och på en riktig telefon gör den det. Vägen där refresh-token nekas finns kvar på telefonen också.

## Risker
- Ett prov som tagits bort på en annan telefon före ändringen, och som saknar ägare, ligger kvar här tills eleven tar bort
  det själv.

## Kvar
- Tobys mindre T24-fynd ("Nytt prov" som namn på en import, "Här är frågorna:" som oläst rad, 20 frågor innan kvoten
  syns) tas när T24-rapporten och köpunkten finns. Importregeln delas med Kevins `import_text`, så den ändringen görs
  tillsammans med honom.
- A3 väntar på K6.
