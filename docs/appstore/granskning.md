# App Store: texter, integritetsuppgifter och granskningsanteckningar (Kelly (moln), Ke76, D218, 2026-11-17)

**Förberedelse. Inget är inlagt i App Store Connect och inget skickas in** (det kräver Arons ja och TILL-ARON #27).
Ersätter texten i `README.md` (Ke56/Ke62), som beskrev appen före Säg i AirPods (D203), krediterna (D213) och köpen (D218).
**Ke90 (2026-11-26):** produktsidan är nu **engelska först** (appen startar på engelska, D253) och svenska som andra
språk; båda texterna och bilderna står i `README.md`. Det nya (aktiveringsordet D259, Komprimera D262, telefonens egen
modell D258/D260, Spela in själv D263) är kontrollerat mot koden i tabellen nedan och i §3.

Märkning: **[V]** verifierat i koden eller dokumenten, **[S]** sett i simulatorn, **[O] overifierat** (måste provas eller
bekräftas före inskickning). Inget här är provat på telefon av mig.

## 1. Texter

### Svenska (primärt språk)
> **Ersatt av `README.md` (Ke80, 2026-11-18):** de svenska texterna, bilderna, URL:erna och åldersgränsen gäller där.
> Texten nedan är Ke76-versionen och står kvar som historik. Den engelska texten nedan gäller fortfarande (om appen
> säljs utanför Sverige), men saknar röster och välkomstkrediter.

| Fält | Gräns | Text | Tecken |
|---|---|---|---|
| Namn | 30 | EarMind | 7 |
| Underrubrik | 30 | Lyssna och plugga i hörlurarna | 30 |
| Reklamtext | 170 | Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar, om och om igen, eller gör provfrågor med svar. | 127 |
| Nyckelord | 100 | `plugga,prov,förhör,glosor,uppläsning,läxor,repetition,instudering,provfrågor,skola,gymnasiet` | 92 |

**Beskrivning:**
> Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar och du kan ha telefonen i fickan.
>
> SÄG I AIRPODS
> • Skriv eller klistra in en text och tryck Spela. Den läses upp om och om igen i 10 minuter upp till en timme.
> • Välj röst och tempo. Skriv i takt läser långsamt med pauser, så att du hinner skriva.
> • Du ser hela tiden att det spelas och hur länge det är kvar, och du stoppar när du vill.
>
> FOTA BOKEN
> • Fota sidor, välj bilder, lägg till en PDF eller Word-fil eller klistra in en länk.
> • Välj Frågor, så gör EarMind provfrågor med ett kort och ett långt svar. Eller välj Läs upp texten.
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
> • 1 500 krediter ingår varje månad. 1 kredit är 1 tecken nytt ljud. Ljud som redan finns och upprepningar kostar inget.
> • Köp fler krediter eller ett veckokort i appen.
>
> FLER LÄGEN (BETA)
> EarMind har också lägen som lyssnar på vad du säger och svarar i örat, till exempel förhör med rösten. De är i beta och
> frågar om lov och om mikrofonen innan de startar.
>
> Fungerar med AirPods. EarMind är inte gjord av eller kopplad till Apple. Svar från AI kan vara fel, så kontrollera mot din kursbok.

### English
> **Ersatt av `README.md` (Ke90, 2026-11-26):** engelska är nu primärt språk; texten nedan är Ke76-versionen (historik).

| Field | Text |
|---|---|
| Subtitle | Study by listening in earbuds *(29)* |
| Promotional text | Type what you want to hear, or snap your textbook. EarMind reads it in your earbuds, again and again, or turns it into quiz questions. |
| Keywords | `study,exam,quiz,flashcards,read aloud,revision,homework,vocabulary,school,audio,learn` *(85)* |

> Type what you want to hear, or snap your textbook. EarMind reads it in your earbuds while your phone stays in your pocket.
>
> SAY IN AIRPODS
> • Type or paste a text and tap Play. It repeats for 10 minutes up to an hour.
> • Pick a voice and a speed. "Type along" reads slowly with pauses, so you can take notes.
> • You always see that it is playing and how long is left, and you can stop at any time.
>
> SNAP YOUR TEXTBOOK
> • Take photos of pages, pick images, add a PDF or Word file, or paste a link.
> • Choose Questions to get quiz questions with a short and a long answer, or Read aloud.
>
> START QUIZ
> • Questions are read in your earbuds. Press once for the long answer, twice for the short one, three times to pause.
> • Start quiz and Say in AirPods never use the microphone.
>
> CREDITS
> • 1,500 credits are included every month. 1 credit is 1 character of new audio. Existing audio and repeats are free.
> • Buy more credits or a weekly pass in the app.
>
> MORE MODES (BETA)
> Modes that listen to what you say and answer in your ear. They are in beta and ask for permission and for the microphone first.
>
> Works with AirPods. EarMind is not made by or affiliated with Apple. AI answers can be wrong.

*(Appen är bara på svenska i dag. Den engelska texten behövs bara om appen säljs i engelskspråkiga länder; annars räcker svenska.)*

### Påståendena i texten och vad som är kontrollerat
| Påstående | Status |
|---|---|
| Upprepar i 10 min till 1 timme (D210) | [S] A124/A132 |
| "Du ser att det spelas och hur länge det är kvar" | [S] A132 |
| Spelar vidare med låst skärm, styrs från AirPods (D209) | **[O]** därför står det inte i texten; Aron provar på telefon |
| Röster, tempo, Skriv i takt (D220) | [S] A136/A140, live O81; pausernas längd **[O]** på telefon |
| Länk som material (D204) | [S] A116; hämtningen på servern K81 **[O]** live |
| 1, 2, 3 tryck | [V] koden; **[O]** alla AirPods-modeller på telefon |
| Starta prov och Säg använder aldrig mikrofonen | [V] koden (repetitionsläget startar ingen mikrofon); **[O]** orange pricken på telefon (R9) |
| 1 500 krediter i månaden, 1 kredit = 1 tecken (D213) | [V] D213/K90 |
| Köp och veckokort | [S] A134 (låtsasbutik), [V] `/purchase`; produkterna finns inte i App Store Connect än (Aron) |
| **Ke90:** Komprimera ger en kortare text med samma innehåll, som går att ändra före uppläsning (D262) | [V] `SayCompress`, K120 `POST /exam compress` live (O98); [S] A163 `repSayCompressed`. Knappen syns först vid 160 tecken, därför "Lång text?" |
| **Ke90:** "Say your own words, and EarMind answers the question that was just asked" (D259, A162) | [V] `ActivationPhrase`, A162-testerna; [S] fältet i lyssnarvyn. Gäller inte Socialt och Rizz (står inte i texten, som bara säger "answers"). Hörs orden rätt i riktigt tal: **[O]** på telefon |
| **Ke90:** "On iPhones with Apple Intelligence … answer and grade with the phone's own model … tells you … no credits" (D258, D260) | [V] `OnDeviceAnswerProvider`, `AnswerGrader` (raden "Telefonens modell:" / "The phone's model:"), inga krediter dras; bara låtsasmodell i CI. **[O] Foundation Models på riktig telefon (D258 punkt 5).** Stryk stycket om Arons prov inte går igenom före inskickning |
| **Ke90:** Spela in själv – helt gratis, ljudet stannar på telefonen (D263) | [V] A164/A165 på main (`OwnDeckStore`, `PhoneVoice`); [S] A165; inspelning på telefon **[O]** |

## 2. Integritetsuppgifter (App Privacy)
**Spårning: Nej.** Ingen reklam-SDK, ingen analys-SDK, ingen IDFA [V: ingen sådan kod i `Lumen/`]. Inloggningen är ett
anonymt konto per installation (`auth/v1/signup` utan e-post) [V].

| Datatyp i Apples lista | Samlas in? | Kopplad till användaren | Syfte | Varför |
|---|---|---|---|---|
| **Identifierare › Användar-ID** | Ja | Ja | Appens funktioner | Det anonyma kontots id knyter prov, ljud och krediter till installationen [V] |
| **Användarinnehåll › Annat** (texter man skriver, frågor och svar) | Ja | Ja | Appens funktioner | Prov, Säg-texter och svar sparas på kontot så att de kan spelas igen [V] |
| **Användarinnehåll › Foton** | Ja | Nej | Appens funktioner | Foton och dokument skickas en gång för att göra frågorna och sparas inte [V i koden: raderas direkt efter analysen i `exam/drill.ts`/`exam/read.ts`, och `drill-purge` (pg_cron var 15:e min) tar bort allt äldre än en timme, K53] |
| **Ljuddata** | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | Ljudet strömmas till ElevenLabs för taligenkänning; EarMind sparar det inte, men ElevenLabs kan behålla det enligt sina villkor (D135) [V] |
| **Köp › Köphistorik** | Ja, när köpen finns | Ja | Appens funktioner | Transaktionen kontrolleras på servern (`/purchase`, StoreKit 2, K94) för att ge krediter eller veckokortet [V i koden; A134 byggd; inga riktiga köp gjorda] |
| **Användningsdata › Produktinteraktion** | Ja | Ja | Appens funktioner (kostnadskontroll) | Servern loggar per anrop vilken funktion, tid och kostnad, ingen text (D48, usage-rader) [V] |
| **Diagnostik** | Nej | – | – | Ingen kraschrapportering i appen [V]. Apples egna kraschrapporter räknas inte |
| **Kontakter › Kontakter** | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | När flera kontakter passar ett namn skickas upp till fyra namn till servern så att EarMind kan fråga vem du menar; numret skickas aldrig [V i koden, `LivePhoneTools.callContact`, A142]. Rättat 2026-11-18 (stod "Nej") |
| **Användarinnehåll › Annat** (kalenderhändelser) | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | När man frågar vad som finns i kalendern skickas upp till 20 händelser (titel, tid, plats) till servern för svaret [V i koden, A142]. Apple har ingen egen kalender-kategori; "Annat användarinnehåll" är närmast. Rättat 2026-11-18 |
| Påminnelser, larm | Nej | – | – | Appen lägger bara till och läser inget [V i koden, A142] |
| Kontaktuppgifter (e-post) | Nej i appen | – | – | E-post samlas bara på webbsidans väntelista, inte i appen [V] |
| **Användarinnehåll › Kundsupport** (A152) | Ja | Ja | Appens funktioner | "Fel svar?", talat "rapportera" och Feedback och förslag skickar den egna frågan, svaret och kommentaren till utvecklarna, med konto-id; högst 90 dagar [V i koden, punkt 3 c] |
| **Användarinnehåll › Annat**, syftet **Analys** (A152) | Ja | Delad historik ja; frågeloggen nej | Analys (produktförbättring) | Frågeloggen (högst 14 dagar, utan konto-id) och frivillig delad historik (högst 12 månader) [V i koden, punkt 3 a, b, d] |
| Plats, hälsa, finans, sökhistorik | Nej | – | – | [V] |

**Ke90, det nya och App Privacy (svaren i 2b ändras inte):** Komprimera skickar texten till servern och Claude som
andra texter, och servern sparar bara en rad utan text (`exam-compress` i `answer_usage`) [V i `exam/handler.ts`].
Aktiveringsorden sparas på telefonen och följer med som nyckelord till taligenkänningen i Fler lägen (A162 punkt 5,
`ListeningModel`), alltså inom raden Ljuddata. Telefonens egen modell skickar inget. Spela in själv: inspelningarna
lämnar aldrig telefonen (D263), så de är inte "collected". [V i koden, utom vyerna i A165]

**Måste rättas eller beslutas före inskickning (till Deangelo/Aron):**
1. ~~**Testläget (D140) skickar allt bakgrundsljud till oss**~~ **Klart (D227, A142): testläget finns inte i Release.** Gällde: när det är på (raderas efter 14 dagar). Det får inte finnas i
   App Store-versionen utan att deklareras. Förslag: **testläget finns bara i TestFlight/Debug**, inte i release. Annars
   måste Ljuddata deklareras som "kopplad till användaren" med syftet produktförbättring. **[O] hög**
2. ~~**Kamerans text i Info.plist**~~ **Klart (A142).** Gällde: texten sa "The text is read on the iPhone; the photo is not saved." Fotona skickas till
   servern för att göra frågorna, så första halvan stämmer inte. Förslag: "Take a photo of the page you are studying.
   The photo is sent once to make your questions and is not saved." (Angela Schrute) **[V] att texten är fel**
3. **Rapporterade frågor (D135):** "med samtycke läser utvecklaren dem, raderas inom 14 dagar". Om det finns i appen ska
   det in som Användarinnehåll, syfte produktförbättring. ~~**[O]**~~ **Svar ur koden (Angela Schrute, A152, 2026-11-19):
   ja, det finns i Release, på fyra sätt. Inget av dem är bortkompilerat (bara testläget är det, D227).** [V i koden]
   | Flöde | När | Vad som skickas | Kopplat till kontot | Sparas | Kod |
   |---|---|---|---|---|---|
   | a. Frågeloggen i lyssnarlägena (D116, K30) | efter lyssnarsamtycket (version 5 eller senare), bara i Fler lägen | varje fråga och svar, siffror maskade; aldrig krissvar, demon eller obesvarade | nej (tabellen har varken konto-id eller installations-id) | högst 14 dagar | `ListeningModel.context(for:)` sätter `qa_log`, `CloudAnswerProvider`; `backend/supabase/functions/answer/qalog.ts`; `20261110210000_qa_log.sql` |
   | b. Frågeloggen i repetitionsläget (D197, K77; **ändrad av D247/K113, live 2026-11-20**) | **bara för testkonton och när appen skickar `share_history: true` (Dela historik, D57); vanliga användares prov loggas inte.** Appen skickar inte flaggan än (ingen `share_history` i `Lumen/`), så i dag loggas bara testkonton | nya och ändrade frågor med svar | nej | högst 14 dagar | `backend/supabase/functions/drill/handler.ts:1132` |
   | c. Rapporter och feedback (D57) | "Fel svar?" på ett svar i Fler lägen, talat "rapportera", Inställningar › Feedback och förslag | den egna frågan, svaret, kommentaren; andras tal skickas aldrig | **ja** (konto-id ur inloggningen och installations-id) | tills ärendet är hanterat, högst 90 dagar | `FeedbackClient.send`, `ListeningModel.report`; `20261107233000_feedback_status_retention.sql` |
   | d. Delad historik (D57) | frivilligt: frågan visas en gång efter lyssnarsamtycket, reglaget står i Feedback och förslag, av från början | egna frågor och appens svar | **ja** (konto-id och installations-id) | högst 12 månader, tas bort när man slår av | `FeedbackClient.sync`, `RootView` (`ShareHistoryPromptView`); `20261106120000_feedback_and_shared_history.sql` |
   - **Följd för App Privacy:** "Användarinnehåll › Annat" får också syftet **Analys** (a, b, d: produktförbättring), och en ny rad **"Användarinnehåll › Kundsupport"**, kopplad, syfte Appens funktioner (c). Så står det i `PrivacyInfo.xcprivacy`.
   - **Texten "14 dagar" i D135 gäller frågeloggen (a, b).** Rapporter (c) ligger kvar upp till 90 dagar och delad historik (d) upp till 12 månader; policyn bör säga alla tre.
   - ~~Beslut som behövs: b har inget samtycke~~ **Avgjort (D247, K113 live):** repetitionsloggen skrivs bara för testkonton och den som delar historik. [V i backend-koden]
4. **Minnen (D37 m.fl.) i Fler lägen** sparas på servern? Om ja: Användarinnehåll, kopplat. ~~**[O]**~~ **Svar ur koden (Angela Schrute, A152, 2026-11-19): nej.** [V i koden]
   - Minnena ligger i filen `memories.json` på telefonen (`MemoryStore`, `Lumen/Core/History/MemoryStore.swift`) och visas och raderas under Inställningar.
   - De **skickas** med varje fråga i Fler lägen (högst 30 × 200 tecken, `AnswerContext.memories`) och till `/memory` när appen letar efter något nytt att minnas. Servern använder dem för svaret och sparar ingen text: `/memory` har ingen skrivning till databasen, bara samma rad utan text i `answer_usage` (`backend/README.md`, D80) [V i backend-koden].
   - Enligt Apples definition är det inte "insamlat" (det behålls inte längre än anropet), så ingen egen rad behövs. Undantag: slår användaren på frågeloggen eller delad historik (punkt 3 a och d) kan en fråga som nämner ett minne hamna där.
5. ~~**Mikrofontexten (D138)**~~ **Klart (D229, A146).** Två avvikelser från D229 som Kelly stöder (sanna och ger mer): meningen om Sömnläget står kvar, och taligenkänningens text säger att iPhonens egen igenkänning håller ljudet på telefonen. Deangelo bekräftar. Gällde: texten sa inte att ljudet skickas till en taligenkänningstjänst. Apple (5.1.1) vill att
   texten säger vad datan används till. Kelly stöder Angela Schrutes förslag: "Ljudet skickas till en
   taligenkänningstjänst, blir text och sparas inte av EarMind." Deangelo beslutar (ändrar D138). **[V] att texten saknar det**
6. **Integritetspolicy** krävs (URL i App Store Connect) och saknas. Förslag: en sida på earmind.vercel.app/integritet
   med samma uppgifter som tabellen. **Utkast klart (Ke78, grenen `kelly/ke78-integritet`), väntar på Arons ja (TILL-ARON #30)**
7. **Privacy manifest (A152, D238): finns.** `Lumen/Resources/PrivacyInfo.xcprivacy` och `LumenControls/PrivacyInfo.xcprivacy`, båda i Release-appen (iOS build 44584413378). Ingen spårning. Skäl: UserDefaults `CA92.1` och `1C8F.1` (delat med widgeten), filers datum `C617.1` (ljudcachen i appens egen mapp), systemets uppstartstid `35F9.1` (tid mellan händelser i appen), diskutrymme `E174.1` (FluidAudios kod). Paketen: SpotifyiOS har eget manifest; FluidAudio har inget och läser ledigt diskutrymme på en rad (`LFM3AudioConfig.swift:81`), som därför står i appens manifest med `E174.1`. Release-binären importerar just de fyra: `NSUserDefaults`, `mach_absolute_time`, `NSURLContentModificationDateKey`, `NSURLVolumeAvailableCapacityKey`. [V i bygget]

## 2b. App Store Connect › App Privacy: svaren att klicka in (Ke84, engelska som i formuläret)
Apples definition: data är "collected" när den lämnar telefonen och vi eller en partner (Anthropic, ElevenLabs,
Supabase) kan nå den längre än själva anropet. "Linked" = knuten till kontots id. Tracking: **No** för allt.

**Do you or your third-party partners collect data from this app? → Yes**

| Data type (Apple) | Collected | Linked to user | Used for tracking | Purposes |
|---|---|---|---|---|
| Identifiers › **User ID** | Yes | Yes | No | App Functionality |
| User Content › **Other User Content** (texts, questions and answers, calendar events asked about in More modes) | Yes | Yes | No | App Functionality, **Analytics** |
| User Content › **Photos or Videos** | Yes | No | No | App Functionality |
| User Content › **Audio Data** (More modes only) | Yes | No | No | App Functionality |
| Contacts › **Contacts** (names only, More modes) | Yes | No | No | App Functionality |
| Purchases › **Purchase History** | Yes | Yes | No | App Functionality |
| Usage Data › **Product Interaction** (function, time, cost per call; no text) | Yes | Yes | No | App Functionality |
| Contact Info, Health & Fitness, Financial Info, Location, Sensitive Info, Browsing History, Search History, Diagnostics, Other Data | No | – | – | – |
| User Content › **Customer Support** ("Wrong answer?", spoken "report", Feedback and suggestions) | Yes | Yes | No | App Functionality |

Grund: tabellen i §2 och Angela Schrutes svar på punkt 3–4 (A152, `PrivacyInfo.xcprivacy` säger detsamma); varje rad
kontrollerad i koden. **Analytics** på Other User Content: frågeloggarna (punkt 3 a, b; ej kopplade, högst 14 dagar) och
delad historik (3 d; frivillig, kopplad, högst 12 månader). **Customer Support**: rapporter (3 c, kopplade, högst 90
dagar). **Minnen** (punkt 4) behålls inte på servern och är därför inte "collected".
**Efter D247 (K113, live 2026-11-20):** repetitionsloggen (3 b) skrivs bara för testkonton och för den som delar
historik, så Analytics på Other User Content kommer från lyssnarlägenas logg efter samtycke (3 a) och delad historik
(3 d). Svaren i tabellen är oförändrade och stämmer med koden. "Linked" för foton, ljud och kontakter är **No** eftersom de
inte sparas på kontot (foton raderas inom en timme, ljud sparas inte av EarMind, kontaktnamn bara i svaret);
partnern kan behålla dem enligt sina villkor, därför "Collected: Yes".

## 3. Granskningsanteckningar (App Review Information › Notes), på engelska – klar att klistra in (Ke84)
> EarMind reads text aloud in the user's earbuds to help them study. No sign-in is needed.
>
> 1. Say in AirPods (first screen): type or paste a text and tap "Play for 10 min". The text is spoken with
> text-to-speech and repeats for the chosen time (10–60 minutes). Playback is always visible: the card shows "Playing in
> AirPods", the time left, Pause and Stop, and the system Now Playing controls are used. There is no delayed or scheduled
> playback and no hidden mode. The microphone is never used here. "How should it sound?" lets the user describe a style;
> the app suggests a voice, or the user picks one from the voice sheet (previews are free).
>
> 2. Start quiz: photos, documents, a link or text become quiz questions with answers (Claude by Anthropic). Answers are
> spoken (ElevenLabs) when the user presses the earbuds. The microphone is never used. Photos are deleted after the
> questions are made.
>
> 3. More modes (beta) use the microphone. Before the first start the app shows a consent screen; the microphone is only
> requested after that. While listening, a bar at the top of every screen shows that the app is listening, with one-tap
> Stop. Audio is streamed for speech recognition and not stored by EarMind.
>
> 4. Credits: 1 credit is 1 character of new audio; repeats and existing audio are free. Every account gets 1,500 free
> credits per month, enough to try Say in AirPods. A quiz with audio needs more (about 6,000 credits); the quiz screen
> shows the cost before anything is made, and the credits sheet offers packs and the weekly pass (about 3 quizzes a week).
> Inviting a friend gives 2,000 credits after the friend plays a first text. Credit packs are consumables. The weekly
> pass is an auto-renewable subscription; price, renewal and how to cancel are shown next to the purchase button, with
> links to Terms and Privacy. Purchases are verified on our server.
>
> 5. Account: an anonymous account is created on first launch. The account and everything on the server can be deleted
> in the app: Settings › Account › Delete account. Feedback and reports are sent only when the user taps them.
>
> 6. AirPods are not required; the app also plays through the phone speaker.
>
> 7. Compress (Say in AirPods, texts of 160 characters or more): the text is shortened by our server (Claude) or, if the
> server can't, by the phone's own model. The shorter text is shown and can be edited or undone before anything is played.
>
> 8. Activation words (More modes, after consent): the user can type their own words. When they are heard while the app
> is listening, it answers the question that was just asked. The words are only used for speech recognition.
>
> 9. When our server can't answer (for example busy or down), the app uses Apple's on-device model (Foundation Models)
> where it is available, and the answer or grade says that it comes from the phone's model. No credits are used for it.

**Punkt 10 (Spela in själv, A165 på main 2026-11-26), klistra in efter punkt 9:**
> 10. Record it yourself (free): the user writes questions and answers and records them in their own voice. The
> microphone is used only while the user records (system microphone prompt first). The recordings stay on the phone and
> are never uploaded. Practice plays them back like a saved quiz and uses no credits; anything not recorded is read by
> the phone's built-in voice (AVSpeechSynthesizer), also on the phone.

Punkt 1 och 2 ("The microphone is never used") stämmer fortfarande: Spela in själv är en egen skärm.

**Före inskickning (Aron/Deangelo), inte i texten ovan:**
- **Krediter för granskaren (O101 G1, hög):** 1 500 räcker för Säg men inte för ett prov (3 frågor ≈ 1 926, servern
  säger "not enough for an exam"; ett prov ≈ 6 000). Punkt 4 är därför rättad (Ke90) och lovar inte längre att ett prov
  ryms. Granskaren köper med sandlådan (O100 S3: App Review köper fortfarande). Välkomsten (5 000)
  kräver Team ID och App Attest (TILL-ARON #31, D239); är den på, lägg till i punkt 4: "New accounts also get 5,000
  welcome credits." Annars: ge granskaren krediter på serversidan och skriv det här. **Inget lösenord i repot.**
- Låst skärm (D209) står inte i texten (inte provad på telefon).

Kontroll (Kelly, Ke84): punkt 1 Now Playing [V i koden: `RepetitionSession` sätter `MPNowPlayingInfoCenter`,
`RemoteCommandHub`]; röster och stil [V: A136/A140, live O81]. Punkt 2 foton raderas [V: `exam/drill.ts`,
`drill-purge`]. Punkt 3 samtycke före mikrofon [V: `ListeningModel` vägrar utan samtycke]. Punkt 4 1 500/månad, inbjudan
[V: D213/D224, live O82], köp verifieras [V: `/purchase`]. Punkt 5 Radera konto [V: A145/K101]. Punkt 6 högtalaren
[V i koden: Säg kräver inga hörlurar; inte provat på telefon]. Ke90: punkt 7 [V `SayCompress`, D262, K120 live O98],
punkt 8 [V `ActivationPhrase`, A162], punkt 9 [V `OnDeviceAnswerProvider`/`AnswerGrader`; **[O]** riktig Foundation
Models, stryk punkten och stycket i beskrivningen om Arons prov inte går igenom], punkt 10 [V A164/A165]. Punkt 4 rättad efter O101 G1 (Ke90): [L] Oscar, 1 500 räcker inte till ett prov.

## 4. Övrigt som Apple frågar efter
| Fält | Förslag | Status |
|---|---|---|
| Åldersgräns | **13+** (Apples skala 2025), se `README.md` §4: Rizz-läget (milda flirtförslag, beta) och AI-innehåll; svara ärligt i formuläret | förslag, Aron |
| Kategori | Utbildning (primär), Produktivitet (sekundär) | förslag |
| Support-URL | earmind.vercel.app/support (Ke94; /sv/support på svenska) | [V] sidan finns; **kontaktadress saknas** (TILL-ARON #38) |
| Marknadsförings-URL | earmind.vercel.app | [V] |
| Villkor (EULA) | Apples standard-EULA räcker, länk i köpdelen | förslag |
| Exportregler (kryptering) | Bara HTTPS från systemet → "nej" på egen kryptering | [V] ingen egen kryptokod hittad |
