# Live-eval 2026-11-11

Backend: https://xjczbzfkmbjdebwlccki.supabase.co (anonym inloggning, publik nyckel). **388 turer, 343 utan anmärkning, 45 med anmärkning.**

| Kategori | Turer | Anmärkningar | p50 första ord (ms) | p95 (ms) |
|---|---:|---:|---:|---:|
| aktuellt | 1 | 0 | 2836 | 2836 |
| appkommando | 57 | 0 | 986 | 5932 |
| beräkning | 17 | 0 | 723 | 966 |
| fakta | 14 | 0 | 984 | 2355 |
| felhörning | 12 | 0 | 1460 | 1905 |
| följdfråga | 42 | 0 | 982 | 1588 |
| intervju | 19 | 3 | 1129 | 4028 |
| klocka | 3 | 0 | 719 | 1222 |
| kommando | 57 | 11 | 1498 | 3207 |
| logik | 1 | 1 | 4223 | 4223 |
| metasvar | 7 | 1 | 1147 | 1147 |
| minne | 6 | 1 | 870 | 901 |
| nivå | 3 | 0 | 1203 | 1485 |
| om-lumen | 3 | 0 | 160 | 232 |
| praktiskt | 8 | 5 | 3124 | 4213 |
| profil | 3 | 0 | 1320 | 1391 |
| provläge | 2 | 2 | 3385 | 3385 |
| rizz | 21 | 2 | 1340 | 2625 |
| räkna | 20 | 0 | 731 | 1067 |
| socialt | 3 | 3 | 800 | 1649 |
| symboler | 10 | 2 | 1094 | 3005 |
| texter | 4 | 4 | 4079 | 4173 |
| tid | 8 | 0 | 510 | 763 |
| tystnad | 24 | 0 | 1434 | 2337 |
| uttal | 1 | 0 | 816 | 816 |
| webb | 5 | 5 | 2466 | 2738 |
| ämne | 7 | 0 | 1394 | 1945 |
| ämnesbyte | 30 | 5 | 949 | 3016 |

Relation (D53): 45/47 rätt av de turer där modellen angav en.

Tystnad (D75): 18/19 icke-frågor fick inget svar; 73/73 riktiga frågor besvarades.

Räkna (kod): 20/20 rätt (krav 100 %).

Uppskattad kostnad för körningen: ca 1.009 USD.

## Anmärkningar

| Typ | Antal |
|---|---:|
| långsamt | 28 |
| källrad saknas | 5 |
| fråga tillbaka | 4 |
| väntat svar saknas | 3 |
| förslag för långt | 2 |
| påhittad personuppgift | 2 |
| inte i jag-form | 2 |
| brasklapp/utfyllnad | 1 |
| förbjudet ord i svaret | 1 |
| för långt | 1 |
| svarade på en icke-fråga | 1 |

- **ämnesbyte-01** tur 2 "hur gör man pannkakor" (2524 ms): långsamt: 2524 ms till första ord (budget 2500)  
  > Till fyra personer behövs tre deciliter vetemjöl, sex deciliter mjölk, tre ägg, en nypa salt och ett par msk smält smör. Vispa mjöl, salt och ägg med lite mjölk till en klump, tillsätt resten av mjölken och smöret och lå
- **ämnesbyte-04** tur 3 "varför då?" (782 ms): brasklapp/utfyllnad: 'det beror på'  
  > Det beror på att procent betyder hundradelar, så när du delar delen med helheten får du en bråkdel, och multiplicerar du den med hundra ser du hur många hundradelar det blir. Tjugo procent av trehundrafemtio är alltså sa
- **ämnesbyte-05** tur 3 "varför då?" (928 ms): förbjudet ord i svaret: 'växt'  
  > Paris blev huvudstad eftersom staden under medeltiden växte till Frankrikes politiska och religiösa centrum, med kungens residens och universitetet. Under elvahundra- och tolvhundratalen stärktes kungamakten och Paris lå
- **ämnesbyte-06** tur 2 "hur byter man däck" (3016 ms): långsamt: 3016 ms till första ord (budget 2500)  
  > Här är de viktigaste stegen. Lägg i parkeringsbromsen, säkra bilen med hjulklossar och ta fram alla verktyg innan du börjar. Lossa bultarna ett kvarts varv med hjulmutternyckel medan hjulet fortfarande står på marken. Ly
- **ämnesbyte-09** tur 2 "hur lagar man ris" (3210 ms): långsamt: 3210 ms till första ord (budget 2500)  
  > Ris kokar du så här: koka upp två deciliter vatten per deciliter ris i en kastrull med lock, salta lite och lägg i risen. Låt koka på svag värme i cirka tio till tolv minuter, tills vattnet är absorberat, ta sedan av pla
