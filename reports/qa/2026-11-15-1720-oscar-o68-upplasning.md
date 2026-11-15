# O68: vad som låter konstigt, kontrollerat på uppläsningstexten – Oscar (moln), 2026-11-15 17:20

Status för varje påstående: **verifierat live** (driftsatt server via testkonton i GitHub Actions och `drill_audio_files.text` via Supabase MCP), **verifierat i kod** (serverns egen `longVoice`/`voiceText` från main, buntad med esbuild) eller **antagande, ej testat**. Det är uppläsningstexten, inte ljudet. Ingen app eller enhet.

**D180 (verifierat live):** 178 nya ljudrader 15:59–16:04 UTC, alla med `earmind-test-silent` och 0 krediter. Claude 0,49 USD (taket 0,5).

## Kort
1. **De genererade svaren är rena (verifierat live).** 96 långa svar ur 9 holdout-prov gav 0 förkortningar, enheter, symboler, parenteser, listor och siffror kvar i uppläsningstexten. Proven var svenska (12 svar), engelska (24), matte (18) och NO (fysik 22, kemi 10, biologi 10). Det enda fyndet är **13 meningar över 30 ord** i 11 svar, längst 37 ord, och 8 av dem är engelska. Gårdagens 199 holdout-svar (O63–O65) och de 162 importfallen i `testdata/import/o58-cases.json` är också rena, så när som på 10 långa meningar och 3 listor (verifierat i kod). Modellen skriver redan talspråk ("fem kilogram", "a i kvadrat").
2. **Analysen stämmer med servern:** 94 av 96 texter är identiska med `drill_audio_files.text` (md5). De två som skiljer sig är svar där servern satte kortsvaret först (D145).
3. **Det konstiga uppstår när eleven redigerar eller importerar text** (D190: svaren går att redigera före Starta prov). Jag skrev 20 påhittade svar som en elev eller ChatGPT kunde skriva. 14 av dem har något som läses fel, och 10 av de 15 värsta kommer därifrån. Det är där K74:s regler behövs. **Antagande, ej testat:** att det är det Aron hör. Han kan också ha hört svar i lyssnarläget (`/answer` → `/tts`, som bara gör `pronounce`), eller engelska svar som ElevenLabs får med `language_code: "sv"` (Kevin K72). Inget av det går att höra med testljud.

## Underlag
- `scripts/qa/o68_fixture.json`: 96 långa svar ur holdout-proven h2-sv-argumentera, h3-en-climate, h4-en-lighthouse, o57-ma-procent, h3-ma-pythagoras, ho-fy1-newton, h4-fy-hastighet, h3-ke-atomer och ho-bio-ak9-blodet. Gjorda på appens väg (exam drill + drill_answers) 15:59–16:03 UTC.
- `scripts/qa/o68_edited.json`: 20 redigerade eller importerade svar (påhittade, inga riktiga användares ord).
- `scripts/qa/o68_analyze.mjs`: räknar förkortningar, enheter efter tal, symboler, parenteser, listor, siffror (svenska), meningar över 30 ord, versalförkortningar och kemiska formler.
- Körning: `oscar-live.yml` → `o68_voice.py` (run 1 gör svaren). Svaren och analysen sparas på grenen `oscar/qa-data` (`o68/`).

## Per kategori
| Kategori | 96 holdout-svar | 20 redigerade svar |
|---|---|---|
| förkortningar (t.ex. kvar, enl., kap., fig., milj., ggr, e.g., i.e., a.m., Sthlm) | 0 | 9 |
| enheter efter tal (N, K) | 0 | 2 |
| symboler (→ ~ ° < > &) | 0 | 4 |
| parenteser | 0 | 6 |
| listor (; och 1) 2)) | 0 | 2 |
| siffror kvar (svenska) | 0 | 0 |
| meningar över 30 ord | 11 svar (13 meningar) | 1 |
| uttal (CO2, CH4, SD, kemiska formler) | 0 | 5 |

Fler fall som analysen inte räknar men som jag såg i texten (verifierat i kod):
- "w/ a lamp" blir "w divided by a lamp".
- "CH4 + 2 O2 → CO2 + 2 H2O" blir "se ha fyra plus två o två ger se o två plus två ha två o".
- "28/6 1914" blir "tjugoåttonde juni nittonhundrafjorton" (rätt).
- "1) … 2) …" blir "ett) … två)".
- I engelska svar lämnas "30 m", "20+ km", "~1.2 °C", "5 sec", "100 ft" och "(12 yrs old)" som de står.

## De 15 värsta (exakt text)
**1. redigerat edit-17 (Engelska), poäng 22** – abbr: e.g.; symbol: →, ~, °; paren: ( ); pronounce: CO2, CH4, formel CO2, formel CH4
   - Fråga: What does the greenhouse effect mean?
   - Skrivet: `It means that gases trap heat. CO2 and CH4 (methane) act like glass, e.g. in a greenhouse → the Earth gets ~1.2 °C warmer.`
   - Rösten får: `It means that gases trap heat. CO2 and CH4 (methane) act like glass, e.g. in a greenhouse → the Earth gets ~1.2 °C warmer.`
