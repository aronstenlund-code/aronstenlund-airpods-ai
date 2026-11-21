# A158 – webbetan: engelska först med EN/SV-val, Ladda ner ljudet, en Nytt prov-knapp (Angela Schrute, moln, 2026-11-21 16:12)

Uppdrag: Deangelo 16:15 (D253). Med i samma leverans: **Open link** (delade prov), som jag byggde efter del 1 av A156.

Märkning: **[CI]** = verifierat i GitHub Actions eller i huvudlös Chromium här · **[kod]** = läst i koden ·
**[antagande]** = otestat. **Inget är provat i Safari på iPhone**, och **inget anrop har gått till riktiga servern**
eller till ElevenLabs.

## 1. Vad som är gjort

1. **Engelska alltid först (D253).** Betan startar på engelska oavsett webbläsarens språk. Överst finns ett synligt val
   **EN | SV** bredvid kugghjulet; valet sparas i webbläsaren (localStorage i try/catch, annars bara för besöket) och
   gäller nästa gång. Bytet visar allt på det nya språket, det man höll på att skriva följer med, och servern får
   språket i varje anrop (`x-earmind-lang`) och i `lang` till `/drill` och `/exam`. **[CI]**
2. **Ladda ner ljudet (MP3).** I spelkortet och i provspelaren: "Download the sound" hämtar de filer servern redan har
   gjort och sätter ihop dem till **en** MP3 – en text del för del, ett prov som fråga följd av långt svar för varje
   fråga. Sedan står "Save the MP3" (en riktig länk, som varje webbläsare låter en spara från) och raden "A downloaded
   file plays with the screen off in your phone's own player." Inget nytt ljud görs, inga krediter dras. Knappen finns
   inte medan ljudet fortfarande görs. **[CI]** i Chromium med låtsasfiler.
3. **Den dubbla Nytt prov-knappen är borta.** Det tomma provkortet hade en egen "New quiz" precis ovanför radens "New
   quiz" längst ned; kortet är nu bara förklaringen, och knappen finns på ett ställe. **[CI]** (provkörningen räknar: 1.)
4. **Open link (delade prov, gratis).** Raden längst ned har "Open link": en inklistrad länk eller kod slås upp
   (`share_info`), visas och läggs till som eget prov (`import`). Ljudet är originalets, så inga krediter dras – det är
   vägen till prov för ett webbkonto, som inte har råd med ett eget (se A156-rapporten §4.2). En delad text (Läs upp)
   kan betan inte öppna än och säger det. **[CI]** mot låtsasserver.
5. **Fel funnet av provkörningen och rättat i roten:** valda saker (språk, röst, tid) märktes med `aria-pressed` utan
   värde, vilket varken stilen eller VoiceOver läser som valt. Alla ARIA-tillstånd skrivs nu som `true`/`false`. **[CI]**

## 2. Teknik

- `web/src/core/mp3.ts`: `joinMp3` lägger filernas MP3-rutor efter varandra och tar bort det som inte är ljud: ID3-taggar
  (början och slut) och den inledande Xing/Info-rutan, som annars får en spelare att visa första delens längd för hela
  filen. Bytes som inte är MP3 lämnas orörda. `fileName` ger "EarMind - <titel>.mp3" utan tecken en telefon inte tar.
- `App.prepareDownload()`: frågar servern om färska länkar först (de gäller en timme), hämtar varje fil en gång, visar
  "Getting the sound … 2 of 6", och städar bort filen vid Stoppa/End.
- Språket: `chosenLanguage(stored)` i `web/src/texts.ts`; `pickLanguage` (D251) är borttagen.
- Vid 400 px och smalare visas inte BETA-brickan överst (EN/SV behöver platsen); ordet beta står kvar i skärmraden och
  längst ned. Kelly avgör om det ska vara så.

## 3. Test

- **72 logiktester** (16 nya, skrivna först): MP3-sammanfogningen (rena filer, taggar, Xing/Info, icke-MP3), filnamn,
  språkregeln, nedladdningen (text, prov i rätt ordning, inte medan ljudet görs, fel och nytt försök, städning vid
  Stoppa), Open link (hittad, död länk, tomt, delad text), attributen.
- **46 kontroller i huvudlös Chromium** mot låtsasserver (`node web/scripts/smoke.mjs`): svensk webbläsare startar på
  engelska, SV byter allt, det skrivna följer med, servern får `sv`, valet finns kvar efter omladdning, nedladdningen
  ger en fil med rätt namn och typ, en Nytt prov-knapp, 320 px brett på båda språken.
- **Web beta-flödet** (tester + att `site/beta` är exakt det `web/` bygger): se körningens nummer i STATUS.

## 4. Inte testat, och risker

1. **Hämtningen av ljudfilerna från riktiga lagringen [antagande].** Nedladdningen läser filerna med `fetch`, och det
   kräver att Supabase Storage svarar med CORS-huvud för signerade länkar (uppspelningen kräver det inte). Standard i
   Supabase är att det gör det, men jag har inte kunnat prova. Blir det nej visas "The sound couldn't be downloaded.
   Try again." **Toby: prova live.**
2. **Spara filen i Safari på iPhone [antagande].** Safari ska fråga "Vill du hämta …?" och lägga filen i Filer, där
   den går att spela med skärmen av. Inte provat.
3. **Provets fil har inga tankepauser** mellan fråga och svar (frågan följs direkt av det långa svaret).
4. Kvar från A156: lyssnarlägena (del 2) väntar på Kevins svar om tak för webbkonton. Hjälpläsningen av serverkoden
   visar att `/answer` och `/tts` från webben bara har kontotaket per nät (inte webbens kredittak) och att `/tts` inte
   drar krediter alls; `/stt-token` har inget webbskydd. **[kod]**

## 5. Arons prov (när Kelly har publicerat)

1. Öppna earmind.vercel.app/beta: står allt på engelska? Tryck **SV**: blir allt svenska, och är det svenska kvar när du öppnar sidan igen?
2. Skriv en mening, tryck Play, tryck **Download the sound**, sedan **Save the MP3**. Hamnar filen i Filer, och spelar den med skärmen av?
3. Längst ned: finns bara en "New quiz"?

## 6. Nästa session

Tobys svar om nedladdningen live (punkt 4.1), Kellys ord och syn på BETA-brickan, Kevins svar om lyssnarlägena.
