# Kevin – D69, prompt caching, labbfunktioner, Oscars runda 2, D72 (2026-11-07)

Driftsatt version vid rapportens slut: **answer v46, tts v19** (Supabase-versioner, lästa med `list_edge_functions`). Alla driftsättningar gick via Actions "Deploy backend" och var gröna (sista körningen 42389417935).

## Sammanfattning

| Uppgift | Resultat | Status |
|---|---|---|
| D69 Rizzläge flirtigare, Socialt läge skämtfokuserat, kalibrering via tal | Driftsatt och provat live | **verified live** (text via servern) |
| Prompt caching | Var redan på; verifierat att andra anropet läser cache (10/10 Rizz, alla Haiku-svar) | **verified live** |
| Labbfunktioner som 410-stubbar | `evallab`, `anthtest` → 410 (de andra var redan 410) | **verified live** |
| Oscars runda 2, allvarliga fel | M04.2 klockslag och F16 internt resonemang rättade; plus två fel jag hittade under rättningen | **verified live** |
| D72 ett förslag, "ge mig fler" (max 5), intervjusvar i jag-form | Driftsatt och provat live | **verified live** |

Inget av detta är testat på iPhone eller AirPods: alla prov är text mot servern från den här datorn.

## 1. D69 (Rizzläge/Socialt läge/kalibrering)

- **Rizzläge (flirt):** varje rad flirtig, rolig och självsäker samtidigt (retsamt, komplimang med twist, självsäker inbjudan). D43-reglerna oförändrade.
- **Socialt läge:** skämt byggda på vad andra just sa (callback, observation, självironi) och en comeback. Transkriptet kan ha flera talare.
- **Kalibrering:** `social.calibrate` (≤ 300 tecken) slås ihop med `social.calibration` på Haiku till ≤ 300 tecken och skickas tillbaka i `done.calibration`, utan förslag. `"RESET"` från modellen (t.ex. "återställ") ger `""`. En lagrad kalibrering som är längre än 300 kapas i stället för att ge 413. `social.calibration` går med i varje förslagsanrop som `<calibration>`.
- Live (före D72): flirt-raderna blev tydligt flirtigare, t.ex. "Jag peppar från sidan och du bjuder på kaffe efteråt." och "Då behöver du en privatlärare. Jag kan ta jobbet." Socialt läge: "Armhävning är bara en planka som ångrar sig.", "Jag trodde du hade årskort, inte hyreskontrakt." Kalibrering: "lite mindre kaxig" → `mindre kaxig; lugnare ton`, sedan "mer skämt, hon gillar fotboll" → `mindre kaxig; lugnare ton; fler skämt; hon gillar fotboll`, och nästa flirtförslag använde fotboll ("Martin med te? Det är som en målvakt utan handskar."). Kalibreringsanropet tar 1,2–1,4 s och kostar 0,006 US cent. **verified live**
- Bedömningen av hur roliga eller flirtiga raderna är är min egen, ingen domare.

## 2. Prompt caching

`cache_control` på den statiska systemprompten fanns redan (`cacheSystem: true`). Live: första anropet per stil skriver cachen (`cache_write` ~2 200 tokens), alla följande läser den (`cache_read` 1 957–2 424 tokens på Sonnet, 2 766–2 798 på Haiku). Deangelos nollor var troligen första anropet per stil eller anrop med mer än 5 minuters mellanrum (cachen lever 5 minuter). **verified live**

Kostnad per anrop, uppmätt (`est_cost_usd`):

| Väg | Utan cache (kallt) | Med cache | Skillnad |
|---|---:|---:|---:|
| Rizz/Socialt (Sonnet, ~2 300 in) | 0,64–0,72 cent | 0,17–0,20 cent | ca −72 % |
| Vanligt svar (Haiku, ~2 850 in) | ca 0,037 cent (räknat) / 0,039 kallt | 0,011 cent | ca −70 % |

`done.usage.cache_write_tokens` är nytt, så det syns när ett anrop skrev cachen.

## 3. Labbfunktioner

`evallab` och `anthtest` (nyckelskyddade, kunde göra modellanrop på ägarens nyckel) är nu 410-stubbar i `backend/supabase/functions/` och driftsätts av arbetsflödet (`--no-verify-jwt`, ingen nyckel, inget anrop). Röktestet i arbetsflödet kontrollerar 410. `bench`, `ttsab`, `probe`, `rizzlab`, `ctxlab`, `ctxlab2` var redan 410 (kontrollerat live). Jag ändrade `.github/workflows/deploy-backend.yml` för detta (utanför `backend/`, men det är backendens arbetsflöde). **verified live**