- **symboler-07** tur 1 "när föll västromerska riket" (2528 ms): långsamt: 2528 ms till första ord (budget 2500)  
  > Västromerska riket föll år fyrahundrasjuttiosex efter Kristus, när den germanske härföraren Odoaker avsatte kejsar Romulus Augustulus.
- **symboler-08** tur 1 "hur lyder andragradsformeln" (3005 ms): långsamt: 3005 ms till första ord (budget 2500)  
  > Andragradsformeln för x i kvadrat plus p x plus q är lika med noll är x är lika med minus p genom två, plus minus roten ur parentesen p genom två i kvadrat minus q. Om uttrycket under rotenheter är negativt saknas reella
- **praktiskt-01** tur 1 "hur gör man pannkakor" (3129 ms): långsamt: 3129 ms till första ord (budget 2500)  
  > Blanda två deciliter vetemjöl, en halv tesked salt och två deciliter mjölk, sedan två ägg tills smeten är jämn. Låt den vila en stund, tillsätt sedan ytterligare en till två deciliter mjölk och stek tunna pannkakor i smö
- **praktiskt-03** tur 1 "hur byter man däck" (3096 ms): långsamt: 3096 ms till första ord (budget 2500); väntat svar saknas (något av: domkraft)  
  > Källorna är bara en vägledning, och jag ger de viktigaste stegen i ordning. Parkera på ett plant, hårt och stabilt underlag, lägg i parkeringsbromsen och säkra bilen med hjulklossar. Lossa bultarna ett kvarts varv medan 
- **praktiskt-04** tur 1 "recept på köttbullar" (3131 ms): långsamt: 3131 ms till första ord (budget 2500); väntat svar saknas (något av: köttfärs)  
  > Ett enkelt recept från ICA för cirka fyra portioner: en halv deciliter mjölk, en halv deciliter vispgrädde, en halv deciliter ströbröd, femhundra gram nöt- eller blandfärs, en tesked salt, ett ägg, en halv gul lök riven,
- **praktiskt-05** tur 1 "hur lagar man ris" (3124 ms): långsamt: 3124 ms till första ord (budget 2500)  
  > Koka ris så här: använd en kastrull med lock, en deciliter ris och två deciliter vatten, plus en nypa salt. Skölj riset först i kallt vatten tills vattnet blir nästan klart. Häll i vatten och salt, låt koka upp på hög vä
- **praktiskt-06** tur 1 "jag har ont i halsen" (4213 ms): långsamt: 4213 ms till första ord (budget 2500)  
  > Det mesta av halsont går över av sig själv inom några dagar. Dricka något varmt, som te, eller något kallt, som glass och yoghurt, brukar kännas bra. Ibland känns det bättre att ha något att suga på, till exempel halstab
- **socialt-01** tur 1 "Kalle sa att jag är tråkig vad säger jag" (800 ms): fråga tillbaka; för långt (26 ord, max 16)  
  > Haha, då får du visa honom att du är allt annat än tråkig. Vill du ta en fika på rasten och se vem som är tråkigast?
- **socialt-02** tur 1 "hon skrev hej vad svarar jag" (663 ms): fråga tillbaka  
  > Hej! Vad roligt att höra från dig, hur har du det?
- **socialt-03** tur 1 "min kompis frågade om jag vill hänga ikväll vad säger jag" (1649 ms): fråga tillbaka  
  > Gärna! Vad drar vi till med?
- **rizz-05** tur 1 "(Rizz)" (2625 ms): förslag för långt: 'Den boken är tjock nog att räknas som träning. Hur långt har du kommit?'; långsamt: första förslaget efter 2625 ms (mål 2500)  
  > Den boken är tjock nog att räknas som träning. Hur långt har du kommit?
- **minne-01** tur 1 "vad har du gjort i sommar" (725 ms): fråga tillbaka  
  > Jag åkte skidor, du då?
- **webb-01** tur 1 "vem vann senaste fotbolls VM" (2464 ms): källrad saknas  
  > Spanien vann senaste fotbolls-VM, som spelades tvåtusen tjugosex i USA, Kanada och Mexiko. Ferran Torres blev stor hjälte i finalen mot Argentina med sitt ett–noll-mål i förlängning. Det var Spaniens andra VM-guld. Källa
