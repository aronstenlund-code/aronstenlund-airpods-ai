"""O55: påhittat studiematerial för repetitionsläget (D142). Skrivet av Oscar (QA). Aldrig elevtext.

Varje prov har:
  pages   – materialet uppdelat i sidor (en sida = ett foto, en PDF-sida eller ett stycke i .docx/text)
  formats – hur sidorna lämnas in: lista av (format, [sidindex]) där format är photo | pdf | docx | text
  goals   – facitlistan över lärandemål (R2): id, mål, nyckelord som ett svar/en fråga om målet bör innehålla
  outside – närliggande saker som INTE står i materialet; en fråga om dem räknas som "utanför materialet" (R2)
"""

M = {}

M["bio-ak8-fotosyntes"] = dict(
    subject="Biologi", grade="åk 8", topic="Ekologi och fotosyntes",
    pages=[
        "Ekologi – begrepp\nEtt ekosystem är alla levande organismer i ett område tillsammans med den icke levande miljön, "
        "till exempel vatten, ljus, jord och temperatur. En population är alla individer av samma art i ett område. "
        "Ett samhälle är alla populationer i området.",
        "Fotosyntes\nGröna växter tillverkar sin egen näring genom fotosyntes. I bladens kloroplaster finns det gröna "
        "färgämnet klorofyll som fångar upp ljusenergi. Växten tar upp koldioxid från luften genom klyvöppningarna och "
        "vatten genom rötterna.",
        "Fotosyntesens formel\nkoldioxid + vatten + ljusenergi → glukos + syre\n6 CO2 + 6 H2O → C6H12O6 + 6 O2\n"
        "Glukosen används som energi och byggmaterial, till exempel till cellulosa och stärkelse. Syret släpps ut i luften.",
        "Producenter och konsumenter\nOrganismer som tillverkar sin egen näring kallas producenter. Djur som äter "
        "växter är förstahandskonsumenter (växtätare). Djur som äter växtätare är andrahandskonsumenter. "
        "Rovdjur högst upp i kedjan kallas toppkonsumenter.",
        "Näringskedjor och näringsvävar\nEn näringskedja visar vem som äter vem: gräs → hare → räv. "
        "I naturen äter de flesta djur mer än en sorts föda. Kedjorna hakar då i varandra och bildar en näringsväv.",
        "Energiflödet\nVid varje steg i en näringskedja går ungefär 90 procent av energin förlorad som värme, rörelse "
        "och sådant som inte äts upp. Bara cirka 10 procent förs vidare. Därför finns det färre rovdjur än växtätare, "
        "och därför är kedjorna sällan längre än fyra eller fem led.",
        "Nedbrytare\nNedbrytare, till exempel svampar, bakterier och daggmaskar, bryter ner döda växter och djur. "
        "Näringsämnena hamnar i jorden och kan tas upp av växterna igen. Utan nedbrytare skulle kretsloppet stanna.",
        "Kolets kretslopp\nKol går runt i naturen. Växterna binder koldioxid vid fotosyntesen. När organismer andas "
        "och när döda växter bryts ner släpps koldioxid ut igen. När vi eldar fossila bränslen frigörs kol som legat "
        "lagrat i miljontals år, och halten koldioxid i luften ökar.",
        "Övergödning\nNär för mycket kväve och fosfor från gödsel och avlopp hamnar i en sjö växer alger kraftigt. "
        "När algerna dör bryts de ner av bakterier som förbrukar syret i vattnet. Syrebrist gör att fiskar och "
        "bottendjur dör.",
        "Att motverka övergödning\nMan kan minska övergödningen genom att gödsla mindre och vid rätt tidpunkt, ha "
        "skyddszoner med gräs mellan åkrar och vattendrag, anlägga våtmarker som fångar näring och rena avloppsvatten "
        "bättre.",
        # sid 10 (index 10) = PDF med lärarens sammanfattning
        "Sammanfattning inför provet\nKunna förklara fotosyntesen med ord och formel. Kunna skillnaden mellan "
        "producent, konsument och nedbrytare. Kunna förklara varför energin minskar i en näringskedja. Kunna förklara "
        "kolets kretslopp och hur övergödning uppstår och kan motverkas.",
    ],
    formats=[("photo", list(range(10))), ("pdf", [10])],
    goals=[
        ("G1", "Förklara vad ett ekosystem, en population och ett samhälle är", ["ekosystem", "population"]),
        ("G2", "Förklara vad växten behöver för fotosyntes och var den sker", ["klorofyll", "koldioxid", "vatten", "ljus"]),
        ("G3", "Fotosyntesens produkter och formel", ["glukos", "syre"]),
        ("G4", "Skillnaden mellan producent, konsument och toppkonsument", ["producent", "konsument"]),
        ("G5", "Näringskedja och näringsväv", ["näringskedja", "näringsväv"]),
        ("G6", "Varför energin minskar i en näringskedja (10 %-regeln)", ["energi", "10 procent", "värme"]),
        ("G7", "Nedbrytarnas roll i kretsloppet", ["nedbrytare", "näringsämnen"]),
        ("G8", "Kolets kretslopp och fossila bränslen", ["kol", "koldioxid", "fossila"]),
        ("G9", "Hur övergödning uppstår och leder till syrebrist", ["övergödning", "alger", "syrebrist"]),
        ("G10", "Hur övergödning kan motverkas", ["skyddszoner", "våtmarker"]),
    ],
    outside=["cellandning i detalj", "mitokondrier", "pollinering", "evolution", "människans matspjälkning"],
)