**2. redigerat edit-01 (Fysik), poäng 15** – abbr: Enl., kap., fig.; unit: N; paren: ( ); long_sentence: 1 st
   - Fråga: Vad säger Newtons andra lag?
   - Skrivet: `Kraften är massan gånger accelerationen. Enl. kap. 4 skrivs det F = m · a, t.ex. ger 5 kg och 2 m/s² en kraft på 10 N (se fig. 3).`
   - Rösten får: `Kraften är massan gånger accelerationen. Enl. kap. fyra skrivs det F är lika med m gånger a, till exempel ger fem kilogram och två meter per sekund i kvadrat en kraft på tio N (se fig. tre).`
**3. redigerat edit-18 (Engelska), poäng 12** – abbr: ft, i.e., sec; symbol: &
   - Fråga: How tall is the lighthouse?
   - Skrivet: `It is about 30 m tall. That is roughly 100 ft, i.e. a ten-storey building, and the light can be seen 20+ km away & it flashes every 5 sec.`
   - Rösten får: `It is about 30 m tall. That is roughly 100 ft, i.e. a ten-storey building, and the light can be seen 20+ km away & it flashes every 5 sec.`
**4. redigerat edit-10 (Fysik), poäng 11** – abbr: milj.; unit: K; symbol: ~, °
   - Fråga: Vad är temperaturen på solens yta?
   - Skrivet: `Den är ungefär 5 500 °C. Det motsvarar ca 5 800 K, och i kärnan är det ~15 milj. °C.`
   - Rösten får: `Den är ungefär femtusen femhundra grader celsius. Det motsvarar cirka femtusen åttahundra K, och i kärnan är det ~femton milj. °C.`
**5. redigerat edit-11 (Geografi), poäng 9** – abbr: Ca, Sthlm, Gbg
   - Fråga: Hur stor är Sveriges befolkning?
   - Skrivet: `Sverige har drygt 10,5 miljoner invånare. Ca 85 % bor i tätorter, främst i Sthlm, Gbg och Malmö.`
   - Rösten får: `Sverige har drygt tio komma fem miljoner invånare. Ca åttiofem procent bor i tätorter, främst i Sthlm, Gbg och Malmö.`
**6. redigerat edit-03 (Kemi), poäng 8** – paren: ( ); pronounce: formel CH4, formel O2, formel CO2
   - Fråga: Vad bildas när metan brinner?
   - Skrivet: `Det bildas koldioxid och vatten. Formeln är CH4 + 2 O2 → CO2 + 2 H2O, och reaktionen avger energi (exoterm).`
   - Rösten får: `Det bildas koldioxid och vatten. Formeln är se ha fyra plus två o två ger se o två plus två ha två o, och reaktionen avger energi (exoterm).`
**7. redigerat edit-04 (Kemi), poäng 8** – symbol: <, >; list: ;
   - Fråga: Vad är pH?
   - Skrivet: `pH är ett mått på hur surt något är. Skalan går från 0–14; pH < 7 är surt, pH = 7 neutralt och pH > 7 basiskt.`
   - Rösten får: `pH är ett mått på hur surt något är. Skalan går från noll till fjorton; pH < sju är surt, pH är lika med sju neutralt och pH > sju basiskt.`
**8. redigerat edit-14 (Samhällskunskap), poäng 6** – paren: ( ); list: ;; pronounce: SD
   - Fråga: Hur många ledamöter har riksdagen?
   - Skrivet: `Riksdagen har 349 ledamöter. Partierna måste få minst 4 % av rösterna; S, M och SD är störst (2022).`
   - Rösten får: `Riksdagen har trehundrafyrtionio ledamöter. Partierna måste få minst fyra procent av rösterna; S, M och SD är störst (tvåtusen tjugotvå).`
**9. redigerat edit-15 (Svenska), poäng 5** – abbr: Ex:; paren: ( )
   - Fråga: Vad är ett argument?
   - Skrivet: `Ett argument är ett skäl för en åsikt. Ex: "Skolan borde börja senare" – argument: 1) tonåringar sover mer, 2) de lär sig bättre.`
   - Rösten får: `Ett argument är ett skäl för en åsikt. Ex: "Skolan borde börja senare" – argument: ett) tonåringar sover mer, två) de lär sig bättre.`
**10. redigerat edit-05 (Biologi), poäng 4** – paren: ( ); pronounce: formel O2
   - Fråga: Vad gör de röda blodkropparna?
   - Skrivet: `De transporterar syre. Hemoglobinet (Hb) binder O2 i lungorna och lämnar det i vävnaderna, bl.a. i musklerna.`
   - Rösten får: `De transporterar syre. Hemoglobinet (Hb) binder o två i lungorna och lämnar det i vävnaderna, bland annat i musklerna.`