- **webb-02** tur 1 "vad är vädret idag i Stockholm" (2441 ms): källrad saknas  
  > Idag i Stockholm är det mulet med omkring fem grader, och kvällen väntas bli lätt regnskur. Förmiddag mulet Högsta temperatur sju grader. Källan är SMHI:s prognos, som kan ha uppdaterats sedan den hämtades. Källa: SMHI.
- **webb-03** tur 1 "vem är Sveriges statsminister just nu" (2738 ms): källrad saknas  
  > Sveriges statsminister är Ulf Kristersson, enligt regeringens webbplats. Sedan den sjuttonde september har Sverige en övergångsregering som leds av statsminister Ulf Kristersson. Han är statsminister sedan den artonde ok
- **webb-04** tur 1 "nyheter om Sverige idag" (2466 ms): källrad saknas  
  > Här är några av dagens nyheter i Sverige, enligt SVT och Sveriges Radio. Regeringsbildningen pågår, och SMHI har utfärdat gula varningar för snöfall. Elpriserna är höga, och flera företag tvingas dra ner på verksamheten.
- **webb-05** tur 1 "kolla scb.se hur många bor i Sverige" (2563 ms): källrad saknas  
  > Ungefär tio komma sex miljoner personer bor i Sverige. Vid halvårsskiftet tvåtusen tjugosex var tio miljoner sexhundratiotusen femhundra personer folkbokförda i landet. Sveriges befolkning ökade med femtusen personer und
- **rizz-14** tur 1 "(Rizz)" (1999 ms): förslag för långt: 'Den boken ser tjock ut. Hur långt hinner du innan kaffet tar slut?'  
  > Den boken ser tjock ut. Hur långt hinner du innan kaffet tar slut? | Jag måste veta om boken är värd att ignorera mig för. | Du läser fantasy, jag letar äventyr. Vilken bok ska jag börja med?
- **intervju-02** tur 1 "berätta om en gång du löste en konflikt" (4028 ms): långsamt: 4028 ms till första ord (budget 3000)  
  > Först ser jag till att alla är lugna, och sedan sätter jag mig på barnens nivå och lyssnar på vad var och en tycker. Jag hjälper dem att sätta ord på känslorna, till exempel "du blev arg för att han tog din bil", och sed
- **intervju-06** tur 2 "vad har du för erfarenhet av vård" (1124 ms): påhittad personuppgift: 'Jag har inte jobbat'  
  > Jag har inte jobbat inom vården tidigare, men det jag tar med mig till rollen är att jag är lugn och tålmodig när någon behöver tid. Jag lyssnar noga, frågar vad som känns svårast just nu och tar sedan itu med det konkre
- **meta-01** tur 1 "Du sätter in ett i formeln, gångrar med fem och lägger till ut till tio. Gud- Om x ökar från ett till två är- Två är krympning." (1147 ms): svarade på en icke-fråga (väntade tystnad)  
  > Om x ökar från ett till två blir y lika med fem gånger två plus tio, alltså tjugo. Då har y ökat från femton till tjugo, alltså med fem. Det är lutningen: varje gång x ökar med en ökar y med fem, så det är en ökning och 
- **cv-04** tur 1 "har du jobbat med kassa förut" (875 ms): påhittad personuppgift: 'Jag har inte jobbat'  
  > Jag har inte jobbat med kassa tidigare, men jag är van vid att hantera många saker samtidigt och att möta människor på ett trevligt sätt. Jag lär mig snabbt, och jag är noggrann med att räkna rätt och ge rätt växel. Jag 
- **text-01** tur 1 "sjung en snapsvisa" (2671 ms): långsamt: 2671 ms till första ord (budget 2500)  
  > Helan går, sjung hopp fallera, helan går, sjung hopp fallera, helan går, sjung hopp fallera, helan går, sjung hopp fallera.  Och den som inte helan tar, han heller inte halvan får, helan går, sjung hopp fallera.
- **text-02** tur 1 "sjung helan går" (3036 ms): långsamt: 3036 ms till första ord (budget 2500); väntat svar saknas (något av: halvan går)  
  > Helan går sjung hoppfaderallanlallanlej Helan går sjung hoppfaderallanlallanlej Och den som inte helan tar han inte halvan får Helan går sjung hoppfaderallanlallanlej
- **text-03** tur 1 "citera Strindberg om kärlek" (4173 ms): långsamt: 4173 ms till första ord (budget 2500)  
  > Strindberg dog nittonhundratolv, så texten är fri. Källa: Litteraturbanken.
