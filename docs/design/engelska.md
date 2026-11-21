# English texts (Kelly (moln), Ke86, D251, 2026-11-21)

English is the base language; Swedish stays as the translation (D251). This file gives the English for every text in
Kelly's design docs, for the iOS app (Angela Fable, A157) and the web beta (Angela Schrute, A156). Where the app already
has an English key in `Localizable.xcstrings`, keep it unless it differs from this file.

**Style:** short, plain, second person, sentence case ("Play for 10 min", not "Play For 10 Min"). No exclamation marks.
No "please". Numbers in English format: `1,236`, short `1.2k` (D222 in English: one decimal, dot), money from
`Product.displayPrice`. `{…}` is a value.

## 1. Words to keep the same everywhere
| Swedish | English | Note |
|---|---|---|
| EarMind | EarMind | never translated |
| Säg i AirPods | Say in AirPods | the first-screen card; "AirPods" only as "in AirPods", never as a product claim |
| Spela | Play | |
| Spela i 10 min | Play for 10 min | |
| Hur ska det låta? | How should it sound? | |
| Röst | Voice | |
| Blanda röster | Mix voices | |
| Skriv i takt / I takt | Type along / Type along | capsule says "Type along" |
| Krediter | Credits | |
| Fyll på | Top up | |
| Veckokort | Weekly pass | |
| Bjud in | Invite | |
| Nytt prov | New quiz | |
| Starta prov | Start quiz | |
| Prov | Quiz | "prov" = quiz everywhere |
| Frågor och svar | Questions and answers | |
| Läs upp texten | Read aloud | |
| Senaste | Recent | |
| Nästa prov | Next quiz | |
| Andra prov | Other quizzes | |
| Prov från din skola | Quizzes from your school | |
| Fler lägen | More modes | |
| Öppna länk | Open link | |
| Inställningar | Settings | |
| Klar | Done | |
| Avbryt | Cancel | |
| Stoppa | Stop | |
| Avsluta | End | |
| Försök igen | Try again | |

## 2. First screen and the Say card (forsta-skarmen.md, sag-i-airpods.md)
| Place | Swedish | English |
|---|---|---|
| Credits capsule | {1 236} krediter kvar · {1,2k} krediter kvar | {1,236} credits left · {1.2k} credits left |
| Placeholder | Skriv eller klistra in det du vill höra | Type or paste what you want to hear |
| Placeholder, largest text | Skriv här | Type here |
| Main button | Spela i {10} min · Spela i 1 timme | Play for {10} min · Play for 1 hour |
| Main button, empty field with clipboard | Klistra in | Paste |
| Duration menu title | Spela i | Play for |
| Duration menu | 10 min … 55 min · 1 timme | 10 min … 55 min · 1 hour |
| Tempo menu | Skriv i takt · 0,5× · 0,75× · 1,0× · 1,5× | Type along · 0.5× · 0.75× · 1.0× · 1.5× |
| + menu | Fota sidor · Välj bilder · Lägg till fil · Klistra in länk | Take photos · Choose photos · Add file · Paste link |
| Cost | {120} krediter · 0 krediter | {120} credits · 0 credits |
| Cost, sound exists | Kostar inget. Ljudet finns redan. | Free. The sound already exists. |
| Not enough credits | {120} krediter · du har {88} · Fyll på | {120} credits · you have {88} · Top up |
| Before play, too expensive | Det här kostar {764} krediter. Du har {312} kvar. Nya krediter den 1 {december}. | This costs {764} credits. You have {312} left. New credits on {December} 1. |
| Lock line (iOS app only, first time; D209/D250 untested) | Du kan låsa telefonen. Det hörs i AirPods ändå. | You can lock your phone. You'll still hear it in your AirPods. |
| Link could not be read | Sidan gick inte att läsa. Kopiera texten och klistra in den i stället. | The page couldn't be read. Copy the text and paste it instead. |
| Waiting 8 s | Det tar längre tid än vanligt. | This is taking longer than usual. |
| Gave up, online | Ljudet kunde inte hämtas. · Försök igen | The sound couldn't be loaded. · Try again |
| No network | Ljudet kunde inte hämtas. Kolla nätet. · Försök igen | The sound couldn't be loaded. Check your connection. · Try again |
| Refused, no server text | Det gick inte att spela just nu. Försök igen om en stund. | Can't play right now. Try again in a moment. |
| Playback off (D200) | Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt. | Reading aloud is paused for now. The text works as usual. |
| Playing, card | ● Spelar i AirPods · {Astrid} · {7:32} kvar · Stoppa | ● Playing in AirPods · {Astrid} · {7:32} left · Stop |
| Making the sound | Gör ljudet … | Making the sound … |
| Paused | {7:32} kvar · pausad | {7:32} left · paused |
| Player, top | ● Spelar i AirPods | ● Playing in AirPods |
| Player, row | Varv {3} · {7:12} kvar av {10} min | Round {3} · {7:12} left of {10} min |
| Recent, long press | Ta bort | Delete |
| VoiceOver field | Säg i AirPods | Say in AirPods |
| VoiceOver cost | Kostar {120} krediter | Costs {120} credits |
| VoiceOver Recent | {text}, {stil eller röst} · Lägger tillbaka texten | {text}, {style or voice} · Puts the text back |
| VoiceOver + | Lägg till material | Add material |
| VoiceOver duration | Hur länge, {10} minuter | Duration, {10} minutes |
| VoiceOver playing | Spelar i AirPods med {Astrid}, {7} minuter kvar | Playing in AirPods with {Astrid}, {7} minutes left |

