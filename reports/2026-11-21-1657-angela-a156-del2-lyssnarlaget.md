# A156 del 2 – lyssnarläget på webben (Angela Schrute, moln, 2026-11-21 16:57)

Uppdrag: Deangelo 11:20 (D249–D251), sista delen: "lyssnarlägen via getUserMedia". Del 1: `reports/2026-11-21-1152-…`,
A158: `reports/2026-11-21-1612-…`.

**Viktigast först:** det finns **ett** lyssnarläge på webben – appens vanliga (Frågor). Handledare, Intervju, Socialt,
Rizz och Provläge finns inte på webben. Och **vägen mot riktiga Scribe (ElevenLabs) har ingen provat**: alla tester får
serverns testsvar utan sockel (D180), så första riktiga provet blir Arons eget.

Märkning: **[CI]** = verifierat i GitHub Actions eller huvudlös Chromium här · **[kod]** = läst i koden ·
**[antagande]** = otestat. 0 anrop till ElevenLabs, inget anrop till riktiga servern från min session.

## 1. Vad som finns

- **Fler lägen (beta)** längst ned på första skärmen: "EarMind listens through your microphone and answers what you
  ask." och knappen **Start listening**.
- **Samtycket först (D21).** Första gången visas Kellys samtyckesblad (fem punkter, `webbeta.md` §9) med knappen "I
  understand, start listening". Först därefter frågar webbläsaren om mikrofonen. Samtycket sparas i webbläsaren med
  datum, går att läsa igen och **ta tillbaka i Inställningar** (då stoppas lyssningen och bladet visas igen nästa gång).
- **Det syns alltid att den lyssnar.** En rad överst på varje skärm: "● Listening · Stop" / "● Answering · Stop",
  också ovanpå blad. Skärmraden (D250) visas. **Döljs sidan eller släcks skärmen avslutas lyssningen** och sidan säger
  varför när man kommer tillbaka: sidan lyssnar aldrig där den inte syns.
- **Så går en fråga:** mikrofonens ljud skickas till Scribe (ElevenLabs) med en engångsbiljett från servern
  (`/stt-token`); när talaren har tystnat skickas turen till `/answer` på samma sätt som appen gör i Frågor
  (`mode: tutor`); servern avgör om det var en fråga och säger ingenting annars; svaret visas och läses upp mening för
  mening via `/tts` på sidans enda ljudelement.
- **Halv duplex:** medan ett svar läses skickas inget från mikrofonen, så sidan kan inte svara på sin egen röst ur en
  högtalare. Ett tryck på AirPods (eller på svaret) stoppar svaret.
- **En sak i taget:** Spela och Starta prov stoppar lyssningen; Start listening stoppar det som spelas.
- **Inget sparas:** varken ljud eller ord, inte i webbläsaren och inte av servern (webben sätter inte `qa_log`;
  Kelly har läst samma sak i koden). När lyssningen stoppas skickas bara antalet sekunder (`POST /stt-token`).
- **Tak (Kevins K114):** 20 lyssningar per nät och 150 för hela webben per dygn; `/tts` räknas mot webbens kredittak.
  Nej från servern (429 `web_daily_cap`, `rate_limited`) visas med serverns egna ord.

## 2. Teknik (DECISIONS: A156 del 2)

- `web/src/listen/`: `pcm.ts` (till 16 kHz, 16 bitar, base64), `scribe.ts` (sockelns adress som appen bygger den:
  `commit_strategy=vad`, tystnad 0,60 s, `eng`/`swe` efter språkvalet; meddelanden; livstecken var 8:e sekund),
  `sse.ts` (serverns händelser), `sentences.ts` (meningar, högst 500 tecken), `session.ts` (passet).
- **Turen:** Scribe avslutar en mening efter 0,6 s tystnad; sidan väntar 0,4 s till (appens paus på 1,0 s), och 3 s om
  meningen ser oavslutad ut ("skillnaden mellan …"). Tal som fortsätter håller kvar turen.
- **Sockel som stängs:** har den varit öppen minst 20 s öppnas den igen med ny biljett (högst tre gånger per pass);
  stängs den direkt är det ett fel och sidan säger det, i stället för att be om biljett efter biljett (taket är 20).
- **Mikrofonen:** `getUserMedia` + `ScriptProcessor` (gammal men finns överallt, ingen extra fil). Inget spelas tillbaka.
- **Ingen reserv med webbläsarens egen taligenkänning.** Säger servern nej blir det ingen lyssning.
- `Client.raw()` för svar som inte är JSON (händelseström, ljud), med samma inloggning och 401-omförsök.
- Sidan är nu 91 kB skript (29 kB packat); `site/` 1 756 kB.

## 3. Små saker från de andra, med i samma leverans