M["hist-ak9-forsta-varldskriget"] = dict(
    subject="Historia", grade="åk 9", topic="Första världskriget",
    pages=[
        "Första världskriget 1914–1918\nOrsaker: Europas stormakter konkurrerade om kolonier och handel (imperialism), "
        "byggde upp stora arméer och flottor (militarism) och var starkt nationalistiska. De hade bildat två allianser: "
        "Ententen (Storbritannien, Frankrike och Ryssland) och Centralmakterna (Tyskland och Österrike-Ungern). "
        "Den 28 juni 1914 sköts Österrike-Ungerns tronföljare Franz Ferdinand i Sarajevo av en bosnisk serb. "
        "Österrike-Ungern förklarade krig mot Serbien, och alliansernas löften drog in de andra stormakterna.",
        "Kriget\nTyskland försökte snabbt besegra Frankrike genom Belgien (Schlieffenplanen), men anfallet stoppades. "
        "På västfronten grävde arméerna ner sig i skyttegravar från Nordsjön till Schweiz. Fronten stod nästan stilla "
        "i fyra år. Kulsprutor, taggtråd, artilleri och giftgas gjorde att anfall över ingenmansland kostade "
        "hundratusentals liv, som vid Somme 1916. Kriget var ett totalt krig: hela samhällen, fabriker och kvinnor "
        "som tog männens arbeten deltog.",
        "Slutet och freden\nÅr 1917 gick USA med i kriget, efter Tysklands oinskränkta ubåtskrig och "
        "Zimmermann-telegrammet. Samma år tog bolsjevikerna makten i Ryssland, som lämnade kriget. "
        "Den 11 november 1918 skrevs ett vapenstillestånd. I Versaillesfreden 1919 fick Tyskland ta på sig skulden "
        "för kriget, betala stora skadestånd, lämna ifrån sig land och kolonier och rusta ner. Många tyskar kände sig "
        "förödmjukade. Nationernas förbund bildades för att förhindra nya krig.",
    ],
    formats=[("photo", [0, 1, 2])],
    goals=[
        ("G1", "Krigets år och långsiktiga orsaker (imperialism, militarism, nationalism)", ["1914", "1918", "nationalis"]),
        ("G2", "Allianserna och vilka länder som ingick", ["ententen", "centralmakterna"]),
        ("G3", "Skotten i Sarajevo som utlösande orsak och hur allianserna drog in fler", ["Franz Ferdinand", "Sarajevo"]),
        ("G4", "Skyttegravskriget och varför fronten stod still", ["skyttegrav", "kulsprut", "ingenmansland"]),
        ("G5", "Totalt krig och kvinnornas roll", ["totalt krig", "kvinnor"]),
        ("G6", "Varför USA gick med och varför Ryssland lämnade kriget", ["ubåtskrig", "Zimmermann", "bolsjevikerna"]),
        ("G7", "Versaillesfreden och dess följder", ["Versailles", "skadestånd", "skulden"]),
        ("G8", "Nationernas förbund", ["Nationernas förbund"]),
    ],
    outside=["andra världskriget", "Hitlers maktövertagande", "Förintelsen", "Sveriges neutralitet", "spanska sjukan"],
)

