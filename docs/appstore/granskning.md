# App Store: texter, integritetsuppgifter och granskningsanteckningar (Kelly (moln), Ke76, D218, 2026-11-17)

**Förberedelse. Inget är inlagt i App Store Connect och inget skickas in** (det kräver Arons ja och TILL-ARON #27).
Ersätter texten i `README.md` (Ke56/Ke62), som beskrev appen före Säg i AirPods (D203), krediterna (D213) och köpen (D218).

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
| Röster, tempo, Skriv i takt (D220) | **[O]** A136 inte byggd än. Stryk raden om den inte är byggd vid inskickning |
| Länk som material (D204) | [S] A116; hämtningen på servern K81 **[O]** live |
| 1, 2, 3 tryck | [V] koden; **[O]** alla AirPods-modeller på telefon |
| Starta prov och Säg använder aldrig mikrofonen | [V] koden (repetitionsläget startar ingen mikrofon); **[O]** orange pricken på telefon (R9) |
| 1 500 krediter i månaden, 1 kredit = 1 tecken (D213) | [V] D213/K90 |
| Köp och veckokort | **[O]** A134 inte byggd, produkterna finns inte i App Store Connect |

## 2. Integritetsuppgifter (App Privacy)
**Spårning: Nej.** Ingen reklam-SDK, ingen analys-SDK, ingen IDFA [V: ingen sådan kod i `Lumen/`]. Inloggningen är ett
anonymt konto per installation (`auth/v1/signup` utan e-post) [V].

| Datatyp i Apples lista | Samlas in? | Kopplad till användaren | Syfte | Varför |
|---|---|---|---|---|
| **Identifierare › Användar-ID** | Ja | Ja | Appens funktioner | Det anonyma kontots id knyter prov, ljud och krediter till installationen [V] |
| **Användarinnehåll › Annat** (texter man skriver, frågor och svar) | Ja | Ja | Appens funktioner | Prov, Säg-texter och svar sparas på kontot så att de kan spelas igen [V] |
| **Användarinnehåll › Foton** | Ja | Nej | Appens funktioner | Foton och dokument skickas en gång för att göra frågorna och sparas inte [V enligt texten i appen; **[O]** att bucketen töms, K53] |
| **Ljuddata** | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | Ljudet strömmas till ElevenLabs för taligenkänning; EarMind sparar det inte, men ElevenLabs kan behålla det enligt sina villkor (D135) [V] |
| **Köp › Köphistorik** | Ja, när köpen finns | Ja | Appens funktioner | Transaktionen kontrolleras på servern för att ge krediter [O: A134/K94 inte byggda] |
| **Användningsdata › Produktinteraktion** | Ja | Ja | Appens funktioner (kostnadskontroll) | Servern loggar per anrop vilken funktion, tid och kostnad, ingen text (D48, usage-rader) [V] |
| **Diagnostik** | Nej | – | – | Ingen kraschrapportering i appen [V]. Apples egna kraschrapporter räknas inte |
| **Kontakter › Kontakter** | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | När flera kontakter passar ett namn skickas upp till fyra namn till servern så att EarMind kan fråga vem du menar; numret skickas aldrig [V i koden, `LivePhoneTools.callContact`, A142]. Rättat 2026-11-18 (stod "Nej") |
| **Användarinnehåll › Annat** (kalenderhändelser) | Ja, bara i Fler lägen (beta) | Nej | Appens funktioner | När man frågar vad som finns i kalendern skickas upp till 20 händelser (titel, tid, plats) till servern för svaret [V i koden, A142]. Apple har ingen egen kalender-kategori; "Annat användarinnehåll" är närmast. Rättat 2026-11-18 |
| Påminnelser, larm | Nej | – | – | Appen lägger bara till och läser inget [V i koden, A142] |
| Kontaktuppgifter (e-post) | Nej i appen | – | – | E-post samlas bara på webbsidans väntelista, inte i appen [V] |
| Plats, hälsa, finans, sökhistorik | Nej | – | – | [V] |

**Måste rättas eller beslutas före inskickning (till Deangelo/Aron):**
1. ~~**Testläget (D140) skickar allt bakgrundsljud till oss**~~ **Klart (D227, A142): testläget finns inte i Release.** Gällde: när det är på (raderas efter 14 dagar). Det får inte finnas i
   App Store-versionen utan att deklareras. Förslag: **testläget finns bara i TestFlight/Debug**, inte i release. Annars
   måste Ljuddata deklareras som "kopplad till användaren" med syftet produktförbättring. **[O] hög**
2. ~~**Kamerans text i Info.plist**~~ **Klart (A142).** Gällde: texten sa "The text is read on the iPhone; the photo is not saved." Fotona skickas till
   servern för att göra frågorna, så första halvan stämmer inte. Förslag: "Take a photo of the page you are studying.
   The photo is sent once to make your questions and is not saved." (Angela Schrute) **[V] att texten är fel**
3. **Rapporterade frågor (D135):** "med samtycke läser utvecklaren dem, raderas inom 14 dagar". Om det finns i appen ska
   det in som Användarinnehåll, syfte produktförbättring. **[O]**
4. **Minnen (D37 m.fl.) i Fler lägen** sparas på servern? Om ja: Användarinnehåll, kopplat. **[O]**
5. ~~**Mikrofontexten (D138)**~~ **Klart (D229, A146).** Två avvikelser från D229 som Kelly stöder (sanna och ger mer): meningen om Sömnläget står kvar, och taligenkänningens text säger att iPhonens egen igenkänning håller ljudet på telefonen. Deangelo bekräftar. Gällde: texten sa inte att ljudet skickas till en taligenkänningstjänst. Apple (5.1.1) vill att
   texten säger vad datan används till. Kelly stöder Angela Schrutes förslag: "Ljudet skickas till en
   taligenkänningstjänst, blir text och sparas inte av EarMind." Deangelo beslutar (ändrar D138). **[V] att texten saknar det**
6. **Integritetspolicy** krävs (URL i App Store Connect) och saknas. Förslag: en sida på earmind.vercel.app/integritet
   med samma uppgifter som tabellen. **Utkast klart (Ke78, grenen `kelly/ke78-integritet`), väntar på Arons ja (TILL-ARON #30)**

## 3. Granskningsanteckningar (App Review Information › Notes), på engelska
> EarMind reads text aloud in the user's earbuds to help them study.
>
> 1. Say in AirPods (first screen): the user types or pastes a text and taps "Play for 10 min". The text is spoken with
> text-to-speech and repeats for the chosen time (10–60 minutes). Playback is always visible: the card shows "Playing in
> AirPods", the time left, Pause and Stop, and the system Now Playing controls are used. There is no delayed or scheduled
> playback and no hidden mode. The microphone is never used here.
>
> 2. Start quiz: photos or text become quiz questions with answers (Claude by Anthropic). Answers are spoken
> (ElevenLabs) when the user presses the earbuds. The microphone is never used.
>
> 3. More modes (beta) use the microphone. Before the first start the app shows a consent screen; the microphone is only
> requested after that. While listening, a bar at the top of every screen shows that the app is listening, with one-tap
> Stop. Audio is streamed for speech recognition and not stored by EarMind.
>
> 4. Credits and purchases: 1,500 credits per month are free. Credit packs are consumables. The weekly pass is an
> auto-renewable subscription; price, renewal and how to cancel are shown next to the purchase button, with links to
> Terms and Privacy.
>
> 5. Account: no sign-in is needed (anonymous account per install). The account and everything on the server can be
> deleted in the app: Settings › Account › Delete account (A145). [Aron: add here how the reviewer gets credits, e.g.
> that the review build/account has unlimited credits. Do not put any password in this repository.]
>
> 6. AirPods are not required; the app also plays through the phone speaker.

**[O]** punkt 1 "Now Playing controls" och låst skärm (D209), punkt 3 att samtycket visas före mikrofonfrågan (D21, [V]
i koden: `ListeningModel` vägrar utan samtycke), punkt 6 högtalaren (texten i appen säger att det går, inte provat av mig).

## 4. Övrigt som Apple frågar efter
| Fält | Förslag | Status |
|---|---|---|
| Åldersgräns | **12+**; Rizz-läget (flirtförslag, beta) och AI-svar kan ge "Infrequent/Mild Mature/Suggestive Themes". Är Rizz kvar: svara ärligt i frågeformuläret | **[O]** Aron |
| Kategori | Utbildning (primär), Produktivitet (sekundär) | förslag |
| Support-URL | earmind.vercel.app (har kontaktadress) | [V] sidan finns (Ke70) |
| Marknadsförings-URL | earmind.vercel.app | [V] |
| Villkor (EULA) | Apples standard-EULA räcker, länk i köpdelen | förslag |
| Exportregler (kryptering) | Bara HTTPS från systemet → "nej" på egen kryptering | [V] ingen egen kryptokod hittad |
