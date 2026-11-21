# A156 – webbetan, del 1: Säg i AirPods, prov från text, krediter, skärmraden (Angela Schrute, moln, 2026-11-21 11:52)

Uppdrag: Deangelo 11:20 (D249–D251). Webbversionen ligger i `web/` och byggs till `site/beta/`. **Del 1 är på main men
inte publicerad** (Kelly äger deployen). **Lyssnarlägena är inte byggda än (del 2)**, se §5.

Märkning: **[CI]** = verifierat i GitHub Actions eller i en riktig webbläsare (huvudlös Chromium) här i sessionen ·
**[kod]** = läst i koden eller dokumentationen · **[antagande]** = otestat. **Inget är provat i Safari på iPhone eller med
AirPods**: det kan jag inte, och allt om ljud, tryck och skärmlås på telefon är därför antaganden tills Aron har provat.
**Inget anrop har gått till den riktiga servern** (den nås inte från min session), och **0 anrop till ElevenLabs**.

## 1. Vad som finns

| Del | Vad | Status |
|---|---|---|
| Säg i AirPods | Fältet, "How should it sound?" med förslag, röstkapseln och röstbladet (provlyssning ur serverns `preview_url`), tid 10–60 min, serverns kostnad under fältet (0 för en text som redan sagts), Spela, spelkortet med mening för mening, paus, nästa/föregående mening, Stoppa, Senaste (lägger tillbaka text, stil och röst; Ta bort) | [CI] i Chromium mot låtsasserver |
| Prov från text | Nytt prov (text + antal frågor), "Is this right?" med ämne, innehåll och frågorna, "Something isn't right" (rättelse utan att texten skickas igen), "Looks right" (svaren skrivs, provet sparas utan ljud), Start quiz (ljudet görs då), provspelaren med appens tryckregler, Continue · question N, Ta bort | [CI] i Chromium mot låtsasserver |
| Krediter | Kapseln "1.2k credits left", bladet med talet, "1,500 credits every month.", Så räknas det, nästa påfyllning och **"Purchases come with the iOS app."** Inget köp, ingen Fyll på-länk någonstans (test) | [CI] |
| Skärmen (D250) | Raden "Keep the screen on … up to about 10 m (33 ft) …" första gången och alltid medan något spelar; Screen Wake Lock tas när Spela/Start quiz trycks, släpps vid Stoppa/End/när tiden är slut och tas om när sidan blir synlig igen; guiden (Auto-Lock › Never, Strömsparläget, Android); "It stopped because the screen turned off. Play again?" när ljudet stannat av sig självt | Wake Lock och raden [CI] i Chromium; på iPhone [antagande] |
| AirPods | Ett `<audio>`-element + Media Session: play/pause = 1 tryck, nästa spår = 2, föregående = 3; låsskärmen får textens första rad, "EarMind", "Say in AirPods" | Media Session-metadata [CI]; trycken på riktiga AirPods [antagande] |
| Språk (D251) | Engelska som standard, svenska när `navigator.language` börjar med `sv`; går att byta i Inställningar. Kellys texter (Ke86) | [CI] |
| Konto | Anonym inloggning mot samma server som appen (`/auth/v1/signup`), kontot ligger i webbläsarens lagring; "Forget this browser" tar bort texter och prov här och på servern | [CI] mot låtsasserver; mot riktiga servern [antagande] → Oscar O94 |

Ser ut som appen efter Kellys `docs/design/webbeta.md` (färger, kort, kapslar, mörkt/ljust, ner till 320 bred, minskad
rörelse). Jag har tittat på skärmbilderna från provkörningen (engelska mörkt 393 bred, svenska ljust, 320 bred) och
jämfört med hennes skiss; **Kelly har inte granskat än.**

## 2. Teknik och beslut (DECISIONS: A156)

- **Ren TypeScript utan körberoenden.** Byggverktyg: Vite 5.4.11, TypeScript 5.6.3, Vitest 2.1.8 (bara `devDependencies`;
  CI nekar `dependencies`). Sidan är 63 kB skript + 12 kB stil (20 + 3 kB packat). `site/` är 1 684 kB (gräns 2 MB).
- **Bygget ligger i git** (`site/beta/`), eftersom Vercel serverar `site/` som filer. `base: '/beta/'`, fasta filnamn
  (`assets/app.js`, `assets/index.css`). Arbetsflödet **Web beta** kontrollerar att `site/beta` är exakt det `web/` bygger.
- **Ett ljudelement.** Safari låter en sida spela av sig själv bara på ett element som användaren har startat. Spela och
  Start quiz startar därför elementet direkt i trycket med en sekunds tystnad i slinga, och serverns filer spelas sedan på
  samma element. Tystnaden spelas också under betänketiden och medan ljudet görs, så att sidan förblir den som "spelar"
  och AirPods-trycken fortsätter att komma dit. **[antagande] för Safari på iPhone.**
- **Samma regler som appen** (portade, med test): frågespelaren (fråga → betänketid 6 s upp till 20 frågor, 4 s från 40 →
  nästa; 1 tryck långt svar, 2 kort svar = långa filen till `short_end_ms`, 3 paus; varje tryck fortsätter; börjar om
  efter sista frågan) och textspelaren (1 paus/fortsätt, 2 nästa mening, 3 föregående; varv efter varv tills tiden är slut).