M["ma1b-ekvationer"] = dict(
    subject="Matematik", grade="Matematik 1b", topic="Ekvationer och räta linjen",
    pages=[
        "Ekvationer\nEn ekvation löses genom att man gör samma sak på båda sidor om likhetstecknet. "
        "Exempel: 3x + 5 = 20. Subtrahera 5: 3x = 15. Dividera med 3: x = 5. Kontrollera alltid genom att sätta in "
        "lösningen: 3 · 5 + 5 = 20.\nParenteser multipliceras först ut: 2(x − 4) = x + 3 ger 2x − 8 = x + 3 och x = 11.",
        "Räta linjens ekvation\nEn rät linje kan skrivas y = kx + m. k är lutningen (riktningskoefficienten): hur mycket "
        "y ökar när x ökar med 1. m är där linjen skär y-axeln. Negativt k betyder att linjen lutar nedåt.\n"
        "Lutningen mellan två punkter: k = (y2 − y1)/(x2 − x1). Exempel: (1, 3) och (3, 11) ger k = 8/2 = 4. "
        "m fås genom att sätta in en punkt: 3 = 4 · 1 + m, alltså m = −1 och y = 4x − 1.",
        "Problemlösning med linjära modeller\nEn fast avgift plus en kostnad per enhet ger en linjär modell: "
        "kostnad = fast avgift + pris · antal. Ett gym med 300 kr i startavgift och 150 kr per månad: y = 150x + 300.\n"
        "För att jämföra två abonnemang sätter man uttrycken lika och löser ekvationen. Lösningen är brytpunkten där "
        "båda kostar lika mycket. Rita gärna båda linjerna och se vilken som ligger lägst på var sida om brytpunkten.",
    ],
    formats=[("pdf", [0, 1, 2])],
    goals=[
        ("G1", "Lösa linjära ekvationer med balansmetoden och kontrollera svaret", ["ekvation", "båda sidor", "kontrollera"]),
        ("G2", "Ekvationer med parenteser", ["parentes"]),
        ("G3", "Tolka k och m i y = kx + m", ["lutning", "k", "m", "y-axeln"]),
        ("G4", "Bestämma linjens ekvation från två punkter", ["två punkter", "k = "]),
        ("G5", "Ställa upp en linjär modell med fast avgift och pris per enhet", ["fast avgift", "linjär modell"]),
        ("G6", "Hitta och tolka brytpunkten mellan två modeller", ["brytpunkt", "lika"]),
    ],
    outside=["andragradsekvationer", "pq-formeln", "procentuell förändring", "exponentialfunktioner", "sannolikhet"],
)

M["ke1-mol"] = dict(
    subject="Kemi", grade="Kemi 1", topic="Stökiometri och mol",
    pages=[
        "Substansmängd och molmassa\nSubstansmängd mäts i mol. 1 mol innehåller cirka 6,022 · 10^23 partiklar "
        "(Avogadros konstant). Molmassan M är massan av 1 mol av ämnet i g/mol och räknas ut från atommassorna. "
        "Vatten H2O: 2 · 1,0 + 16,0 = 18,0 g/mol.\nSambandet n = m/M: 88 g koldioxid (M = 44,0 g/mol) är 2,0 mol.",
        "Reaktionsformler\nEn reaktionsformel balanseras så att det finns lika många atomer av varje slag på båda "
        "sidor, eftersom atomer inte förstörs eller skapas. Man ändrar bara koefficienterna framför formlerna, aldrig "
        "indexen. Exempel: 2 H2 + O2 → 2 H2O. Koefficienterna anger förhållandet mellan substansmängderna.",
        "Koncentration\nKoncentrationen c = n/V, där V är volymen i dm³ (liter). Enheten är mol/dm³ (molar, M). "
        "0,50 mol NaCl i 0,250 dm³ ger 2,0 mol/dm³. Vid spädning är substansmängden densamma före och efter: "
        "c1 · V1 = c2 · V2.",
        "Stökiometriska beräkningar\n1. Skriv och balansera reaktionsformeln. 2. Räkna om given massa till mol. "
        "3. Använd koefficienterna för att få substansmängden av det sökta ämnet. 4. Räkna om till massa.\n"
        "Exempel: CH4 + 2 O2 → CO2 + 2 H2O. 16 g metan = 1,0 mol, som kräver 2,0 mol O2 = 64 g.",
    ],
    formats=[("docx", [0, 1, 2, 3])],
    goals=[
        ("G1", "Vad en mol är och Avogadros konstant", ["mol", "Avogadros"]),
        ("G2", "Räkna molmassa och använda n = m/M", ["molmassa", "n = m/M"]),
        ("G3", "Balansera reaktionsformler och varför man gör det", ["balansera", "koefficient", "atomer"]),
        ("G4", "Koncentration c = n/V", ["koncentration", "mol/dm³"]),
        ("G5", "Spädning c1V1 = c2V2", ["spädning"]),
        ("G6", "Stökiometrisk beräkning i fyra steg", ["substansmängd", "koefficienterna", "massa"]),
    ],
    outside=["pH och syror", "redoxreaktioner", "gaslagen pV = nRT", "jämvikt", "organisk kemi"],
)

