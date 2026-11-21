# Till Aron (Deangelo håller listan)

Kortast möjligt. Svara "ja"/"nej"/eget val i chatten med Deangelo.

| # | Fråga | Rekommendation |
|---|---|---|
| 4 | Namn: Lumen, Proviska eller Testvisk | Bestäm före Fas 3 |
| 5 | Installera om appen senast fre 13 nov (går ut lör 14 nov) | Måste göras |
| 7 | **Lägg inte in `SUPABASE_SERVICE_ROLE_KEY` i GitHub** (för K22) förrän Oscar har godkänt K24: flödet skrev elevtext till det publika repot | Vänta |
| 8 | ElevenLabs-krediterna är slut sedan 08:10: rösten och taligenkänningen i appen fungerar inte. Fyll på (elevenlabs.io › Subscription) eller vänta på nollställning | Fyll på om du vill testa i dag |
| 9 | U5: riktig logga och appikon (Kelly har tre förslag i Ke12) | Ja |
| 10 | C5 Sömnläge: bygga nu (efter fas 1) eller lägga i backloggen? | Backlog, bygg efter fas 1. Bra för positioneringen "AI för hela vardagen" |
| 12 | ~~Löst 2026-11-13 (Aron: e-posten verifierad).~~ **GitHub kör inga Actions sedan 13 nov 10:00 (Toby 2026-11-13 17:45).** Varje körning stoppas direkt med "Please verify your email address to run GitHub Actions workflows". Inga byggen, inga simulatortester, ingen ny ipa. Gör: github.com › din profilbild › Settings › Emails › vid din e-postadress: "Resend verification email", öppna mejlet och klicka länken. Säg till i chatten när det är gjort | Måste göras, allt test står still |
| 13 | **Lägg in `SUPABASE_SERVICE_ROLE_KEY` i GitHub (Kevin 2026-11-13 19:58).** Oscar godkände K38 den 11 nov (`reports/qa/2026-11-11-1033-oscar-o38-k38-godkand.md`), så #7 gäller inte längre. Nyckeln låser upp blindtestet K48 (färdigt, väntar bara på den, 1 488 tecken), K6 och K22. Klickväg: GitHub › repot › Settings › Secrets and variables › Actions › New repository secret › Name `SUPABASE_SERVICE_ROLE_KEY` › Secret: Supabase › projektet › Project Settings › API Keys › service_role › Reveal › kopiera. (#8: ElevenLabs svarar igen, kontrollerat 19:57.) | Ja |
| 14 | **ElevenLabs Startup Grants: troligen inte aktuellt (Deangelo läste villkoren 2026-11-13 20:58).** Villkoren säger: inga projekt för barn 18 år eller yngre (Earminds målgrupp är 13–25), inga byråer, konsultbolag eller småföretag (Rothman Solutions är en webbyrå), affärsmejl krävs och de skriver inte på NDA. Kan bli aktuellt med ett eget bolag för Earmind och en åldersgräns på 18+, men det är ett ägarbeslut. | Vänta |
| 15 | **ElevenLabs-nyckeln behöver en behörighet till (K6, Kevin 2026-11-13 21:35).** Förhandsproven av roliga röster nekades: "missing the permission voice_generation". Klickväg: elevenlabs.io › Developers › API Keys › nyckeln som ligger i Supabase som ELEVENLABS_API_KEY › Edit › slå på **Voice Generation** (och gärna **User: Read**, så att servern ser plan och krediter). Nyckeln byts inte. Säg till när det är gjort | Gör det om du vill ha K6 |
| 16 | **ElevenLabs-kvoten för Scribe är slut sedan 2026-11-14 14:34 (Toby 1).** "quota_exceeded: You have exceeded your quota." Taligenkänningen i appen fungerar inte, och alla lyssningstester står still. Fyll på: elevenlabs.io › Subscription (eller vänta på nollställningen). Rapport `reports/apptest/2026-11-14-1505-toby1-t17b.md` | Fyll på om lyssningen ska testas i dag |
| 17 | **Billigare prov i ElevenLabs (Kevin K64, `reports/2026-11-14-1801-kevin-k64-queue-texts-test-modes-cost.md`).** I dag kostar ett prov på 15 frågor cirka 3 190 krediter, varav det långa svaret står för 94 %. Förslag 1: bara frågorna får ljud vid spara, och långa svaren görs under uppspelningen för de 3 närmaste frågorna. Det sparar bara på prov som aldrig spelas, men bryter din regel att allt ljud görs när provet sparas. Förslag 2: långa svaret görs först vid första trycket, cirka −56 %, med cirka 2 s väntan första gången. Förslag 3: långa svaret 90 → 70 ord, −20 %, men ett kortare A-svar. Deangelo rekommenderar att börja med förslag 2, eftersom det är det enda som sparar på riktiga användare utan att ändra röst eller svar. | Ja eller nej till 1, 2 och 3 |
| 18 | **Demosidan med EarMind (Kelly Ke60).** Stavningen är ändrad på grenen `kelly/ke60-earmind-site` men inte publicerad. | "ja" om den ska läggas ut |
| 19 | **ElevenLabs: köp krediter och ge nyckeln User Read.** Oscar har sagt JA (O62, 18:17): testerna gör inga riktiga anrop längre, så det är säkert att köpa. User Read låter servern läsa saldot och varna i tid (elevenlabs.io › Developers › API Keys › nyckeln › User Read). | Gör när du vill att ljudet ska fungera igen |
| 20 | **Läsläget (D185): vad det ska kosta.** En löpande text kostar ElevenLabs-krediter efter längd. 2 000 ord är cirka 12 000 tecken, ungefär 4 800 krediter, och det är mer än ett helt prov med 15 frågor (cirka 3 200). Tills du säger annat räknas varje påbörjad 800 tecken som en fråga mot kvoten på 15 i månaden, så gratis räcker då till cirka 2 000 ord i månaden. Det kan ändras utan ny kod. | Ok, eller annan regel |
| 21 | ~~(klart 2026-11-15 10:10: dolda, `hidden = true`, går att ångra)~~ **Två testprov är publicerade på en riktig skola** (Toby T24, skola 35374123, "Nytt prov", Biologi, 22 nov; id finns i docs/HANDOVER-toby.md). Alla som söker på skolan kan se dem. Ska de tas bort ur databasen? | "ja" så tar Kevin (moln) bort just de två |
| 22 | **Tre molnsessioner väntar på ditt klick (sedan ca 03:00).** De behöver nätåtkomst i molnmiljön AirPods. Kevin (moln) och Oscar (moln) behöver `xjczbzfkmbjdebwlccki.supabase.co`, alltså din egen Supabase-server, för livetester. Angela Fable (moln) behöver `productionresultssa0.blob.core.windows.net`, där GitHub Actions lägger bygg- och testfiler. Deangelo får inte godkänna det själv. Gör så här: öppna sessionen "Kevin molnsession för EarMind backend" och klicka **Update environment**, och gör likadant i "Oscar QA molnsession" och "Angela Fable molnsession". Kelly (moln) behöver samma blob-adress för skärmbilderna. | Klicka Update environment i de tre sessionerna |

