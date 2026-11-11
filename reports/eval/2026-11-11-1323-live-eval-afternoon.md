# Live-eval 2026-11-11

Backend: https://xjczbzfkmbjdebwlccki.supabase.co (anonym inloggning, publik nyckel). **388 turer, 349 utan anmärkning, 39 med anmärkning.**

| Kategori | Turer | Anmärkningar | p50 första ord (ms) | p95 (ms) |
|---|---:|---:|---:|---:|
| aktuellt | 1 | 0 | 2879 | 2879 |
| appkommando | 57 | 0 | 1095 | 1682 |
| beräkning | 17 | 0 | 742 | 1190 |
| fakta | 14 | 1 | 964 | 2225 |
| felhörning | 12 | 0 | 1152 | 1664 |
| följdfråga | 42 | 2 | 932 | 1739 |
| intervju | 19 | 4 | 1093 | 1827 |
| klocka | 3 | 0 | 1183 | 2399 |
| kommando | 57 | 7 | 1576 | 3663 |
| logik | 1 | 1 | 4938 | 4938 |
| metasvar | 7 | 1 | 1052 | 1052 |
| minne | 6 | 1 | 1198 | 1399 |
| nivå | 3 | 0 | 1254 | 1395 |
| om-lumen | 3 | 0 | 201 | 227 |
| praktiskt | 8 | 4 | 2694 | 3642 |
| profil | 3 | 0 | 1552 | 1641 |
| provläge | 2 | 1 | 3406 | 3406 |
| rizz | 21 | 1 | 1309 | 3119 |
| räkna | 20 | 0 | 645 | 1613 |
| socialt | 3 | 3 | 986 | 1123 |
| symboler | 10 | 1 | 1301 | 2779 |
| texter | 4 | 3 | 4179 | 10332 |
| tid | 8 | 0 | 455 | 892 |
| tystnad | 24 | 0 | 1461 | 1809 |
| uttal | 1 | 0 | 949 | 949 |
| webb | 5 | 5 | 3285 | 3684 |
| ämne | 7 | 0 | 1263 | 1854 |
| ämnesbyte | 30 | 4 | 1005 | 2434 |

Relation (D53): 44/46 rätt av de turer där modellen angav en.

Tystnad (D75): 18/19 icke-frågor fick inget svar; 73/73 riktiga frågor besvarades.

Räkna (kod): 20/20 rätt (krav 100 %).

Uppskattad kostnad för körningen: ca 0.982 USD.

## Anmärkningar

| Typ | Antal |
|---|---:|
| långsamt | 18 |
| fråga tillbaka | 5 |
| källrad saknas | 5 |
| väntat svar saknas | 3 |
| förbjudet ord i svaret | 2 |
| påhittad personuppgift | 2 |
| kopia av tidigare svar | 1 |
| fel | 1 |
| för långt | 1 |
| förslag för långt | 1 |
| intervjusvar innehåller 'bra fråga' | 1 |
| svarade på en icke-fråga | 1 |
| inte i jag-form | 1 |

- **fakta-11** tur 1 "vad betyder ambivalent" (964 ms): väntat svar saknas (något av: motstridig, tvehågsen, blandade)  
  > Ambivalent betyder tvetydig eller tudelad: man känner eller tycker två motsatta saker samtidigt, till exempel att man både vill och inte vill åka på en resa.
- **följdfråga-01** tur 3 "kortare" (961 ms): kopia av tidigare svar  
  > Andra världskriget började främst för att Tyskland under Hitler ville ta kontroll över Europa, och Poleninvasionen den första september nittonhundratrettionio blev gnistan.
- **följdfråga-04** tur 3 "varför då?" (2585 ms): långsamt: 2585 ms till första ord (budget 2500)  
  > Växten behöver ljus för att driva reaktionerna, eftersom ljusenergin är det som gör att koldioxid och vatten kan omvandlas till socker. Koldioxiden är själva råvaran som kolet i sockret kommer ifrån, och vattnet ger väte