- **Kevin:** rösterna på det valda språket först (katalogens `language`); `lang` skickas i `/answer`.
- **Oscar (O94):** när ett anrop faller fast nätet finns säger sidan "EarMind couldn't be reached right now. Try again
  in a moment." i stället för "Check your connection." (`navigator.onLine`).
- **Kelly (§10):** kreditkapseln i kortform ("1.2k left") vid 359 px och smalare; knappens egen text är hela meningen.
- **Fel funnet av provkörningen:** långa blad klämde ihop innehållet och klippte det (samtyckets sista punkt syntes inte)
  i stället för att rulla. Rättat för alla blad; provkörningen mäter att sista punkten går att läsa.

## 4. Test

- **100 logiktester** (28 nya för lyssningen): ljudet till Scribe, sockelns adress och meddelanden, händelseströmmen,
  meningsdelningen, och passet mot låtsasmikrofon, låtsassockel och låtsasserver: start, tur, svar i meningar, halv
  duplex, tal som fortsätter, inte en fråga, tryck stoppar svaret, Stop, nekad mikrofon, webbens tak, testtrafik utan
  sockel, sockel som stängs, livstecken, uppläsning som inte går, svar som tas tillbaka, dold sida.
  Testerna för `listen/`-grunden skrevs tillsammans med koden, passets tester efter koden; två fel hittades av dem
  (ett återtaget svar lästes ändå upp; textnycklar saknades).
- **59 kontroller i huvudlös Chromium** med låtsasmikrofon mot låtsasserver (`node web/scripts/smoke.mjs`): samtycket
  före mikrofonen, hela samtycket går att läsa, raden överst, svaret på skärmen, uppläsning i två meningar, lyssnar
  igen, Stop, ingen samtyckesskärm andra gången, Spela stoppar lyssningen, samtycket taget tillbaka.
- **Web beta-flödet:** se STATUS för körningens nummer.

## 5. Inte testat, och risker

1. **Riktiga Scribe-sockeln [antagande].** Adress och meddelanden följer appens kod, som fungerar på telefon, men
   webbens väg har aldrig öppnat en riktig sockel. Ett prov kostar ElevenLabs-krediter och är därför Arons (D180).
2. **Safari på iPhone med AirPods [antagande].** När mikrofonen är på byter iOS ljudläge; svaren kan låta sämre eller
   lägre, och AirPods-trycken kan bete sig annorlunda än vid ren uppspelning.
3. **Eko ur högtalare** hanteras bara genom halv duplex; med AirPods finns inget eko.
4. **Kostnad:** varje lyssningspass drar Scribe-tid tills det stoppas; taket är Kevins (20 pass per nät och dygn), och
   ett pass har ingen egen tidsgräns på sidan. **Fråga till Deangelo/Kevin:** ska ett pass stoppas av sig självt efter
   en viss tid (till exempel 30 minuter)? Jag har inte lagt in någon gräns.
5. Bara Frågor-läget finns. De andra lägena bygger på mycket applogik (profiler, talare, kalibrering) och är egna
   uppgifter om de ska till webben.

## 6. Arons prov (när Kelly har publicerat; kostar lite ElevenLabs-krediter)

1. earmind.vercel.app/beta i Safari med AirPods i. Rulla ned till **More modes**, tryck **Start listening**.
2. Läs samtycket, tryck "I understand, start listening", tillåt mikrofonen. Står "● Listening" överst?
3. Ställ en fråga högt ("What is photosynthesis?"). Kommer svaret på skärmen och i AirPods?
4. Tryck en gång på AirPods medan den svarar: slutar den?
5. Lås skärmen och lås upp: står det att lyssningen stannade?
6. Inställningar › Withdraw consent: kommer samtycket tillbaka nästa gång?

## 7. Nästa session

Arons och Tobys fynd; svaret på frågan om tidsgräns (5.4); A149 väntar fortfarande på Arons telefonprov.

## Tillägg 17:40 – tidsgräns per pass (Kevins svar på 5.4)

Kevin: servern kan inte stänga en Scribe-sockel (den går direkt mellan webbläsaren och ElevenLabs), så gränsen ligger
på sidan. **Ett lyssningspass stängs nu av sig självt efter 30 minuter**, sidan säger "Listening stopped after 30
minutes. Start again to go on." / "Lyssningen stannade efter 30 minuter. Starta igen för att fortsätta.", och sekunderna
skickas som vid Stop. Två tester skrivna först (gränsen; ett stoppat pass kortar inte nästa); 102 logiktester och 59
kontroller i Chromium gröna. **[CI]** Web beta: se STATUS.

Toby 17:10: lyssnarläget är grönt lokalt i WebKit och Chromium (T56 44922296899), och mikrofonen fungerar i Playwrights
WebKit. Live väntar på Kellys publicering. Riktiga Scribe är fortfarande oprovad.

