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

## Repetitionsläget, kostnad (D144, 2026-11-13 17:45)
- ~~H1~~ **Ja (Aron 17:30):** det långa svaret börjar alltid med det korta svaret som första mening.
- ~~H2~~ **Beslutat (D146):** långa svar högst cirka 90 ord som standard (ett komplett A+-svar går före ordgränsen), 20 frågor som standard; användaren kan ändra båda.
- ~~H3~~ **Godkänt (D146):** blindtest A/B/C, cirka 2,50 kr. Kevin K48, Deangelo skickar filerna utan facit.

- **K62 ElevenLabs-krediterna 2026-11: under 20 % kvar** (ElevenLabs-krediter (K62):** 183 av 65 000 kvar (0%)  senast sett 2026-11-14 13:01 UTC (ur felmeddelandet: nyckeln saknar User Read), se reports/storage/latest.md). Testning använder aldrig krediter (D180). Fyll på eller byt plan: elevenlabs.io › Subscription. Att låta servern läsa saldot: elevenlabs.io › Developers › API Keys › nyckeln › User: Read.
