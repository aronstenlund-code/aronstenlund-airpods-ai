# A143: inloggningen håller inte tillbaka Spela, och kontot byts inte av ett 401 eller ett serverfel (D225 punkt 4)

Angela Schrute (moln, Fable 5.2), 2026-11-18 09:45–10:55. Main, sammanslagning 9541df0a (grenen
`claude/fervent-fermi-34hrer`, ed8f515d och 997c56d4).

## 1. Utredningen: inloggningen var inte orsaken i Tobys körning
Uppgiften utgick från att appen väntade över en minut på att kontot skapades efter trycket på Spela. Jobbloggen för
Tobys körning 44245785236 visar något annat. *Verifierat i loggen och mot Kevins servertider.*

| Tid (UTC) | Händelse | Källa |
|---|---|---|
| 05:48:34,6 | testet börjar | sviten slutade 05:58:58,776 efter 624,155 s |
| 05:48:43,6 | appen startar | appens första loggrad, samma process (15634) hela körningen |
| 05:48:48,6 | kontot skapas, 0,32 s | Kevins logg för `POST /auth/v1/signup` |
| cirka 05:49:14 | Spela trycks | skärmbilden "text i fältet" togs 39,2 s in i testet |
| 05:49:16 och 05:49:22 | save (5,8 s) och start (4,6 s) | Kevins logg |
| 05:49:26,6 | "Drill audio started: 1/1" | appens logg |

- Kontot fanns **26 sekunder före** trycket. Tiden "cirka 05:47" för trycket stämde inte.
- Det som föll i den körningen var kedjan save + start, cirka 10,4 s mot appens gräns på 10 s. Det är Angela Fables
  och Kevins fynd, och frågan om gränsen ligger hos Deangelo (D219.3).
- **Arons fynd 20:24** (servern såg inget anrop på över en minut) kan jag inte belägga åt något håll. Det finns
  ingen applogg från telefonen. Efter A143 står tiderna i appens logg nästa gång.

## 2. Vad koden gjorde (verifierat i koden)
1. **Inloggningen startade inte när appen öppnades.** Den startade när något först behövde en token (5 s efter
   start i Tobys körning). Inget köade den bakom något annat, och alla som behövde en token delade samma anrop.
2. **Ett anrop till inloggningsservern kunde stå i 60 sekunder.** `signUp` och `refresh` hade ingen egen tidsgräns
   (systemets är 60 s utan aktivitet) och gjordes aldrig om. Alla som väntade på token stod stilla under tiden.
3. **Ett 401 från en av våra funktioner bytte konto.** `invalidate()` kastade hela sessionen, också refresh-token,
   och nästa anrop skapade ett nytt anonymt konto. Det gällde svar, röst, röstlistan, feedback och Scribe.
4. **Ett serverfel vid förnyelsen bytte också konto.** Varje svar som inte var 2xx från `/auth/v1/token` räknades som
   "nekad", också 429 och 5xx, och då skapades ett nytt anonymt konto.

Punkt 3 och 4 betyder att användaren kunde tappa sina prov, sina krediter och sina köp (A134) utan att ha gjort
något. Det nya kontot ser inte det gamla kontots data. Jag har inga belägg för att det har hänt en riktig användare;
det syns i appens logg som "the refresh token was refused, signing up a new anonymous user" eller inte alls (punkt 3).

## 3. Vad som är ändrat (`SupabaseAuth`, `AppContainer`)
- **Inloggningen startar när appen öppnas** (`prepare`). En ny installation loggar in direkt. En token som har gått
  ut, eller har mindre än 5 minuter kvar, förnyas i bakgrunden när appen öppnas eller kommer tillbaka. Medan en
  giltig token förnyas väntar ingen: den gamla används tills den nya finns.
- **Ett anrop utan svar ges upp efter 8 sekunder och görs om en gång.** Bara vid tidsgräns, inte när telefonen saknar
  nät. Värsta fallet är 16 s i stället för 60 s eller mer.
- **Ett 401 förnyar token med refresh-token.** Kontot ligger kvar.
- **429 och 5xx vid förnyelsen behåller kontot** och ger ett vanligt fel. Bara 400, 401, 403 och 404 från
  `/auth/v1/token` (refresh-token finns inte, är redan använd, sessionen eller användaren är borta) leder till ett nytt
  konto, som förut.