M["fy-ak9-ellara"] = dict(
    subject="Fysik", grade="åk 9", topic="Ellära",
    pages=[
        "Ellära – grunder\nElektrisk ström är laddningar (elektroner) som rör sig i en sluten krets. Strömmen I mäts i "
        "ampere (A) med en amperemeter som kopplas i serie. Spänningen U mäts i volt (V) med en voltmeter som kopplas "
        "parallellt och är det som driver strömmen. Resistansen R mäts i ohm (Ω) och visar hur mycket en komponent "
        "begränsar strömmen.\n\nOhms lag: U = R · I. En lampa med 6 Ω på 12 V får strömmen 12/6 = 2 A.\n\n"
        "Serie- och parallellkoppling: i en seriekoppling går samma ström genom alla komponenter. Går en lampa sönder "
        "bryts hela kretsen. I en parallellkoppling har strömmen flera vägar, så de andra lamporna lyser vidare. "
        "Hemmets eluttag är parallellkopplade.\n\nEffekt och energi: effekten P = U · I mäts i watt. Energin E = P · t. "
        "Elräkningen räknas i kilowattimmar: 1 kWh är energin när 1 000 W används i en timme. En vattenkokare på "
        "2 000 W som används 1,5 timmar under en månad drar 3 kWh.\n\nElsäkerhet: säkringen bryter strömmen om den blir "
        "för stor, och jordfelsbrytaren bryter om ström läcker ut, till exempel genom en människa.",
    ],
    formats=[("text", [0])],
    goals=[
        ("G1", "Vad ström är och hur den mäts", ["ström", "ampere", "elektroner"]),
        ("G2", "Spänning och resistans och deras enheter", ["spänning", "volt", "resistans", "ohm"]),
        ("G3", "Använda Ohms lag", ["Ohms lag", "U = R · I"]),
        ("G4", "Skillnaden mellan serie- och parallellkoppling", ["seriekoppling", "parallellkoppling"]),
        ("G5", "Effekt och energi, kWh och elkostnad", ["effekt", "watt", "kWh"]),
        ("G6", "Säkring och jordfelsbrytare", ["säkring", "jordfelsbrytare"]),
    ],
    outside=["magnetism och elmotorer", "induktion", "kärnkraft", "statisk elektricitet", "halvledare"],
)

M["eng6-grammar"] = dict(
    subject="Engelska", grade="Engelska 6", topic="Grammar and vocabulary",
    pages=[
        "Present perfect vs. past simple\nUse the present perfect (have/has + past participle) for something that started "
        "in the past and is still true: 'I have lived here for three years.' Use the past simple for a finished time: "
        "'I lived in Lund in 2020.' Swedish speakers often say 'I live here since three years' – this is wrong.",
        "Irregular verbs and conditionals\nSome verbs are irregular: seek – sought – sought, bring – brought – brought, "
        "lie – lay – lain. In the second conditional (unreal present) use 'were' for all persons: 'If I were rich, "
        "I would travel the world.'",
        "Confusing words\n'Affect' is usually a verb (to influence): 'The weather affects my mood.' 'Effect' is usually "
        "a noun (a result): 'The effect was huge.' Advanced vocabulary: 'ubiquitous' means found everywhere "
        "(synonyms: omnipresent, widespread). 'Ambiguous' means having more than one possible meaning.",
    ],
    formats=[("photo", [0, 1]), ("text", [2])],
    goals=[
        ("G1", "When to use present perfect vs. past simple", ["present perfect", "past simple"]),
        ("G2", "The Swedish-speaker mistake 'since three years'", ["for three years", "since"]),
        ("G3", "Irregular verbs seek, bring, lie", ["sought", "brought"]),
        ("G4", "Second conditional with 'were'", ["were", "would"]),
        ("G5", "Affect vs. effect", ["affect", "effect"]),
        ("G6", "Meaning of ubiquitous and ambiguous", ["ubiquitous", "ambiguous"]),
    ],
    outside=["phrasal verbs", "passive voice", "reported speech", "Shakespeare", "British vs American spelling"],
)