## Repetitionsläget, kostnad (D144, 2026-11-13 17:45)
- ~~H1~~ **Ja (Aron 17:30):** det långa svaret börjar alltid med det korta svaret som första mening.
- ~~H2~~ **Beslutat (D146):** långa svar högst cirka 90 ord som standard (ett komplett A+-svar går före ordgränsen), 20 frågor som standard; användaren kan ändra båda.
- ~~H3~~ **Godkänt (D146):** blindtest A/B/C, cirka 2,50 kr. Kevin K48, Deangelo skickar filerna utan facit.

- **K62 ElevenLabs-krediterna 2026-11: under 20 % kvar** (ElevenLabs-krediter (K62):** 183 av 65 000 kvar (0%)  senast sett 2026-11-14 13:01 UTC (ur felmeddelandet: nyckeln saknar User Read), se reports/storage/latest.md). Testning använder aldrig krediter (D180). Fyll på eller byt plan: elevenlabs.io › Subscription. Att låta servern läsa saldot: elevenlabs.io › Developers › API Keys › nyckeln › User: Read.
| 23 | ~~(klart 2026-11-17 08:28: Aron raderade phawadee-thai, Deangelo skapade projektet earmind (rot site/), https://earmind.vercel.app svarar med EarMind-sidan och väntelistan)~~ **Demosidan på Vercel (D202).** (1) Vilken Vercel-plan har du? Hobby är bara för icke-kommersiellt bruk, och EarMind är kommersiellt. Pro kostar 20 USD i månaden. (2) Skapa projektet (bara du kan koppla ditt Vercel-konto): vercel.com → Add New… → Project → Import "aronstenlund-airpods-ai" → Root Directory: `site` → Framework Preset: Other → Deploy. Skriv sedan adressen (t.ex. earmind-xxx.vercel.app) till Deangelo. Kelly och Kevin gör resten. |
| 24 | **"Spela om 10 minuter" (D210).** Jag byggde det som spela upp igen och igen i 10 min till 1 timme. Om du menade att uppspelningen ska starta först om 10–60 minuter, med telefonen låst: det bygger vi inte. Det är dold, tidsinställd uppspelning, och kombinerat med förebilden Spicker blir det ett fuskverktyg för prov. Det strider mot projektets regler (CLAUDE.md), och App Store skulle stoppa appen. Säg till om du menade något annat. |

## 25. ~~Din egen gräns~~ Klart: Aron 18:33 "gör så att jag alltid har krediter som admin" (D216, K93) (2026-11-17 13:55)
Du har gjort 14 av 15 frågor med ljud den här månaden, så appen nekar mer ljud tills 1 december. ElevenLabs har krediter igen. Vill du att ditt eget konto inte har någon månadsgräns? Svara ja eller nej, så gör Kevin det. Det kostar bara ElevenLabs-krediter när du själv använder appen.

## 26. ~~Priser~~ Bestämt av Aron 21:08 (D224): 79 kr/vecka, 20 000 tecken, 5 000 välkomstkrediter, inbjudan 2 000 (förslaget nedan gäller i övrigt)
- 100 krediter 10 kr, 500 för 39 kr, 2 000 för 110 kr.
- Prenumeration 80 kr i veckan, obegränsat med en dold gräns för rimlig användning på 40 000 tecken i veckan.
- Varje nytt konto får 10 000 krediter första gången, så att man hinner prova ett helt prov. Därefter 1 500 i månaden.
- Svara ja, eller ändra siffrorna.

## 27. Betalningen i App Store Connect (D218), 2026-11-17 20:25
Appen och servern byggs nu för köp med StoreKit, men produkterna måste finnas i App Store Connect innan de går att köpa på riktigt. Det kräver dig: avtalet för betalda appar (Paid Apps Agreement med bank och skatt) och de fyra produkterna. Vi säger till när det behövs och öppnar sidan åt dig. Inget kostar något innan dess.

## 28. Får vi lyssna på taggarna en gång? (D220), 2026-11-17 20:40
För att veta att taggarna (lugnt, tydligt, viskande) och en skånsk röst faktiskt låter bra måste vi göra riktigt ljud en gång. Ett A/B-test med 6 korta texter kostar ungefär 2 000 ElevenLabs-krediter. Svara ja eller nej. Utan ja testas bara att texten blir rätt, inte hur den låter.

## 29. När det passar: prova lyssnarlägena med AirPods (D221)
Fem omstruktureringar av lyssnarlägena (Frågor, Provläge med rösten, minitestet, det tysta förhöret, studieplanen) är bara testade i simulatorn. Provlistorna står i rapporterna för A120, A125, A126, A127 och A128. Ingen brådska; de två sista stegen med högre risk väntar tills du har provat.

## 30. Läs integritetspolicyn och villkoren (Ke78), 2026-11-18 09:05
Kelly har skrivit /integritet och /villkor för earmind.vercel.app på en gren, med det som inte är verifierat markerat. De publiceras inte förrän du har läst dem och svarat ja. Deangelo skickar bilderna.

## 31. Apple-konto och Team ID (K98, App Store), 2026-11-18 09:05
För App Attest (skyddet för välkomstkrediterna) och för att lämna in appen behövs ett betalt Apple Developer-konto (99 USD per år) och dess Team ID. Har du ett konto: öppna developer.apple.com/account → Membership details, och skicka Team ID (10 tecken) till Deangelo. Det är inte hemligt. Har du inget konto är det ditt beslut om kostnaden.

## 32. ~~En inställning för inloggningen i Supabase (A143)~~ Klart 2026-11-18 12:50: Deangelo läste i dashboarden (Aron: "kolla du"). "Detect and revoke potentially compromised refresh tokens" är på, "Refresh token reuse interval" är 10 s. Inget ändrat.
Det tar en minut, och ingenting ska ändras om värdena stämmer. Appen förlitar sig på att en förnyelse av inloggningen som tappas på vägen räddas inom 10 sekunder. Kevin kan inte läsa inställningen själv, eftersom nyckeln saknar behörigheten `auth_config_read`.

1. Öppna supabase.com/dashboard, välj projektet (xjczbzfkmbjdebwlccki) och gå till **Authentication**. Under **Configuration**, välj **Sessions**. Direktlänk: `https://supabase.com/dashboard/project/xjczbzfkmbjdebwlccki/auth/sessions`.
2. Under **Refresh Tokens** står "Detect and revoke potentially compromised refresh tokens" (bör vara på) och "Refresh token reuse interval" (bör vara **10** sekunder, Supabases standard).
3. Skicka de två värdena till Deangelo. Är intervallet lägre än 10, skriv det; ändra inget själv.

Verifierat i Supabases dokumentation: intervallet finns och är 10 s som standard. Ej verifierat: att knapparna heter exakt så i dag.


## #33 Webbsvaren är slut för i dag (2026-11-18 15:15)
Testerna har använt alla 150 webbsvar för i dag, så appen svarar utan webben till kl. 01:00 svensk tid. Från och med nu har testerna ett eget tak (D234) och kan inte ta användarnas. **Fråga:** ska webbsvaren slås på igen redan i dag? Det kostar högst cirka 3–5 USD extra. Svara ja eller nej.

## #34 Inskickningen till App Store – det som bara du kan göra (2026-11-20 09:00)
Release-bygget är klart (A155, main grön 44694689538). Hela listan står i `reports/2026-11-20-0825-angela-a155-release-arkivet.md` §4. Kort:
1. Apple Developer Program (99 USD/år) om kontot inte redan är med.
2. Team ID (developer.apple.com › Membership) – skriv det i chatten, så lägger sessionerna in det i appen och hos Kevin (då slås välkomstkrediterna på).
3. Två App ID:n och appgruppen (Certificates, Identifiers & Profiles › Identifiers) – sessionerna ger exakta klick när du har Team ID.
4. Signering: säg om du vill signera i Xcode på en Mac eller i bygget med en App Store Connect API-nyckel.
5. Ny app i App Store Connect, köpen (id:na står i rapporten), formulären (Kellys texter är klara att klistra in).
6. Ladda upp och skicka till granskning.

## #35 Anthropic-nyckeln går ut 3 december (2026-11-20 16:15)
Nyckeln som servern använder för AI-svaren skapades 3 november med 30 dagars giltighet (STATUS › Reminders). Går den ut slutar appen svara. Senast 2 december: skapa en ny nyckel i console.anthropic.com (API Keys › Create Key, utan utgångsdatum eller med ett långt) och klistra in den i Supabase › Project Settings › Edge Functions › Secrets som `ANTHROPIC_API_KEY`. Säg till, så öppnar jag sidorna åt dig och Kevin kontrollerar efteråt att svaren fungerar.

## #36 Webbetan (2026-11-21 11:20)
Webbetan byggs nu på earmind.vercel.app/beta (D249–D252). Jag säger till när den är uppe, och Kelly skriver ett TikTok-svar du kan klistra in. Om Kevin behöver ändra röstlistan i en hemlighet för att ta bort Marlon får du exakta klick.

## #37 Webbetan och ElevenLabs-kapaciteten (2026-11-21 16:45)
ElevenLabs-planen räcker till cirka 90 000 tecken i månaden – ungefär 15 prov med 12 frågor för alla tillsammans. Webben får högst 10 000 tecken per dygn och varje nät 3 000. Ett nytt webbkonto har 1 500, och det minsta provet (3 frågor) kostar cirka 1 900, så besökare från TikTok kan bara använda Säg med korta texter, inte prov. Två beslut som bara du kan ta: (a) uppgradera ElevenLabs-planen (kostnad), och (b) om webbkonton ska få mer än 1 500 (till exempel 5 000 en gång). Talen kan ändras utan ny kod.