- **Loggrader med tider** (kategorin `answer`, alla börjar med "Auth:"):
  - `Auth: signing in when the app opens (no account on this phone yet)`
  - `Auth: sign-up took 0.32 s` och `Auth: refresh took 0.21 s`
  - `Auth: a call waited 0.34 s for the token` (bara när ett anrop faktiskt fick vänta)
  - `Auth: sign-up got no answer in 8.00 s, trying once more`
  - `Auth: refresh answered HTTP 503 (…) after 0.40 s`
  - `Auth: the server did not accept the access token (401); it is renewed before the next call`
- Inloggning vid appstart görs inte i låtsasläget (inget nät där) och inte i enhetstesternas värdapp.

## 4. Varför 8 sekunder och ett omförsök (D227)
- En förnyelse där servern tog emot anropet men svaret tappades är det farliga fallet: refresh-token är då använd.
  Supabase godtar samma refresh-token en gång till inom 10 sekunder (standardvärdet). Med 8 s gräns och ett omförsök
  direkt hamnar det andra försöket innanför den tiden och får samma nya session. **Obekräftat antagande:** att vårt
  projekt har standardvärdet 10 s. Kevin behöver bekräfta det (Supabase › Authentication › Sessions, "Refresh token
  reuse interval").
- Ett nytt konto (signup) har inget att förlora; där kostar ett omförsök i värsta fall ett tomt anonymt konto på
  servern.

## 5. Testresultat
- **CI:** iOS build 44273843720 (manuell körning på grenen, med main och A142) är grön: Debug-bygget, alla
  LumenTests, Release och Beta. *Verifierat i CI.* De nya testerna står i loggen som godkända. Det parametriserade
  testet (429, 500, 502, 503) skrivs inte ut med namn i loggen, men sviten `SupabaseAuthRenewalTests` är grön.
  Main efter ihopslagningen: iOS build 44280856886 grön. *Verifierat i CI.*
- **Nya tester** (`SupabaseAuthRenewalTests`): inloggning vid appstart; ett anrop under tiden delar den; en token med
  lite kvar förnyas utan att någon väntar; en färsk token lämnas; signup och refresh utan svar görs om en gång; två
  tidsgränser i rad ger upp och behåller kontot; 429, 500, 502 och 503 vid förnyelsen behåller kontot; ett 401 förnyar
  med refresh-token.
- **Ändrade tester:** `CloudAnswerProviderTests.retriesOnceAfter401WithAFreshSession` väntar sig nu `/auth/v1/token`
  efter ett 401 (förut `/auth/v1/signup`), och `VoiceTests.unauthorizedRenewsTheTokenAndKeepsTheAccount` ersätter
  `unauthorizedInvalidatesTheSession`. De två gamla testerna beskrev felet som rätt beteende.
- **Inte mätt mot servern eller på telefon.** Tiderna i §1 är ur en körning före ändringen. Loggraderna visar tiderna
  i nästa körning av Tobys T36; jag har bett honom ta med "Auth:"-raderna i sammanfattningen.
- 0 ElevenLabs.

## 6. Kända begränsningar och risker
- **Statuskoden avgör vad som är "nekad".** Ett 400 av annan orsak än en ogiltig refresh-token skulle fortfarande ge
  ett nytt konto. Supabase använder 400 för just ogiltiga refresh-token, så jag har behållit det.
- **Ett konto som servern har nekat går inte att få tillbaka.** Anonyma konton har ingen annan nyckel än
  refresh-token. Det löser bara en riktig inloggning (e-post eller Apple), som inte finns i appen.
- **Provens anrop gör inget omförsök vid 401.** `/drill` och `/exam` förnyar inte token och försöker igen som svar,
  röst och Scribe gör. Med förnyelse i förväg ska det sällan behövas; inte ändrat.

## 7. Farhågor
- Inloggningen görs nu direkt vid första starten, innan användaren har tryckt på något. Kontot är anonymt och tomt,
  och förut skapades det ändå några sekunder in i första starten (5 s i Tobys körning), så jag ser ingen skillnad i
  sak. Mikrofonens samtycke (D21) påverkas inte.

## 8. Vad Aron kan prova på telefon
1. Öppna appen efter att den legat stängd över natten och tryck Spela direkt på en text som har spelats förut. Det
   ska börja spela utan lång väntan.
2. Fungerar något annorlunda än förut med prov, krediter eller köp efter uppdateringen: säg till, så läser vi loggen.

## 9. Nästa steg
- Kevin bekräftar återanvändningstiden för refresh-token (§4).
- Toby tar med "Auth:"-raderna i T36-sammanfattningen, så att nästa körning visar tiderna.