- **Servern:** `web/src/api/`. Skickar `Authorization`, `apikey`, `Content-Type`, `x-earmind-lang` (webbens språk, K114)
  och `lang` i `/drill` och `/exam`. Ingen annan nyckel än den publika finns i koden (CI letar efter hemligheter i `site/`).
- **Testtrafik (D180):** `?test=1` (eller `?test=oscar-qa`, `?test=oscar-qa+slow`) sätter `x-earmind-test` för fliken;
  `?test=0` stänger av.
- **Krediter som inte räcker till ett prov:** serverns 402 läses (`fits`, `min_questions`): ryms minst tre frågor görs
  provet med så många och säger det; annars visas serverns ord och "Purchases come with the iOS app.".

## 3. Test

- **56 logiktester** (Vitest, `web/tests/`): textregler och kostnad, båda spelarna, inloggningen (nytt konto, förnyelse,
  401, serverfel behåller kontot), vad som skickas till `/drill`, texterna (båda språken har samma nycklar och samma
  platshållare, "10 m" bryts inte, inget köp-ord finns), lagret, och hela flödena Säg och prov mot en skriptad server.
  **[CI]** Web beta 44896049152 grön.
- **Provkörning i webbläsare** (`node web/scripts/smoke.mjs`): den byggda sidan i huvudlös Chromium, mobilstorlek, mot en
  låtsasserver med tyst ljud; 35 kontroller gröna här i sessionen (inget lämnar maskinen: skriptet kontrollerar att
  inga andra adresser anropas). Körs inte i CI (Playwright är inget beroende i repot); Toby kan utgå från det i T56.
- **Inte testat:** Safari/WebKit (finns inte här), iPhone, AirPods, riktiga servern, riktig CORS, riktigt ljud.

## 4. Fynd och öppna frågor

1. **Till Kevin (blockerar testare i riktig webbläsare):** `x-earmind-test` finns inte i `ALLOW_HEADERS` i
   `_shared/cors.ts`. En webbläsare som skickar den får nej redan i förfrågan före anropet (preflight), så `?test=…`
   fungerar inte från Safari/Chrome förrän den är tillagd. Huvudlösa webbläsare räknas redan som test på sin
   användaragent. **[kod]**
2. **Till Deangelo/Aron (produktfråga): ett prov från text ryms inte i webbens krediter.** En fråga kostar enligt
   serverns uppskattning 642 krediter (`estimatedCostPerQuestion`, 90 ord per långt svar); 1 500 räcker till två, och ett prov är minst tre. Ett nytt webbkonto
   får alltså alltid nej på Nytt prov (serverns ord visas, och "Purchases come with the iOS app."). Säg i AirPods
   fungerar (1 tecken = 1 kredit). Vägar: fler krediter för webbkonton, kortare svar på webben, eller att webben
   erbjuder publicerade prov (andras prov är gratis). Räknat på serverns formel: med 40 ord per långt svar (serverns
   minsta, `long_words`) kostar en fråga 327 och då ryms fyra frågor; det är ett produktval (kortare svar), inte gjort. **[kod]**, inte provat mot servern.
3. **Till Kevin inför del 2:** `/stt-token` har inget webbskydd (`withWebGuard`) i dag. Innan lyssnarlägena öppnas för
   alla på webben behöver någon bestämma vad ett webbkonto får lyssna och fråga per dag, annars kan en öppen sida dra
   ElevenLabs-krediter utan tak. **Concerns**, se nedan.
4. **Sajtens gamla adress fick en tom kopia.** När `site/beta/` kom på main publicerade Kellys flöde Deploy demo site
   (`pages.yml`, går automatiskt på `site/**`) hela `site/` till GitHub Pages (körning 44896297380). Betan fungerar inte
   där (sidan ligger under `/aronstenlund-airpods-ai/beta/` och pekar på `/beta/assets/…`, som är rätt för Vercel), så
   den sidan är tom, och inget länkar dit. Kelly avgör om `beta/` ska tas undan ur Pages-paketet. **[CI]**
5. Appens "Open link", + (bilder, fil, länk), "Type along"/tempo, Blanda röster, röstsök, delade och publicerade prov,
   Läs upp texten och ändring av enskilda frågor finns inte på webben än.

**Concerns:** lyssnarlägen på en öppen webbsida (D249) behöver samma skydd som appen: samtyckesskärmen före första
start, synlig "Listening · Stop" hela tiden, inget ljud sparas (Kellys §6 säger detta). Jag bygger dem så, och inte
förrän frågan i punkt 3 har ett svar.

## 5. Kvar

- **Del 2: lyssnarlägen via `getUserMedia`** (More modes), efter svar på punkt 3.
- Kellys granskning av del 1 och hennes publicering; därefter Oscars O94 och Tobys T56.
- **Arons prov på iPhone** (när Kelly har publicerat), i Safari med AirPods i:
  1. Öppna earmind.vercel.app/beta. Skriv en mening, tryck Play. Hörs det i AirPods? Står "The screen stays on while it plays."?
  2. Tryck en gång på AirPods (paus), en gång till (fortsätter), två gånger (nästa mening), tre gånger (föregående).
  3. Låt telefonen ligga en minut. Släcks skärmen? Om ja: stannade ljudet, och står "It stopped because the screen turned off" när du väcker den?
  4. Samma sak i Chrome på iPhone om du har den.

## 6. Nästa session

Läs svaren från Kevin (punkt 1 och 3) och Deangelo (punkt 2), Kellys granskning, och bygg del 2.