## 3. Style and voices (stil-och-roster.md)
| Place | Swedish | English |
|---|---|---|
| Style placeholder | Hur ska det låta? | How should it sound? |
| Style suggestions | Tydligt · Lugnt · Glatt · Viskande | Clear · Calm · Cheerful · Whisper |
| AI's choice | Vald efter stilen · {motivering} / Vald efter stilen. | Chosen for the style · {reason} / Chosen for the style. |
| Voice sheet | Röst · Klar | Voice · Done |
| Search | Sök bland alla röster | Search all voices |
| Section | Svenska röster | Swedish voices · English voices |
| Mix voices | Blanda röster · Varje stycke får en egen röst, samma varje gång. | Mix voices · Each paragraph gets its own voice, the same every time. |
| Capsule when mixed | Blandat | Mixed |
| Library voice not in catalog | Kan bara provlyssnas | Preview only |
| Footnote | Provlyssning kostar inget. En ny röst blir nytt ljud. | Previews are free. A new voice means new sound. |
| VoiceOver voice capsule | Röst, {Astrid} | Voice, {Astrid} |
| VoiceOver ▶ | Provlyssna {Astrid} | Preview {Astrid} |
| Review section (admin only) | Att provlyssna | To review |

## 4. Credits and purchases (kop.md)
| Place | Swedish | English |
|---|---|---|
| Sheet | Krediter · Klar | Credits · Done |
| Big number | {1 236} · krediter kvar | {1,236} · credits left |
| Welcome (when on) | {5 000} · välkomstkrediter | {5,000} · welcome credits |
| Sections | Fyll på · Varje vecka · Bjud in · Så räknas det | Top up · Every week · Invite · How it's counted |
| Pack | {100} krediter · {10 kr} | {100} credits · {price} |
| Badge | Bäst värde | Best value |
| Pack footnote | Ett prov ≈ 6 000 krediter. | One quiz ≈ 6,000 credits. |
| Weekly pass | Veckokort · {79 kr} i veckan · cirka 3 prov | Weekly pass · {price} a week · about 3 quizzes |
| Subscription footnote (3.1.2) | Veckokortet kostar {79 kr} i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. Säg upp i Inställningar › ditt namn › Prenumerationer. | The weekly pass costs {price} a week and renews automatically until you cancel at least 24 hours before the next week. Cancel in Settings › your name › Subscriptions. |
| Links | Villkor · Integritet · Återställ köp | Terms · Privacy · Restore purchases |
| Invite row | Få 2 000 krediter · när en kompis har spelat sin första text · Bjud in | Get 2,000 credits · when a friend plays their first text · Invite |
| Invite link text | Plugga med EarMind. Du får 5 000 krediter att börja med. | Study with EarMind. You get 5,000 credits to start. *(only when welcome is on, D239)* |
| Invite done | +2 000 krediter för en inbjudan. | +2,000 credits for an invite. |
| Ten a month | Du har bjudit in 10 i månaden. Fler ger krediter nästa månad. | You've invited 10 this month. More will earn credits next month. |
| Rows | 1 tecken nytt ljud · 1 kredit / Ljud som redan finns · 0 / Upprepa samma text · 0 / Prov som andra har delat eller publicerat · 0 | 1 character of new sound · 1 credit / Sound that already exists · 0 / Repeating the same text · 0 / Quizzes others shared or published · 0 |
| Footnote | Du får 1 500 krediter varje månad. Nya krediter den 1 {december}. Oanvända krediter sparas inte. | You get 1,500 credits every month. New credits on {December} 1. Unused credits don't carry over. |
| With pass | Veckokort · till {24 nov} · {16 200} av 20 000 tecken kvar i veckan · Hantera veckokortet · Förnyas automatiskt den {24 nov} för {79 kr}. | Weekly pass · until {Nov 24} · {16,200} of 20,000 characters left this week · Manage weekly pass · Renews automatically on {Nov 24} for {price}. |
| Cost row with pass | Ingår | Included |
| Weekly limit reached | Veckans tak är nått · Fyll på | This week's limit is reached · Top up |
| No products | Paketen kunde inte hämtas från App Store just nu. · Försök igen | Packs couldn't be loaded from the App Store right now. · Try again |
| Purchase failed | Köpet gick inte igenom. Inget har dragits. | The purchase didn't go through. You weren't charged. |
| Bought, offline | Köpet är gjort. Krediterna kommer när EarMind har kontakt igen. | Purchase complete. Your credits arrive when EarMind is back online. |
| Ask to Buy | Köpet väntar på godkännande. Krediterna kommer när det är godkänt. | The purchase is waiting for approval. Your credits arrive once it's approved. |
| Restore, none | Det fanns inga köp att hämta. | No purchases to restore. |
| Restore failed | Det gick inte att hämta köpen just nu. Försök igen om en stund. | Couldn't restore purchases right now. Try again in a moment. |
| New quiz, none fits | Ett prov med 3 frågor kostar cirka {2,0k} krediter. Du har {1,5k}. · Fyll på | A quiz with 3 questions costs about {2.0k} credits. You have {1.5k}. · Top up |
| New quiz, some fit | Krediterna räcker till {5} frågor. · Fyll på · Skapa {5} frågor | Your credits cover {5} questions. · Top up · Create {5} questions |
| Under disabled button | Krediterna räcker inte till ett prov. | Not enough credits for a quiz. |
| Web beta (no purchases, D249) | Köp kommer i iOS-appen. | Purchases come with the iOS app. |

