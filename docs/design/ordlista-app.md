# Ordlista för appen – engelska först (Kelly (moln), Ke91, 2026-11-27)

Genomgång av appens 1 728 texter (`Lumen/Resources/Localizable.xcstrings`, engelska och svenska), kopplade till de
Swift-filer som visar dem, och av bilderna från A164–A166 och Ke90. Måttstock: **kort, tydlig, samma ord som sajten och
App Store-sidan.** Engelska är amerikansk (App Store-sidan är English (U.S.), Ke90). Kelly ändrar ingen appkod; Angela
Fable äger repetitionsvyerna, Angela Schrute resten (lyssnandet, Inställningar, första starten, kommandona).

## 1. Ett ord per sak
| Sak | English | Svenska | Inte |
|---|---|---|---|
| Appens namn | EarMind | EarMind | Lumen (bara som väckningsord, se 2.2) |
| Det man övar på | quiz | prov | exam, test, set, mini test |
| Det som skapas av texten | **audio** | ljud | sound (blandas i dag: 55 sound, 33 audio) |
| Att skapa något | **Create** (Create questions, Create audio) | Skapa / Gör | Make (blandas i dag) |
| Tryck på AirPods | **press** (Apples ord) | tryck | tap (tap = på skärmen) |
| Öva | **practice** (amerikansk stavning) | öva | practise |
| Märkning | **Beta** | Beta | BETA |
| Krediter | credits · Top up · Weekly pass | krediter · Fyll på · Veckokort | questions left (gamla enheten, se 2.5) |
| Uppspelning | Say in AirPods · Play for 10 min · Playing in AirPods | Säg i AirPods · Spela i 10 min · Spelar i AirPods | – |
| Egna inspelningar | Record it yourself · Completely free | Spela in själv · Helt gratis | – |
| Lägena som lyssnar | More modes (Beta) | Fler lägen (Beta) | Listening modes, Voice quizzing (BETA) |
| Hastighet | **Speed** | Tempo | Tempo (på engelska låter det som musik) |