## 4. Oscars runda 2 (`reports/qa/2026-11-07-1500-oscar-round2.md`)

- **M04.2 "17.40" lästes "sjutton komma fyra noll".** Orsak: strömmen skickade "klockan " i en bit och "17.40" i nästa, så klockregeln såg aldrig ordet. Nu används texten som redan lästs som kontext; "klockan 17,40" räknas också. Test i alla bitstorlekar 1–40. Live: "Ditt tåg går klockan sjutton och fyrtio idag, lördag den sju november." **verified live**
- **F16 internt resonemang uppläst.** Meningar som berättar om sökbeslutet ("utan sökning", "jag söker", "jag har inte sökt", "om du vill vara helt säker", "Hmm") tas bort. Filtren gäller nu också när webbtaket stängt av sökningen (det var så meningen slapp igenom). Prompten säger att sökning aldrig ska nämnas.
- **Hittat under rättningen, samma fråga:** F16 gav **fel kung** (Oscar I) i två av mina körningar, och läckte en engelsk halvmening ("Succeeding rulers were his son …"). Åtgärder: ordningstalsfrågor tvingar nu en webbsökning (`tool_choice: any`; om modellen inte tar emot det skickas anropet om utan), får en kodnotis om att räkna upp listan först, och en mening med en engelsk följd på minst 3 av 5 ord utan svenska småord tas bort. En ensam källrad utan svar läses inte upp (då blir det `empty_answer` och appen faller tillbaka). Live efter rättningen: Bernadotte → "Karl den femtonde" (rätt), andra statsministern → "Arvid Posse" (rätt), femte presidenten → "James Monroe" (rätt). Varje sådan fråga kostar nu ca 1 cent (sökningen) och tar 2,2–3,4 s till första ord. **verified live**, 3 frågor, inte ett större set.
- **Regentnummer i strömmen:** "Karl " och "XV" i olika bitar blev "Karl XV" i talet. Strömmen håller nu kvar ett versalt ord tills nästa ord kommit. Test i alla bitstorlekar. **verified in unit tests**, i live-svaren syns "Karl den femtonde".
- Övriga punkter i Oscars lista (E01.4 Provläget utan fråga, platshållare i Intervjuläget, x i ekvationer, pq-formeln, grammatik) är inte rättade, utom platshållarna i Intervjuläget som försvinner med D72.

## 5. D72

- **Ett förslag:** `suggestions` innehåller exakt ett förslag. Modellen skriver två rader (den bästa och en reserv), strömmen stoppas så fort första godkända raden är klar, och bara den skickas. Reserven används om första raden filtreras bort. En rad på 11–14 ord används hellre än reservfrasen "Berätta mer om det." (hårda regler för innehåll gäller fortfarande).
- **"Ge mig fler":** via `social.calibrate`. "ge mig tre pickup lines", "ge mig fem skämt", "visa fler" (= 3), "ge mig tio" (= 5, taket), "nästa" / "ge mig en till" (= ett nytt). Bara för det anropet; `done.calibration` är `null` och kalibreringen ändras inte. "fler skämt" eller "mer skämt" utan verb är fortfarande en kalibrering.
- **Intervjuläget:** svaret är det perfekta svaret i jag-form, redo att sägas högt, utan inledning, struktur, feedback, frågor tillbaka eller sammanfattning. Beteendefrågor som en kort berättelse (STAR utan att säga det). `turn: user_answer` ger den bästa versionen av användarens eget svar. Feedback bara på uttrycklig begäran ("ge mig feedback", "hur var mitt svar"). Sammanfattning på "klar", "avsluta", "sammanfatta" (enligt D72 punkt 4 i DECISIONS; Deangelos uppdrag sa "bara om användaren uttryckligen ber om det", och DECISIONS räknar "klar" som det).
- **Live (verified live):**

