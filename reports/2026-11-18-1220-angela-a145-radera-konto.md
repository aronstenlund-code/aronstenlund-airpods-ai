# A145: Radera konto i Inställningar (Ke78, Apple 5.1.1(v), Kevins K101)

Angela Schrute (moln, Opus 5.5 från 11:15, Fable 5.2 före), 2026-11-18 11:00–12:20. Main, sammanslagning be0b66f3
(grenen `claude/fervent-fermi-34hrer`, fa9dea99).

## 1. Vad som gjordes
- **Inställningar › Konto › Radera konto.** Knappen är röd och visar en fråga som går att avbryta:
  - rubrik "Radera kontot?";
  - text "Allt du har gjort raderas, både på telefonen och hos oss: prov, texter, ljud, krediter, historik och
    inställningar. Det går inte att ångra.";
  - knapparna "Radera konto" (röd) och "Avbryt".
- **Veckokortet:** under knappen står "Har du veckokortet? Det avslutas inte när kontot raderas. Säg upp det i
  Inställningar › ditt namn › Prenumerationer.", och knappen "Hantera prenumerationer" öppnar Apples eget blad.
- **Ordningen efter "Radera konto":**
  1. Servern: `POST /functions/v1/account/delete` med `{"confirm": true}` (K101). Under tiden står "Raderar kontot …",
     och knappen är avstängd.
  2. Säger servern nej, eller saknas nät, rörs **ingenting** på telefonen. Raden under knappen säger vad som hände.
  3. Säger servern ja: lyssnandet och uppspelningen stoppas, och telefonen glömmer allt (§2).
  4. Appen börjar om som ny utan att stängas: ny behållare (`AppHolder`), första starten, och ett nytt anonymt konto
     (A143 loggar in direkt vid start).
  5. En ruta "Kontot är raderat. EarMind börjar om som ny på den här telefonen." Har användaren veckokortet läggs
     K101:s besked till ("Veckokortet avslutas inte …"), med knappen "Hantera prenumerationer".
- **Fel som sägs för sig:**
  - inget nät: "… telefonen har inget nät. Inget är raderat. Försök igen när du är uppkopplad.";
  - fler än 3 försök i minuten (429): "För många försök. Vänta en minut och försök igen.";
  - allt annat: "Det gick inte att radera kontot just nu. Försök igen om en stund." Här står inte "inget är raderat",
    eftersom en tidsgräns kan komma efter att servern har raderat. Ett nytt försök är säkert: K101 svarar 200 för ett
    konto som redan är borta.
- **Ett 401** förnyar token med refresh-token och frågar en gång till (A143), så att en gammal token inte stoppar
  raderingen.

## 2. Vad telefonen glömmer (`LocalWipe`)
- Allt i appens egna mappar: Application Support (prov, anteckningar, röstprofilen, väntande ljudbitar), Documents
  (inspelningar i Diagnostik), Caches (provens ljud) och tmp (Sömnlägets och Mina svars klipp).
- Alla inställningar (`UserDefaults` för appen), också samtycket och första starten.
- Inloggningen i nyckelringen.
- Widgetens ögonblicksbild (appgruppen) och väntande och visade påminnelser.
- Den gamla behållarens inloggning stängs (`SupabaseAuth.retire`): den kan aldrig logga in igen, så inget kvar av den
  gamla appen skapar ett nytt anonymt konto eller når servern.

Inte rörda: händelser, påminnelser och larm som användaren har låtit EarMind lägga in i iPhonens egna appar. De är
användarens, inte EarMinds.

## 3. Testresultat
- **CI: iOS build 44284557970 grön** på grenen (6c849a6e, med A146): device-bygget, alla LumenTests och Release-steget
  ("Release check: no test mode in the Release build"). *Verifierat i CI.*
- **Nya tester** (`A145AccountDeletionTests`, alla gröna): servern får `confirm: true` och token; ett 401 förnyar och
  frågar igen; 429, inget nät och serverfel sägs för sig; inget på telefonen rörs när servern säger nej; efter ja kommer
  stopp, sedan radering, sedan omstart med beskedet; filer, inställningar och inloggning glöms; den gamla inloggningen
  loggar aldrig in igen.
- **Main efter ihopslagningen:** iOS build 44293876104 — resultatet står på tavlan.
- **Inte provat i Simulator eller på telefon.** Omstarten med ny behållare är inte provad någonstans.
- 0 ElevenLabs.

## 4. Kända risker och begränsningar
- **Den gamla appens delar kan skriva en fil efter raderingen.** Mellan raderingen och bytet av behållare finns de
  gamla objekten kvar ett ögonblick. En uppgift som redan körde (till exempel en provsparning) kan då skriva en fil
  som blir kvar. Den når aldrig servern (inloggningen är stängd), men filen ligger kvar på telefonen tills nästa
  radering eller avinstallation. Inte provat om det händer.
- **Två behållare samtidigt ett ögonblick.** Den nya skapas innan den gamla släpps. Ljudmotorn startar först när något
  lyssnar eller spelar, så det ska inte ge två ljudmotorer, men det är inte provat på telefon.
- **Ett köp som pågår** när kontot raderas avslutas inte av appen. Apple äger köpet.

## 5. Vad Aron ska prova på telefon
Gör det med ett konto du kan förlora, till exempel efter en ny installation.
1. Inställningar › Konto: "Radera konto" och "Hantera prenumerationer" finns, och texten om veckokortet står under.
2. Tryck "Radera konto" och sedan "Avbryt". Ingenting händer.
3. Slå på flygplansläge, tryck "Radera konto" › "Radera konto". Raden säger att inget nät finns och att inget är
   raderat. Proven finns kvar.
4. Slå av flygplansläge och radera. Appen börjar om med Välkommen, och rutan "Kontot är raderat" visas.
5. Efteråt: inga prov, inga Säg-texter under Senaste, krediterna är som för ett nytt konto (1 500 i månaden och
   välkomstkrediterna enligt D224, om servern ger dem till samma telefon).

## 6. Till Toby
A145 kan provas i Simulator, men raderingen sker på riktigt på servern: använd ett testkonto som får försvinna.

## 7. Kvar
- Inget i A145. Kelly får en rad om att Radera konto finns (Ke78, App Privacy).