## 2. De tio viktigaste (nuvarande → förslag)
1. **Röstkommandona är på svenska i den engelska appen** (25 texter, Angela Schrute): ". Answer out loud, or say
   nästa." · "Or say ja or nej." · "Or say “Lumen, förhör mig”." · "Say ja for more" · "Tap Listen again or say “Lumen,
   fortsätt”" · "”Lumen, jag har prov i engelska på onsdag”". → Visa de **engelska** orden när appen är på engelska
   ("say next", "say yes or no", "“Lumen, quiz me”", "“Lumen, continue”", "“Lumen, I have an English test on
   Wednesday”") och låt kommandona förstå båda språken. Går det inte nu: dölj kommandoraderna på engelska hellre än att
   visa svenska ord.
2. **"Lumen" står i 32 engelska texter** där appen menas ("Lumen never saves anything …", "Say the keyword in a question
   and Lumen follows …"). → **EarMind** överallt där appen menas. Där väckningsordet menas, säg det en gång: "Start with
   “Lumen” (EarMind's wake word)". (Angela Schrute)
3. **"EarMind can do anything"** (HomeView, två texter) lovar för mycket. → "Ask EarMind anything. Say “Lumen” and what
   you want, for example:" (Angela Schrute)
4. **sound → audio** i allt som rör uppläsningen (Angela Fable): "Making the sound …" → "Creating audio …" · "Sound: 4 of
   6 ready" → "Audio: 4 of 6 ready" · "The sound is made when you start" → "The audio is created when you start" ·
   "Previews are free. A new voice means new sound." → "Previews are free. A new voice means new audio." · "1 character
   of new sound" → "1 character of new audio". (App Store-texten säger redan audio; sajten är rättad i Ke91.)
   **Undantag:** "The sound stays on your phone" för egna inspelningar får stå (det är din röst, inte skapat ljud).
5. **Två enheter syns** (Angela Fable): "questions left this month", "No questions left until %@ 1.", "The text counts as
   one question per started 800 characters", "Counts as %lld of your %lld questions left." står kvar bredvid
   krediterna. → När kontot räknar tecken (D213) ska bara krediter synas: "Not enough credits. You have %@." ·
   "Credits refill on %@ 1." Ta bort raderna om frågor per 800 tecken.
6. **Kostnadsraderna säger samma sak på fyra sätt** (Angela Fable): "Counts as %@. Repeats are free." · "Costs %@" · "The
   text counts as %@, and you have %lld left." · "Counts as %lld of your %lld when you start". → **"Costs %@ credits.
   Repeats are free."** och, när det inte räcker, **"Costs %@ credits · you have %@"** (som på webben, D249).
7. **Make/Create blandas** (Angela Fable): "Make" (valet) · "Make questions" · "Create questions" · "Create audio" · "Make
   with ChatGPT" · "%@ quiz". → **Create**: "Create" · "Create questions" · "Create audio" · "Create with ChatGPT".
   Svenska oförändrat ("Gör" / "Skapa uppläsning").
8. **Stavning och skrivsätt** (båda): "To practise" · "Practise with %lld flip cards" · "Shows what you know and what you
   should practise" → **practice**. "BETA" (4 texter, t.ex. "Voice quizzing (BETA)", "They are in BETA") → **Beta**.
   "Privacy & consent" → **Privacy and consent** (står båda). "THE PRACTICE PAPER" → **Practice paper**. "Mini test, 5
   questions" → **Mini quiz, 5 questions**.
9. **Fota-raderna** (båda): Välkommen "Photograph the material" · Home "Photograph the page you're studying" · "Photograph
   your material. EarMind makes questions …" → **"Snap your textbook"** (sajten och App Store-bild 6), och i undertexten
   "Take photos" som knappen. "%@ has no text that can be read. Photograph the pages instead." → "… Take photos of the
   pages instead."
10. **Tempo → Speed** (Angela Fable, Säg-kortet och Inställningar): "Tempo" · "Tempo, %@" · "Tempo, normal" → "Speed" ·
    "Speed, %@" · "Speed, normal". Svenska "Tempo" står kvar.

## 3. Per skärm (nuvarande → förslag)
### Första starten och Välkommen (Angela Schrute)
| Nuvarande | Förslag |
|---|---|
| Study without your phone · Your phone can stay in your pocket. | Ask out loud · The answer comes in your ear. The next screen asks first. (beslutat Ke90; fickan är inte provad, D209) |
| Photograph the material | Snap your textbook |
| Got a quiz coming up? | står (bra) |
| No account. Try now means you accept the points above. | No account needed. Tapping Try now means you accept the points above. |
| The text is sent … Without a connection there are no answers. | … If the server can't answer, the phone's own model answers where it's available, and then the text stays on your phone. (beslutat Ke90) |
| Privacy & consent / Privacy and consent | Privacy and consent |

### Start (Angela Fable)
| Nuvarande | Förslag |
|---|---|
| Come prepared to the quiz | Be ready for your quiz |
| %@ · Counts as %lld of your %lld when you start | %@ · Uses %lld of your %lld credits when you start |
| %@ · The sound is fetched when you start | %@ · The audio downloads when you start |
| %@ · The sound is made when you start | %@ · The audio is created when you start |
| Opens the set | Opens the quiz |
| BETA · Beta, in development · Beta · uses the microphone | Beta (en form) · "Beta · uses the microphone" står |
| These modes listen to what you say. They are in BETA and keep getting better. | These modes listen to what you say. They're in beta and keep getting better. |

### Säg i AirPods (Angela Fable)
| Nuvarande | Förslag |
|---|---|
| Counts as %@. Repeats are free. / Costs %@ | Costs %@ credits. Repeats are free. |
| %@, not enough credits / %@ · you have %@ | Costs %@ credits · you have %@ |
| Making the sound … | Creating audio … |
| Tempo | Speed |
| Shorten the text or wait until %@ 1. | Shorten the text, or wait until %@ 1 when credits refill. |
| You can lock your phone. You'll still hear it in your AirPods. | **Sanningsfråga, inte ord:** inte provat på telefon (D209, TILL-ARON #29). Visa först när Aron har provat. |
| To review (röstbladet, granskningsröster) | Under review |
| Swedish voices | Voices (så länge katalogen bara har svenska röster; Ke90) |

### Nytt prov (Angela Fable)
| Nuvarande | Förslag |
|---|---|
| Make · Make questions · Create questions | Create · Create questions |
| Make with ChatGPT | Create with ChatGPT |
| Quiz name · Quiz name (optional) · Quiz name, optional | Quiz name (optional) |
| Not enough credits for a quiz. / … for the quiz. | Not enough credits for this quiz. |
| Something wrong? Write it | Something wrong? Tell us |
| The text counts as one question per started 800 characters, about a third of a book page. | ta bort (krediter, punkt 5) |
| You have no questions left this month. You can make new questions from %@ 1. | You're out of credits. They refill on %@ 1. |
| It takes about a minute. You can leave the app. | står (bra) |

### Provet och spelaren (Angela Fable)
| Nuvarande | Förslag |
|---|---|
| Press your AirPods for the answer | står (rätt ord) |
| The first sentence becomes the short answer (2 presses). The whole answer is the long one (1 press). | står |
| Sound: %lld of %lld ready. The rest is made on %@ 1, when you have questions left. | Audio: %lld of %lld ready. The rest is created when you have credits. |
| Counts as %lld of your %lld questions left. | Uses %lld of your %lld credits. |
| If you save a change, new sound is made only for this question. | If you save a change, only this question gets new audio. |
| Get others' quizzes | Find quizzes from your school (samma som Start) |

### Krediter och butik (Angela Fable)
| Nuvarande | Förslag |
|---|---|
| Questions left · question(s) left this month | dölj när kontot räknar tecken (punkt 5) |
| Regular question · Slightly longer question · Very long question | dölj med samma villkor |
| Shows what costs what | Shows what things cost |
| 1 per %lld characters | 1 credit per %lld characters |
| See the packs | står |
| Study with EarMind. You get 5,000 credits to start. | står, men visas bara när välkomsten är på (D239) |

### Spela in själv (Angela Fable, A165)
Orden följer `spela-in-sjalv.md`; inget att ändra. "Not recorded · read by the phone", "My questions" (D264).

### Lyssnarvyn och Fler lägen (Angela Schrute)
| Nuvarande | Förslag |
|---|---|
| . Answer out loud, or say nästa. | . Answer out loud, or say “next”. (punkt 1) |
| Or say ja or nej. / Say ja for more | Or say “yes” or “no”. / Say “yes” for more |
| Voice quizzing / Voice quizzing (BETA) | Spoken quiz (sajten: "a spoken quiz") |
| Silent quiz: answer by nodding | står |
| Wrong answer, send to the developers | Wrong answer? Send it to us |
| Test mode · audio is sent | står (bara testkonton, D227) |

### Hem (Fler lägen) (Angela Schrute)
| Nuvarande | Förslag |
|---|---|
| EarMind can do anything · EarMind can do anything. Say Lumen and what you want, for example: | Ask EarMind anything. Say “Lumen” and what you want, for example: |
| Mini test, 5 questions | Mini quiz, 5 questions |
| Practise with %lld flip cards · Practise more on | Practice with %lld flip cards · Practice more on |
| Listening modes use the microphone. Start quiz never does. | More modes use the microphone. Start quiz never does. |

### Inställningar (Angela Schrute)
| Nuvarande | Förslag |
|---|---|
| Tempo | Speed |
| Cloud speech recognition (Scribe) · Local voice detector before Scribe · Latency overlay · Mock answers (debug, no network) | Bara under Advanced/Debug och inte i Release (kontrollera; de säger inget för en elev) |
| Spotify (for testers) | dölj i Release |
| Privacy & consent | Privacy and consent |

## 4. Rättat på sajten och App Store-sidan (Ke91)
- "Tap once for the long answer …" → **"Press once …"** (sajten /, App Store-bild 7 "Press for the answer.").
- "1 credit is 1 character of new sound" → **"… of new audio"** (sajten /). App Store-texten hade redan audio.
- Svenska oförändrat ("Tryck en gång", "nytt ljud").

## 5. Hur listan togs fram
Skript (scratchpad, inte i repot): varje nyckel i String Catalog kopplad till de Swift-filer där den står (132 filer;
180 nycklar utan träff är rader som byggs i kod eller inte används), räkning av ord över alla engelska texter
(quiz 145, sound 55, audio 33, Lumen 32, BETA 4, practise 9), och genomläsning av skärmarna ovan. Inget är provat
på telefon; orden är sedda i katalogen och på Simulator-bilderna.