- **ämnesbyte-01** tur 2 "hur gör man pannkakor" (None ms): fel: {"code": "empty_answer", "message": "Model returned no answer", "fallback": true}  
  > 
- **ämnesbyte-01** tur 3 "varför då?" (1087 ms): förbjudet ord i svaret: 'strålning'  
  > Den kan skada celler därför att energin är så hög att den kan slå loss elektroner ur molekylerna i kroppen, till exempel i DNA. När DNA skadas kan cellen dö eller bli fel på sätt som i värsta fall kan leda till cancer. L
- **ämnesbyte-05** tur 3 "varför då?" (876 ms): förbjudet ord i svaret: 'växt'  
  > Paris blev huvudstad eftersom staden under medeltiden växte till Frankrikes politiska och religiösa centrum, med universitetet och kungamakten knutna dit. Under elvahundra- och tolvhundratalen gjorde kungarna staden till
- **ämnesbyte-06** tur 2 "hur byter man däck" (3922 ms): långsamt: 3922 ms till första ord (budget 2500)  
  > Kort svar: Parkera på ett plant, hårt och stabilt underlag, lägg i parkeringsbromsen och säkra bilen med hjulklossar. Lossa sedan bultarna ett kvarts varv medan hjulet fortfarande står på marken. Lyft bilen vid den angiv
- **symboler-08** tur 1 "hur lyder andragradsformeln" (2779 ms): långsamt: 2779 ms till första ord (budget 2500)  
  > Andragradsformeln för x i kvadrat plus p gånger x plus q är lika med noll är: x är lika med minus p genom två, plus minus roten ur parentesen p genom två i kvadrat, minus q.  Har ekvationen formen a x i kvadrat plus b x 
- **praktiskt-01** tur 1 "hur gör man pannkakor" (2694 ms): långsamt: 2694 ms till första ord (budget 2500)  
  > För vanliga pannkakor behövs tre deciliter vetemjöl, sex deciliter mjölk, tre ägg, en nypa salt och ungefär en matsked smält smör. Vispa mjölet med lite av mjölken till en slät smet, tillsätt ägg, salt och resten av mjöl
- **praktiskt-03** tur 1 "hur byter man däck" (3296 ms): långsamt: 3296 ms till första ord (budget 2500)  
  > Ett däckbyte görs så här: Parkera på ett plant, hårt och stabilt underlag, lägg i parkeringsbromsen, säkra bilen med hjulklossar och ta fram alla verktyg. Lossa hjulbultarna ett kvarts varv medan hjulet fortfarande står 
- **praktiskt-04** tur 1 "recept på köttbullar" (3642 ms): långsamt: 3642 ms till första ord (budget 2500); väntat svar saknas (något av: köttfärs)  
  > Ett enkelt grundrecept för fyra portioner från ICA är: en halv deciliter mjölk, en halv deciliter vispgrädde, en halv deciliter ströbröd, femhundra gram nöt- eller blandfärs, en tesked salt, ett ägg, en halv gul lök, ett
- **praktiskt-05** tur 1 "hur lagar man ris" (3149 ms): långsamt: 3149 ms till första ord (budget 2500)  
  > Så här kokar du ris enligt ICA: koka upp vatten och salt, skölj riset i kallt vatten och låt det rinna av. Häll sedan riset i kastrullen och koka på svag värme under lock enligt tiden på förpackningen. För fyra portioner
- **socialt-01** tur 1 "Kalle sa att jag är tråkig vad säger jag" (986 ms): fråga tillbaka; för långt (21 ord, max 16)  
  > Haha, då får du visa honom att du är allt annat än tråkig! Vill du ta en fika och bevisa det?
- **socialt-02** tur 1 "hon skrev hej vad svarar jag" (685 ms): fråga tillbaka  
  > Hej! Vad roligt att du hörde av dig, hur har din dag varit?
- **socialt-03** tur 1 "min kompis frågade om jag vill hänga ikväll vad säger jag" (1123 ms): fråga tillbaka  
  > Gärna! Vad har du tänkt dig?