- **text-04** tur 1 "sjung Tattoo med Loreen" (4079 ms): långsamt: 4079 ms till första ord (budget 2500)  
  > Tattoo är Loreens vinnarlåt i Eurovision Song Contest tvåtusen tjugotre, där hon vann för Sverige i Liverpool. Låten handlar om en kärlek som är så stark att den känns som ett outplånligt märke, ungefär som en tatuering.
- **k7-logik-01** tur 1 "Anna och Fredrik går hem till varandra, Anna går dubbelt så snabbt som Fredrik men de möttes ändå halvvägs, hur kan det komma sig" (4223 ms): långsamt: 4223 ms till första ord (budget 2500)  
  > De möts halvvägs bara om Fredrik gick hemifrån tidigare än Anna. Halvvägs betyder att de har gått lika långt, och sträcka är hastighet gånger tid. Eftersom Anna går dubbelt så fort behöver hon bara halva tiden för att gå
- **k9-harder_question-1** tur 1 "ställ en svår fråga" (3076 ms): långsamt: 3076 ms till första ord (budget 2500)  
  > Varför slutar en växt att växa om den står i ett mörkt rum under lång tid, trots att den får vatten och näring?
- **k9-harder_question-2** tur 1 "Lumen, en svårare fråga" (3450 ms): långsamt: 3450 ms till första ord (budget 2500)  
  > Varför slutar fotosyntesen i en växt om stomata, alltså klyvöppningarna, stängs under en het och torr dag, trots att det finns gott om solljus?
- **k9-harder_question-3** tur 1 "utmana mig" (2863 ms): långsamt: 2863 ms till första ord (budget 2500)  
  > Varför blir fotosyntesen långsammare på en mycket kall dag, även om det är gott om ljus, vatten och koldioxid?
- **k9-quiz_topic-1** tur 1 "förhör mig på cellandning" (2863 ms): långsamt: 2863 ms till första ord (budget 2500)  
  > Vilka två ämnen behöver cellerna för cellandning, och vilket ämne bildas som avfall tillsammans med vatten och energi?
- **k9-quiz_topic-2** tur 1 "Lumen, testa mig om klorofyll" (2737 ms): långsamt: 2737 ms till första ord (budget 2500)  
  > Vilken färg på ljuset absorberar klorofyllet minst, så att växter ser gröna ut?
- **k9-weak_areas-1** tur 1 "testa mina svagaste områden" (2686 ms): långsamt: 2686 ms till första ord (budget 2500)  
  > Vilken gas tar växten upp från luften för att kunna bilda socker i fotosyntesen?
- **k9-weak_areas-2** tur 1 "vad kan jag sämst" (2748 ms): långsamt: 2748 ms till första ord (budget 2500)  
  > Vilket ämne i kloroplasten fångar upp ljusenergin vid fotosyntesen?
- **k9-weak_areas-3** tur 1 "vad behöver jag öva mer på" (2909 ms): långsamt: 2909 ms till första ord (budget 2500)  
  > Vilket ämne i klorofyll tar upp ljuset i kloroplasterna, och vilken färg ger det bladen?
- **k9-ih-professional-2** tur 1 "vad borde jag säga" (1377 ms): inte i jag-form  
  > Kvällar och helger passar dig bra, och du trivs i ett snabbt tempo där det händer mycket hela tiden. Du vill lära dig hur en livsmedelsbutik fungerar och bidra med ett vänligt bemötande och noggrannhet vid kassan.
- **k9-ih-counter_question-2** tur 1 "vad kan jag fråga tillbaka" (1293 ms): inte i jag-form  
  > Hur ser en vanlig kväll ut i kassan, och vad brukar vara mest utmanande under helgerna?
- **k9-neg-5** tur 1 "vad händer med klimatet i framtiden" (3207 ms): långsamt: 3207 ms till första ord (budget 2500)  
  > Enligt FN:s klimatpanel IPCC blir det varmare, och utfallet beror på hur mycket utsläppen minskar. IPCC bedömer att temperaturen globalt kommer att öka mellan ett komma fyra – fem till sju grader fram till seklets slut b
- **k20-04** tur 1 "jag vet inte ens vad jag ska fråga" (2636 ms): långsamt: 2636 ms till första ord (budget 2500)  
  > Börja med cellens delar, sedan växtcellen mot djurcellen och till sist fotosyntes och cellandning. Det är det som oftast kommer på prov om cellen.  Vi tar delarna först. 
- **k20-05** tur 1 "ge mig en svår fråga" (3385 ms): långsamt: 3385 ms till första ord (budget 2500)  
  > Varför har en cell i en växt både mitokondrier och kloroplaster, när en djurcell bara har mitokondrier, och vad säger det om hur växtcellen får sin energi?