| Prov | Första rad / text | Resultat |
|---|---:|---|
| Socialt, standard (kallt) | 1,7 s | 1 förslag: "Fönsterbrädan är ju brottsplatsens bästa alibi." |
| Socialt, standard (varm) | 1,0 s, hela listan samtidigt | "Martin på te är början. Nästa vecka läser han poesi." |
| Flirt, standard, gym ×2 | 1,6–2,4 s | "Jag kan coacha dig, men du bjuder på kaffe efteråt." / "Jag kan vara din tränare, men du får bjuda på kaffe." |
| Flirt "ge mig tre pickup lines" | 1,2 s första, 1,9 s alla | 3 förslag |
| Socialt "ge mig fem skämt" | 1,1 s första, 2,3 s alla | 5 förslag |
| Socialt "nästa" | 2,1 s | 1 nytt förslag |
| Intervju "berätta om en gång du löste en konflikt" (barnskötare) | 0,7 s | jag-form, berättelse, ingen inledning |
| Intervju "vad är din största svaghet" + eget svar | 0,9–2,0 s | jag-form; eget svar blev en starkare version |
| Intervju "har du några frågor till oss" | 0,7 s | två frågor till intervjuaren |
| Intervju "klar" | 0,8 s | sammanfattning i fem meningar |

  Med ett förslag kommer listan samtidigt som första raden. Före D72 kom första raden vid 1,1–1,4 s och listan vid ~2,4 s. Kalla anrop (ny prompt eller 5 minuter utan anrop) tar 1,7–2,5 s.
- **Kostnad:** Rizz med ett förslag 0,09–0,13 cent varmt (före: 0,17–0,20). Intervjusvar 0,01–0,04 cent.

## Tester

- Enhetstester: alla `answer`-tester körs i Actions före varje driftsättning (gröna). Lokalt finns ingen Deno; jag körde testfilerna i Node 24 med en liten shim för `Deno.test` och `@std/assert` (161 gröna i `answer/`; shimmen typkontrollerar inte, det gör Actions).
- Nya tester: kalibrering, comeback-regeln (D69), antal förslag och "ge mig fler"/"nästa", reservrad och mjukt ordtak, intervjuplaner och prompt, klockslag och regentnummer i strömmen, sökberättelser, engelska fragment, `tool_choice` med omförsök, ensam källrad.
- Live-eval: nya fall `rizz-10`–`rizz-15` (kalibrering, återställ, 3/5/1/nästa) och `intervju-01`–`04`. **Ingen stor eval-omgång kördes efter D72** (uppdraget: bara små tester). Den nattliga körningen 2026-11-07 (efter D69) fick 503 på rizz-10–13 när krediterna tog slut.
- **Kostnad för mina livetester:** D69/caching-mätningar ca 0,10 USD, nattlig eval (som jag startade) 0,097 USD, D72 och rättningar ca 0,12 USD. **Totalt ca 0,32 USD.**

## Kända problem och risker

- Flirtförslagen upprepar samma idé ("du bjuder på kaffe") i flera scenarier. Ingen domare har bedömt D69/D72-raderna, bara jag.
- En gång gav flirt+gym reservfrasen "Berätta mer om det." (före reservraden). Efter rättningen 0 av 2. Ett större prov behövs.
- Kalla anrop till Rizz tar upp till 2,5 s; cachen lever 5 minuter.
- Ordningstalsfrågor kostar nu en sökning (1 cent) och 2–3,5 s. Webbtaket är 3 per minut och 20 per dag per användare.
- Live-evalens enhetstest (`scripts/test_live_eval.py`) går inte att köra här (tidszonsdata saknas i Windows-Python); Actions kör det.
- "Du har en bra start" i intervjusammanfattningen bryter regeln om att inte börja med beröm.

## Concerns

- Intervjuläget skriver nu färdiga svar i jag-form och hittar på ett allmänt exempel när användaren inte gett något (utan namn och siffror). Det är bra för träning men samma svar kan läsas upp i en riktig intervju. Startskärmen säger att läget är för träning (D72 punkt 4). Jag har inte byggt något som döljer appen.

## Nästa steg

1. Oscar: snabbtest på answer v46, särskilt Rizz/Socialt (1 förslag), "ge mig fler", Intervjuläget och F16/M04.2.
2. Angela: appen ska visa och läsa ett förslag, skicka "ge mig tre …" och "nästa" som `social.calibrate`, och lagra `done.calibration` bara när den inte är `null`.
3. Kevin: Oscars övriga punkter (E01.4 Provläget, x i ekvationer, pq-formeln), en större Rizz-mätning med domare när budgeten tillåter.