- **rizz-05** tur 1 "(Rizz)" (2269 ms): förslag för långt: 'Den boken är tjock nog att räknas som träning. Hur långt har du kommit?'  
  > Den boken är tjock nog att räknas som träning. Hur långt har du kommit?
- **minne-01** tur 1 "vad har du gjort i sommar" (1276 ms): fråga tillbaka  
  > Jag åkte skidor, du då?
- **webb-01** tur 1 "vem vann senaste fotbolls VM" (3359 ms): källrad saknas  
  > Spanien vann senaste fotbolls-VM, som spelades tvåtusen tjugosex. Spanien har vunnit VM-guld för andra gången. Det blev en ett till noll seger mot Argentina. Ferran Torres gjorde målet i förlängningen. Källa: SVT.
- **webb-02** tur 1 "vad är vädret idag i Stockholm" (3684 ms): källrad saknas  
  > Det finns ingen tydlig dagsprognos för idag i sökresultaten, så jag kan inte säga säkert hur vädret blir i Stockholm just nu. Förmiddagen är mulen med högsta temperatur sju grader och lägsta temperatur fem grader, men de
- **webb-03** tur 1 "vem är Sveriges statsminister just nu" (3285 ms): källrad saknas  
  > Sveriges statsminister är Ulf Kristersson, Moderaterna. Sedan den sjuttonde september har Sverige en övergångsregering som leds av statsminister Ulf Kristersson. Mandatperioden för statsministerämbetet är från den artond
- **webb-04** tur 1 "nyheter om Sverige idag" (3055 ms): källrad saknas  
  > Regeringsbildningen dominerar dagens nyheter. Ulf Kristersson ska redovisa sitt sonderingsuppdrag tisdag sjuttonde november, och Socialdemokraternas Magdalena Andersson vill regera med MP och C. Dessutom väntas snöfall, 
- **webb-05** tur 1 "kolla scb.se hur många bor i Sverige" (3118 ms): källrad saknas  
  > Enligt SCB bodde det tio miljoner sexhundratiotusen femhundra personer folkbokförda i landet vid halvårsskiftet tvåtusen tjugosex. Folkmängden var tio miljoner sexhundratjugoetttusen sjuhundratjugofem i september tvåtuse
- **intervju-04** tur 2 "klar" (1386 ms): intervjusvar innehåller 'bra fråga'  
  > Du visade intresse för uppföljning av truckarbetet, särskilt säkerhet och utbildning av nya medarbetare, vilket är en bra fråga för en lagerroll. Öva gärna mer på att koppla dina svar till konkreta moment i jobbet. Tips 
- **intervju-06** tur 2 "vad har du för erfarenhet av vård" (819 ms): påhittad personuppgift: 'Jag har inte jobbat'  
  > Jag har inte jobbat med vård tidigare, men det jag tar med mig är att jag är lugn, lyhörd och tycker om att möta människor. I en situation som den jag beskrev lyssnar jag först och frågar hur personen mår, och sedan förs
- **intervju-07** tur 1 "hur gammal är du och vad pluggar du" (1717 ms): fråga tillbaka  
  > Det jag tar med mig hit är att jag är noggrann och van vid att jobba strukturerat, och jag gillar att ha många saker igång samtidigt utan att tappa koll på detaljerna. Jag ser fram emot att lära mig lagrets rutiner, att 
- **meta-01** tur 1 "Du sätter in ett i formeln, gångrar med fem och lägger till ut till tio. Gud- Om x ökar från ett till två är- Två är krympning." (1052 ms): svarade på en icke-fråga (väntade tystnad)  
  > Om x ökar från ett till två blir y lika med fem gånger två plus tio, alltså tjugo. Då har y ökat från femton till tjugo, så y växer med fem när x växer med ett. Det är just vad talet fem framför x betyder: lutningen, ell
- **cv-04** tur 1 "har du jobbat med kassa förut" (1827 ms): påhittad personuppgift: 'Jag har inte jobbat'  
  > Jag har inte jobbat med kassa tidigare, men jag är snabb med siffror och noggrann, så jag brukar räkna rätt och hålla koll på det jag gör. Jag gillar att möta folk, och jag lär mig snabbt nya system.