**11. holdout h3-en-climate (Engelska), poäng 4** – long_sentence: 2 st
   - Fråga: Why does burning coal, oil and gas make the temperature rise more?
   - Skrivet: `Burning coal, oil and gas releases more carbon dioxide into the air, and since this gas traps heat, a larger amount of it means more heat is held in the atmosphere. So there is a clear chain of cause and effect: we burn fossil fuels for electricity, heating and transport, carbon dioxide is released, the greenhouse effect gets stronger, and the Earth becomes warmer. This is why cutting emissions, for example by travelling by train instead of flying, can help slow down the warming.`
   - Rösten får: `Burning coal, oil and gas releases more carbon dioxide into the air, and since this gas traps heat, a larger amount of it means more heat is held in the atmosphere. So there is a clear chain of cause and effect: we burn fossil fuels for electricity, heating and transport, carbon dioxide is released, the greenhouse effect gets stronger, and the Earth becomes warmer. This is why cutting emissions, for example by travelling by train instead of flying, can help slow down the warming.`
**12. holdout h3-ma-pythagoras (Matematik), poäng 4** – long_sentence: 2 st
   - Fråga: Vad säger Pythagoras sats?
   - Skrivet: `Pythagoras sats säger att i en rätvinklig triangel är summan av kateternas kvadrater lika med hypotenusans kvadrat, alltså a i kvadrat plus b i kvadrat är lika med c i kvadrat. Här är a och b kateterna och c hypotenusan. Satsen gäller bara i rätvinkliga trianglar. Den kan också användas åt andra hållet: om a i kvadrat plus b i kvadrat är lika med c i kvadrat för en triangel, så vet man att triangeln är rätvinklig. Man kan även räkna ut en katet om man känner hypotenusan och den andra kateten, då är a i kvadrat lika med c i kvadrat minus b i kvadrat.`
   - Rösten får: `Pythagoras sats säger att i en rätvinklig triangel är summan av kateternas kvadrater lika med hypotenusans kvadrat, alltså a i kvadrat plus b i kvadrat är lika med c i kvadrat. Här är a och b kateterna och c hypotenusan. Satsen gäller bara i rätvinkliga trianglar. Den kan också användas åt andra hållet: om a i kvadrat plus b i kvadrat är lika med c i kvadrat för en triangel, så vet man att triangeln är rätvinklig. Man kan även räkna ut en katet om man känner hypotenusan och den andra kateten, då är a i kvadrat lika med c i kvadrat minus b i kvadrat.`
**13. redigerat edit-02 (Fysik), poäng 3** – abbr: ggr
   - Fråga: Hur snabbt går ljudet?
   - Skrivet: `Ljudet går ca 340 m/s i luft. I vatten går det ungefär 4 ggr snabbare, dvs. ca 1 500 m/s.`
   - Rösten får: `Ljudet går cirka trehundrafyrtio meter per sekund i luft. I vatten går det ungefär fyra ggr snabbare, det vill säga cirka femtonhundra meter per sekund.`
**14. redigerat edit-13 (Historia), poäng 3** – abbr: milj.
   - Fråga: Vad hände 1914–1918?
   - Skrivet: `Då pågick första världskriget. Det började efter mordet i Sarajevo 28/6 1914, och ca 17 milj. människor dog.`
   - Rösten får: `Då pågick första världskriget. Det började efter mordet i Sarajevo tjugoåttonde juni nittonhundrafjorton, och cirka sjutton milj. människor dog.`
**15. redigerat edit-19 (Engelska), poäng 3** – abbr: a.m.
   - Fråga: Who was Thomas?
   - Skrivet: `Thomas was the keeper's grandson. He climbed the 154 steps w/ a lamp at 3 a.m.`
   - Rösten får: `Thomas was the keeper's grandson. He climbed the 154 steps w divided by a lamp at 3 a.m.`

## Till Kevin (K74, pågår)
Underlaget är `scripts/qa/o68_edited.json` och `o68_fixture.json`. Det som K74 punkt 1 bör täcka, med fallen ovan:
- **Förkortningar** som står kvar: enl., kap. (blir "kap. fyra"), fig., milj., ggr, Ex:, Sthlm, Gbg, Ca med stor bokstav först i meningen. På engelska: e.g., i.e., a.m., ft, sec, yrs och w/ (blir "w divided by").
- **Parenteser** står kvar: "(se fig. tre)", "(tvåtusen tjugotvå)", "(exoterm)", "(Hb)" och "(methane)".
- **Symboler:** < och > (pH < sju), ~, & och → på engelska, och °C på engelska.
- **Enheter efter tal:** "tio N", "femtusen åttahundra K". På engelska: "30 m", "20+ km".
- **Kemiska formler:** "se o två", "ha två o" och "o två". Skriv "koldioxid" eller läs bokstav för bokstav med paus, och svara hellre i ord.
- **Listor:** "ett) … två)" och semikolon.
- **Meningar över 30 ord:** 13 i de genererade svaren, varav 8 engelska.

Kravet för omtestet: 0 kvar i de kategorier K74 täcker, i båda fixturerna. Jag kör `o68_voice.py --fixture=…` och analysen när K74 är driftsatt (0 Claude).

## Kvar
- Omtest efter K74 (samma 96 + 20 svar).
- Det som bara hörs med riktigt ljud bedömer Aron på telefonen (D180): engelska med `language_code: "sv"`, och betoning.
