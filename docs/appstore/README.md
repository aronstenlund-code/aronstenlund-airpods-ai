# App Store-produktsidan (Kelly (moln), Ke90, D253, 2026-11-26; Ke80 2026-11-18)

**Klar att lägga in, men inget är uppladdat eller inskickat.** Det görs bara efter Arons ja (TILL-ARON #27).
**Engelska är primärt språk** (appen startar på engelska, D253): välj *English (U.S.)* som primärt språk i App Store
Connect och lägg till *Swedish* som lokalisering med texterna i §2b. Integritet och granskningsanteckningar:
`granskning.md`. Kontrollen av vad texten lovar: §5.

## 1. Bilder (6,9 tum, 1320 × 2868)
Rubrik ovanför en oförändrad skärmbild ur appen (Apple-stil, D160): grå bakgrund, mörk ram, ingen skugga. Skärmbilderna
är tagna i **full storlek** på iPhone 17 Pro Max med Kellys bildflöde `kelly-appstore-shots.yml` på engelska
(`en/`) och svenska (`sv/`), ljust läge, med `say.hasPlayed` så att raden om låst skärm inte syns. Rådata: grenen
`kelly/appstore-shots-ke90`. Rubrikerna är satta i Inter Display (molnet); byt till SF Pro Display på en Mac om Aron vill.

| # | Scen | English | Svenska |
|---|---|---|---|
| 1 | `repSayCredits` | **Type. Listen.** What you type is read in your earbuds. | **Skriv. Lyssna.** Det du skriver läses upp i dina hörlurar. |
| 2 | `repSayOnCard` | **Again and again.** From 10 minutes up to an hour. | **Om och om igen.** Från 10 minuter upp till en timme. |
| 3 | `repSayPicked` | **How should it sound?** Describe it, and EarMind picks a voice. | **Hur ska det låta?** Skriv det, så väljer EarMind en röst. |
| 4 | `repSayVoicesUser` | **Pick a voice.** Listen first. It's free. | **Välj en röst.** Lyssna först. Det kostar inget. |
| 5 | `repSayCompressed` | **Make it shorter.** Compress keeps the content in fewer words. | **Gör det kortare.** Komprimera ger samma innehåll med färre ord. |
| 6 | `repTextNew` | **Snap your textbook.** Quiz questions with answers, or the whole text read aloud. | **Fota boken.** Frågor med svar, eller hela texten uppläst. |
| 7 | `repPlayAnswer` | **Press for the answer.** Once for the long answer, twice for short, three times to pause. | **Tryck för svaret.** 1 gång för långt svar, 2 för kort, 3 för paus. |
| 8 | `listeningActivation` | **Say your words.** Question you're not prepared for? Say [ … ] so our AI activates. | **Säg dina ord.** Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI. |
| 9 | `repShop` | **Start free.** 1,500 credits are included every month. | **Börja gratis.** 1 500 krediter ingår varje månad. |
| 10 | `repOwnDeck` | **Record it yourself.** Completely free. The sound stays on your phone. | **Spela in själv.** Helt gratis. Ljudet stannar på din telefon. |

Bild 1–3 syns i sökresultatet och berättar idén. Bild 8 visar lyssnarvyn med "● Listening" och orden ifyllda (scenen `listeningActivation`, Angela Schrute A166), så att det syns att mikrofonen används. Bild 10 är Spela in själv (A165). Telefonens egen modell (D258) syns
inte på någon bild: den finns ingen scen för, och det riktiga provet på telefon är inte gjort; den står bara i texten
(§2, med villkor i §5). Inget om låst skärm (D209) och inget som antyder dold användning: varje bild visar appen öppen.
"Swedish voices" i bild 4 är appens riktiga rubrik (katalogen har
bara svenska röster), och priserna i kr kommer från simulatorns butik.

## 2. Texter, English (primärt språk; tecken räknade med Python)
| Field | Limit | Text | Chars |
|---|---|---|---|
| Name | 30 | EarMind | 7 |
| Subtitle | 30 | Study by listening in earbuds | 29 |
| Promotional text | 170 | Type what you want to hear, or snap your textbook. EarMind reads it in your earbuds, again and again, or turns it into quiz questions. | 134 |
| Promotional text, launch week only | 170 | Launch week: 65% off everything in EarMind. Ends soon. *(kan bytas utan ny granskning; byt tillbaka när veckan slutar, D259)* | 54 |
| Keywords | 100 | `study,exam,quiz,flashcards,read aloud,revision,homework,vocabulary,school,audio,learn,record,voice` | 98 |
| Support URL | – | https://earmind.vercel.app | – |
| Marketing URL | – | https://earmind.vercel.app | – |
| Privacy Policy URL | – | https://earmind.vercel.app/integritet (**Ke78, inte publicerad**: Arons ja först) | – |
| Terms (EULA) | – | Apples standard-EULA, och länken https://earmind.vercel.app/villkor i beskrivningen (3.1.2; **inte publicerad**) | – |
| Category | – | Education (primary), Productivity (secondary) | – |
| Age rating | – | **13+** (förslag, §4) | – |

"AirPods" står inte i namnet, undertiteln eller nyckelorden (D122, Apples varumärkesregler), bara i beskrivningen.
Ke78-sidorna är på svenska; en engelsk version behövs innan den engelska sidan skickas in (förslag, Arons ja först).

**Description** (2 406 av 4 000 tecken):

> Type what you want to hear, or snap your textbook. EarMind reads it in your earbuds, again and again.
>
> SAY IN AIRPODS
> • Type or paste a text and tap Play. It repeats from 10 minutes up to an hour.
> • Describe how it should sound, like "calm, like a teacher", and EarMind picks a voice that fits. Or pick one yourself and listen first.
> • Long text? Tap Compress for a shorter version with the same content. You can edit it before it's read.
> • Type along reads slowly with pauses, so you have time to write.
> • You always see that it's playing and how much time is left, and you stop whenever you like.
>
> SNAP YOUR TEXTBOOK
> • Take photos of pages, choose images, add a PDF or Word file, or paste a link.
> • Get quiz questions with a short and a long answer, or the whole text read aloud.
> • Change, delete or add your own questions and answers.
>
> START QUIZ
> • The questions are read in your earbuds. Press once for the long answer, twice for the short one and three times to pause.
> • Start quiz and Say in AirPods never use the microphone.
>
> SHARE WITH YOUR CLASS
> • Share a quiz with a link or publish it for your school. Photos and documents are never shared.
>
> CREDITS
> • 1,500 credits are included every month.
> • 1 credit is 1 character of new audio. Audio that already exists and repeats are free.
> • Invite a friend and get 2,000 credits when your friend has played their first text.
> • Buy more credits or a weekly pass in the app. The weekly pass renews every week until you cancel.
>
> RECORD IT YOURSELF – COMPLETELY FREE
> • Write your own questions and answers and record them in your own voice. Then practice them in your earbuds.
> • No credits, and the sound stays on your phone.
>
> MORE MODES (BETA)
> EarMind also has modes that listen to what you say and answer in your ear, like a spoken quiz. They ask for permission and for the microphone before they start, and always show that they're listening.
> • Question you're not prepared for? Say your own words, and EarMind answers the question that was just asked.
>
> WHEN OUR SERVER CAN'T ANSWER
> On iPhones with Apple Intelligence, EarMind can answer and grade with the phone's own model instead, and tells you when it does. No credits are used for that.
>
> Works with AirPods. EarMind is not made by or affiliated with Apple. AI answers can be wrong, so check with your textbook.
>
> Terms: https://earmind.vercel.app/villkor
> Privacy: https://earmind.vercel.app/integritet

## 2b. Texter, svenska (lokalisering)
| Fält | Gräns | Text | Tecken |
|---|---|---|---|
| Namn | 30 | EarMind | 7 |
| Undertitel | 30 | Lyssna och plugga i hörlurarna | 30 |
| Reklamtext | 170 | Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar, om och om igen, eller gör provfrågor med svar. | 127 |
| Reklamtext, bara lanseringsveckan | 170 | Lanseringsvecka: 65 % rabatt på allt i EarMind. Slutar snart. | 61 |
| Nyckelord | 100 | `plugga,prov,förhör,glosor,uppläsning,läxor,repetition,instudering,provfrågor,skola,gymnasiet,röster` | 99 |

URL:er, kategori och åldersgräns som på engelska.

**Beskrivning** (2 383 av 4 000 tecken):

> Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar, om och om igen.
>
> SÄG I AIRPODS
> • Skriv eller klistra in en text och tryck Spela. Den läses upp om och om igen, från 10 minuter upp till en timme.
> • Skriv hur det ska låta, till exempel "lugnt, som en lärare", så väljer EarMind en röst som passar. Eller välj själv och lyssna först.
> • Lång text? Tryck Komprimera, så får du en kortare text med samma innehåll. Du kan ändra den innan den läses upp.
> • Skriv i takt läser långsamt med pauser, så att du hinner skriva.
> • Du ser hela tiden att det spelas och hur länge det är kvar, och du stoppar när du vill.
>
> FOTA BOKEN
> • Fota sidor, välj bilder, lägg till en PDF eller Word-fil eller klistra in en länk.
> • Få provfrågor med ett kort och ett långt svar, eller hela texten uppläst.
> • Ändra, ta bort eller lägg till egna frågor och svar.
>
> STARTA PROV
> • Frågorna läses upp i dina hörlurar. Tryck 1 gång för det långa svaret, 2 gånger för det korta och 3 gånger för paus.
> • Starta prov och Säg i AirPods använder aldrig mikrofonen.
>
> DELA MED KLASSEN
> • Dela ett prov med en länk eller publicera det för din skola. Foton och dokument delas aldrig.
>
> KREDITER
> • 1 500 krediter ingår varje månad.
> • 1 kredit är 1 tecken nytt ljud. Ljud som redan finns och upprepningar kostar inget.
> • Bjud in en kompis och få 2 000 krediter när kompisen har spelat sin första text.
> • Köp fler krediter eller ett veckokort i appen. Veckokortet förnyas varje vecka tills du säger upp det.
>
> SPELA IN SJÄLV – HELT GRATIS
> • Skriv egna frågor och svar och läs in dem med din röst. Öva sedan på dem i hörlurarna.
> • Inga krediter, och ljudet stannar på din telefon.
>
> FLER LÄGEN (BETA)
> EarMind har också lägen som lyssnar på vad du säger och svarar i örat, till exempel förhör med rösten. De frågar om lov och om mikrofonen innan de startar, och visar hela tiden att de lyssnar.
> • Fråga du inte är beredd på? Säg dina egna ord, så svarar EarMind på frågan som just ställdes.
>
> NÄR VÅR SERVER INTE KAN SVARA
> På iPhone med Apple Intelligence kan EarMind svara och rätta med telefonens egen modell i stället, och säger till när den gör det. Det kostar inga krediter.
>
> Fungerar med AirPods. EarMind är inte gjord av eller kopplad till Apple. Svar från AI kan vara fel, så kontrollera mot din kursbok.
>
> Villkor: https://earmind.vercel.app/villkor
> Integritet: https://earmind.vercel.app/integritet

## 3. Måste vara sant när den skickas in
1. **Ke78 publicerad** (integritet och villkor), annars fungerar inte länkarna. Arons ja (TILL-ARON #30).
2. **Produkterna** (tre paket och veckokortet) finns i App Store Connect och skickas med bygget; annars ser granskaren
   bara "Paketen kunde inte hämtas …". (TILL-ARON #27)
3. **Byggnummer** på bilderna: se `kelly/appstore-shots-ke90`/RUN.txt (körning och commit). Ändras en skärm före
   inskickning: kör flödet igen och `appstore.py`.
4. **Telefonens egen modell** (D258): Aron har provat den på sin iPhone; annars stryks stycket "WHEN OUR SERVER CAN'T
   ANSWER" / "NÄR VÅR SERVER INTE KAN SVARA" och punkt 9 i granskningsanteckningarna.
5. **Spela in själv** (D263): A165 är på main (2026-11-26); bygget som skickas in måste vara från main efter `afbe239c`.

## 4. Åldersgräns (förslag 13+)
Apples frågeformulär (2025: 4+, 9+, 13+, 16+, 18+). Svar som Kelly föreslår, **Aron svarar ärligt i formuläret**:
- Mogna eller suggestiva teman: **sällsynt/milt** (Rizzläget i Fler lägen ger flirtförslag, D112, inget sexuellt).
- Innehåll som AI skapar: ja (svar, frågor, röstval). Användare kan publicera prov för sin skola (rapporteras och döljs).
- Inget våld, inga droger, inget spel om pengar, ingen obegränsad webb.
Det ger troligen **13+**, vilket stämmer med integritetssidan ("från 13 år"). **untested assumption**: Apples svar
avgör.

## 5. Kontroll: lovar texten mer än appen gör?
Mot `granskning.md` §1 och dagens main. [V] i koden eller beslut, [S] sett i Simulatorn, [L] provat live mot servern
(Oscar), **[O]** inte provat på telefon.
| Påstående | Status |
|---|---|
| Upprepas 10 min till 1 timme (D210) | [S] A124/A132 |
| "Skriv hur det ska låta … väljer EarMind en röst", "välj själv och lyssna först" | [S] A136/A140, [L] O81 (14 röster, AI-val med motivering) |
| Skriv i takt med pauser | [S] A136; pausernas längd **[O]** |
| "Du ser att det spelas och hur länge det är kvar" | [S] A132 |
| Länk, PDF, Word som material | [S] A116; hämtningen K81 **[O]** live |
| 1, 2, 3 tryck | [V]; **[O]** alla AirPods-modeller |
| Starta prov och Säg använder aldrig mikrofonen | [V]; **[O]** orange prick på telefon (R9) |
| Dela med länk, publicera för skolan | [S] A81/A83; att länken öppnar appen **[O]** |
| 1 500 i månaden, inbjudan 2 000 | [V] D213/D224, [L] O82. **Välkomsten (5 000) nämns inte** förrän den är på (Team ID, TILL-ARON #31, D239); läggs då till i beskrivningen och bild 8 |
| Köp och veckokort | [S] A134 med låtsasbutik; **[O]** StoreKit-filen (T48) och produkterna i App Store Connect |
| Fler lägen frågar om lov och visar att de lyssnar | [V] D21, `ListeningModel` |
| Komprimera: kortare text, samma innehåll, går att ändra före uppläsning (Ke90) | [V] D262, K120 live (O98); [S] A163 |
| Egna ord aktiverar svaret på frågan som just ställdes (Ke90) | [V] A162; att orden hörs i riktigt tal **[O]** |
| Telefonens egen modell svarar och rättar, säger till, inga krediter (Ke90) | [V] A159/A160 med låtsasmodell i CI; **[O]** på telefon, se §3 punkt 4 |
| Spela in själv, gratis, ljudet stannar på telefonen (Ke90) | [V] A164/A165 (`OwnDeckStore` på telefonen, `PhoneVoice` = `AVSpeechSynthesizer` för det som inte är inspelat); [S] A165. Inspelning på telefon **[O]** |
| **Står inte i texten:** låst skärm (D209), "andra hörlurar", att ljudet fungerar utan nät | medvetet utelämnat |

## Göra om bilderna
```
gh workflow run kelly-appstore-shots.yml --ref main -f branch=kelly/appstore-shots-ke90 -f languages="en sv" -f screens="repSayCredits repSayOnCard repSayPicked repSayVoicesUser repSayCompressed repTextNew repPlayAnswer repShop repOwnDeck"
gh workflow run kelly-appstore-shots.yml --ref main -f branch=kelly/appstore-shots-ke90b -f languages="en sv" -f screens="listeningActivation"
python3 -I docs/appstore/_src/appstore.py <mapp med bilderna från båda grenarna> en
python3 -I docs/appstore/_src/appstore.py <mapp med bilderna> sv
```
Utan fontargument används Inter Display (finns i molnet). Äldre bilder (Ke56–Ke80, `69-*.jpg`) finns i git-historiken.