- **text-02** tur 1 "sjung helan går" (2576 ms): långsamt: 2576 ms till första ord (budget 2500); väntat svar saknas (något av: halvan går)  
  > Helan går sjung hopp faderallan lallan lej Helan går sjung hopp faderallan lallan lej Och den som inte helan tar han heller inte halvan får Helan går sjung hopp faderallan lallan lej
- **text-03** tur 1 "citera Strindberg om kärlek" (10332 ms): långsamt: 10332 ms till första ord (budget 2500)  
  > Jag kan inte citera det ordagrant, men Strindberg skildrar kärleken som en kraft som både lockar och förgör. I flera av sina verk, till exempel i novellsamlingen Giftas, beskriver han förhållandet mellan man och kvinna s
- **text-04** tur 1 "sjung Tattoo med Loreen" (4179 ms): långsamt: 4179 ms till första ord (budget 2500)  
  > "Tattoo" med Loreen vann Eurovision Song Contest tvåtusen tjugotre i Liverpool för Sverige, och Loreen blev därmed den första kvinnan med två segrar i tävlingen. Låten är en dramatisk electropop-ballad om en kärlek så st
- **k7-logik-01** tur 1 "Anna och Fredrik går hem till varandra, Anna går dubbelt så snabbt som Fredrik men de möttes ändå halvvägs, hur kan det komma sig" (4938 ms): långsamt: 4938 ms till första ord (budget 2500)  
  > Det kan bara hända om Fredrik gick hemifrån tidigare än Anna. Att de möttes halvvägs betyder att de gick lika långt var. Anna går dubbelt så fort, så hon behöver bara hälften så lång tid som Fredrik för samma sträcka. Fr
- **k9-harder_question-1** tur 1 "ställ en svår fråga" (3685 ms): långsamt: 3685 ms till första ord (budget 2500)  
  > Varför slutar fotosyntesen att fungera när en växt får för lite vatten, trots att det finns gott om ljus och koldioxid, och vad händer då med växtens tillväxt?
- **k9-harder_question-2** tur 1 "Lumen, en svårare fråga" (3663 ms): långsamt: 3663 ms till första ord (budget 2500)  
  > Varför är det en nackdel för växten om klyvöppningarna stänger sig en varm och torr dag, och vad händer då med fotosyntesen?
- **k9-harder_question-3** tur 1 "utmana mig" (2968 ms): långsamt: 2968 ms till första ord (budget 2500)  
  > Varför skulle en växt som får gott om ljus och vatten ändå kunna sluta producera socker om det blir för lite koldioxid, och vilken del av fotosyntesen stoppas då?
- **k9-yes_no_quiz-3** tur 1 "förhör mig med ja och nej" (3562 ms): långsamt: 3562 ms till första ord (budget 2500)  
  > Bildas det syre vid fotosyntesen?
- **k9-quiz_topic-1** tur 1 "förhör mig på cellandning" (2541 ms): långsamt: 2541 ms till första ord (budget 2500)  
  > Vilken gas tar cellerna upp, och vilken gas lämnar de ifrån sig vid cellandning?
- **k9-quiz_topic-2** tur 1 "Lumen, testa mig om klorofyll" (3176 ms): långsamt: 3176 ms till första ord (budget 2500)  
  > Vad är det i klorofyllet som gör att blad ser gröna ut, och vilken färg på ljuset tar klorofyllet inte upp?
- **k9-ih-counter_question-1** tur 1 "ge mig en motfråga" (1622 ms): inte i jag-form  
  > Hur ser ett typiskt kvällspass ut här, och hur brukar ni fördela arbetet mellan kassorna och hyllorna när det är som mest att göra?
- **k20-05** tur 1 "ge mig en svår fråga" (3406 ms): långsamt: 3406 ms till första ord (budget 2500)  
  > Varför har en växtcell både cellvägg och kloroplaster, medan en djurcell saknar dem, och vad får det för följd för hur de två celltyperna får sin energi?