M["sv1-sprakhistoria"] = dict(
    subject="Svenska", grade="Svenska 1", topic="Svensk språkhistoria",
    pages=[
        "Runsvenska (ca 800–1225)\nPå vikingatiden skrev man med runor. Runalfabetet kallas futharken efter de första "
        "tecknen. Den yngre futharken hade bara 16 runor. Runstenar restes ofta till minne av döda släktingar.",
        "Fornsvenska (1225–1526)\nMed kristendomen kom det latinska alfabetet. Under Hansans tid kom många lågtyska "
        "lånord, till exempel betala, språk, fönster och borgmästare, eftersom tyska köpmän dominerade handeln i "
        "städerna.",
        "Nysvenska (från 1526)\nNya testamentet på svenska kom 1526 och Gustav Vasas bibel 1541. Bibeln lästes i "
        "kyrkor i hela riket och blev förebild för stavning och skriftspråk, så språket blev mer enhetligt. "
        "På 1700-talet lånade svenskan många franska ord, till exempel trottoar, paraply, fåtölj och byrå.",
        "Svenskan i dag\nI dag lånar svenskan främst från engelskan, till exempel inom teknik, musik och ungdomsspråk. "
        "Det gör språket rikare och underlättar kontakt med andra länder. En risk är domänförlust: att svenskan slutar "
        "användas inom vissa områden, till exempel forskning eller stora företag.",
    ],
    formats=[("docx", [0, 1, 2, 3])],
    goals=[
        ("G1", "Runsvenska och futharken", ["runor", "futhark"]),
        ("G2", "Lågtyska lånord under Hansan och varför", ["lågtyska", "Hansan"]),
        ("G3", "Gustav Vasas bibel och skriftspråkets enhetlighet", ["Gustav Vasas bibel", "1541"]),
        ("G4", "Franska lånord på 1700-talet", ["franska", "paraply"]),
        ("G5", "Engelska lånord i dag, för- och nackdelar", ["engelska", "lånord"]),
        ("G6", "Domänförlust", ["domänförlust"]),
    ],
    outside=["dialekter i Sverige", "minoritetsspråk", "Strindberg", "grammatik och ordklasser", "nordiska grannspråk"],
)

M["ge-ak7-klimat"] = dict(
    subject="Geografi", grade="åk 7", topic="Klimat och vegetationszoner",
    pages=[
        "Väder och klimat\nVäder är hur det är i atmosfären just nu eller under några dagar. Klimat är medelvärdet av "
        "vädret under lång tid, oftast 30 år.\nSolinstrålning: vid ekvatorn träffar solstrålarna jorden nästan rakt "
        "och värmer en liten yta. Mot polerna kommer strålarna snett och sprids över en större yta, därför är det "
        "kallare där.",
        "Havsströmmar och nederbörd\nGolfströmmen (Nordatlantiska driften) för varmt vatten från Mexikanska golfen till "
        "Nordeuropa och gör Skandinaviens klimat mildare än på samma breddgrad i Kanada.\nVästvindar med fuktig luft "
        "från Atlanten tvingas upp över fjällen. Luften kyls, vattenångan kondenserar och det regnar mycket på "
        "västsidan (lovartsidan). På östsidan blir det torrare: regnskugga.",
        "Vegetationszoner\nTundra: kallt, kort sommar, mossor, lavar och dvärgbjörk. Barrskogszonen (tajgan): gran och "
        "tall, täcker större delen av Norrland. Lövskogszonen: ek och bok, södra Sverige. Stäpp: gräs, torrt inland. "
        "Öken: mycket lite nederbörd. Regnskog: varmt och regn hela året kring ekvatorn.",
    ],
    formats=[("pdf", [0, 1, 2])],
    goals=[
        ("G1", "Skillnaden mellan väder och klimat", ["väder", "klimat", "30 år"]),
        ("G2", "Varför det är varmare vid ekvatorn", ["solstrålar", "rakt", "yta"]),
        ("G3", "Golfströmmen och Skandinaviens klimat", ["Golfströmmen"]),
        ("G4", "Orografisk nederbörd och regnskugga", ["regnskugga", "fjällen"]),
        ("G5", "Vegetationszonerna och var de finns", ["tundra", "tajga", "regnskog"]),
    ],
    outside=["växthuseffekten", "plattektonik", "befolkningstäthet", "monsun", "vulkaner"],
)