## 5. Search tone, sharing, privacy (sag-i-airpods.md, texter-integritet.md)
Sharing texts are in `texter-integritet.md` (Swedish and English, already in the app).

## 6. App Store
English listing texts: `docs/appstore/granskning.md` §1 English and §3 (review notes). When English becomes the
primary language (D251), the English subtitle is **"Study by listening in earbuds"** (29).

## 7. Svar på A157 (Angela Fable, 2026-11-21) – rader svenska → engelska
| Svenska | English | Kommentar |
|---|---|---|
| Standardläge | Standard mode | |
| Provläge | Quiz mode | lägena får engelska namn |
| Intervjuläge | Interview mode | |
| Rizzläge | Rizz mode | |
| Socialt läge | Social mode | |
| tryck 1 gång / 2 gånger / 3 gånger | press once / twice / three times | godkänt |
| A-svar | top-grade answer | "A-grade" är en svensk betygsskala |
| åk 6–9, gymnasiet 1–3, universitet | Year 6–9, Upper secondary 1–3, University | godkänt |
| Skapa uppläsning | Create audio | kortare och tydligare |
| Språk · Gäller appens texter och EarMinds svar. | Language · Applies to the app's texts and EarMind's answers. | godkänt |
| cirka 1 min per varv | about 1 min per round | **blandrad på Start i engelskan i dag** ("5 questions · cirka 1 min per varv") |