M["sh1b-demokrati"] = dict(
    subject="Samhällskunskap", grade="Samhällskunskap 1b", topic="Demokrati och statsskick",
    pages=[
        "Sveriges statsskick\nSverige är en parlamentarisk demokrati och en konstitutionell monarki. All offentlig makt "
        "utgår från folket (regeringsformen). Riksdagen har 349 ledamöter som väljs vart fjärde år. Ett parti måste få "
        "minst 4 procent av rösterna i hela landet, eller 12 procent i en valkrets, för att komma in.\n\n"
        "Maktdelning: riksdagen stiftar lagar, beslutar om statens budget och granskar regeringen. Regeringen styr "
        "landet och verkställer riksdagens beslut med hjälp av myndigheter. Domstolarna dömer enligt lagarna och är "
        "självständiga. Riksdagen kan avsätta en minister eller hela regeringen med misstroendeförklaring.\n\n"
        "Direkt och representativ demokrati: i en direktdemokrati röstar medborgarna själva om besluten, till exempel "
        "i folkomröstningar. Det ger stort inflytande men är långsamt och kräver mycket kunskap av alla. I en "
        "representativ demokrati väljer folket representanter som fattar besluten. Det är effektivare, men avståndet "
        "mellan väljare och beslut blir större.",
    ],
    formats=[("text", [0])],
    goals=[
        ("G1", "Parlamentarisk demokrati och konstitutionell monarki", ["parlamentarisk", "monarki"]),
        ("G2", "Riksdagens storlek, val vart fjärde år och spärrarna", ["349", "fjärde år", "4 procent"]),
        ("G3", "Maktdelningen mellan riksdag, regering och domstolar", ["riksdagen", "regeringen", "domstolar"]),
        ("G4", "Misstroendeförklaring", ["misstroendeförklaring"]),
        ("G5", "Direkt mot representativ demokrati", ["direktdemokrati", "representativ"]),
    ],
    outside=["EU:s institutioner", "kommunernas ansvar", "partiernas ideologier", "FN", "mediernas roll"],
)

M["re-ak8-varldsreligioner"] = dict(
    subject="Religionskunskap", grade="åk 8", topic="Världsreligionerna",
    pages=[
        "Judendom och islam\nJudendomens heliga skrift är Tanach, där Toran är den viktigaste delen. Vilodagen sabbat "
        "börjar vid solnedgången på fredagen och slutar på lördagskvällen. Islams heliga skrift är Koranen. Islams fem "
        "pelare är trosbekännelsen, bönen fem gånger om dagen, allmosan, fastan under ramadan och vallfärden till Mecka.",
        "Hinduism och buddhism\nI hinduismen och buddhismen finns tron på återfödelse (samsara) och karma: handlingar "
        "får följder, även i kommande liv. I hinduismen är målet att själen (atman) befrias från kretsloppet (moksha).",
        "Buddhismens fyra ädla sanningar\n1. Livet innebär lidande. 2. Lidandet orsakas av begär. 3. Lidandet kan upphöra "
        "(nirvana). 4. Vägen dit är den åttafaldiga vägen.\n\nKristendom: kristna tror att människan lever ett liv och att "
        "Jesus uppstod från de döda. Efter döden väntar uppståndelse och dom.",
    ],
    formats=[("photo", [0, 1]), ("docx", [2])],
    goals=[
        ("G1", "Judendomens skrift och sabbaten", ["Tanach", "Toran", "sabbat"]),
        ("G2", "Koranen och islams fem pelare", ["Koranen", "fem pelare"]),
        ("G3", "Karma och samsara", ["karma", "återfödelse"]),
        ("G4", "Atman och moksha i hinduismen", ["atman", "moksha"]),
        ("G5", "Buddhismens fyra ädla sanningar", ["lidande", "begär", "nirvana", "åttafaldiga"]),
        ("G6", "Kristendomens syn på livet efter döden jämfört med hinduismen", ["uppståndelse", "återfödelse"]),
    ],
    outside=["sikhism", "religion och vetenskap", "etiska modeller", "nyandlighet", "kristendomens olika kyrkor"],
)
