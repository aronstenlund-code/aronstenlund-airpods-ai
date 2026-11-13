"""O55b: fem nya påhittade prov som Kevin inte har sett (hållout). Skrivet av Oscar (QA) 2026-11-13. Aldrig elevtext.

Samma format som materials.M, plus:
  grade_ok – årskurser som räknas som rätt om servern läser av den; tom årskurs räknas alltid som rätt (K52: rätt eller
             tom, aldrig fel). None betyder att materialet inte anger någon årskurs, så bara tom är rätt.
  max_q    – (D159) högsta rimliga antal frågor för tunt material; None = ingen gräns.
Ligger utanför exams.json med avsikt, så att Kevins scripts/k45-measure.py inte mäter på dem.
"""

H = {}

H["ho-bio-ak9-blodet"] = dict(
    subject="Biologi", grade="åk 9", grade_ok=["åk 9", "åk9", "y9", "årskurs 9"], max_q=None,
    topic="Blodet och blodomloppet",
    pages=[
        "Biologi åk 9 – Kapitel 4: Blodet och blodomloppet\nHjärtat är en muskel som pumpar runt blodet i kroppen. "
        "Det har fyra rum: två förmak och två kammare. Klaffar i hjärtat gör att blodet bara kan flyta åt ett håll.",
        "Två kretslopp\nI det lilla kretsloppet pumpar höger kammare blodet till lungorna, där det tar upp syre och "
        "lämnar koldioxid. I det stora kretsloppet pumpar vänster kammare det syrerika blodet ut till hela kroppen. "
        "Vänster kammare har tjockare vägg eftersom den måste pumpa längre.",
        "Blodkärlen\nArtärer för blodet bort från hjärtat och har tjocka, elastiska väggar eftersom trycket är högt. "
        "Vener för blodet tillbaka till hjärtat och har klaffar som hindrar blodet från att flyta bakåt. "
        "Kapillärerna är så tunna att syre och näring kan passera ut till cellerna.",
        "Blodets innehåll\nRöda blodkroppar innehåller hemoglobin som binder syre. Vita blodkroppar försvarar kroppen "
        "mot bakterier och virus. Blodplättar hjälper blodet att levra sig när vi får ett sår. Blodplasman är den "
        "vätska som transporterar näring, hormoner och avfall.",
        "Hjärtat och hälsan\nRegelbunden motion stärker hjärtmuskeln så att den pumpar mer blod per slag och vilopulsen "
        "sjunker. Rökning och mycket salt kan ge högt blodtryck. Om ett kranskärl täpps till får en del av hjärtmuskeln "
        "inte syre, och det kallas hjärtinfarkt.",
    ],
    formats=[("photo", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "Hjärtats byggnad: förmak, kammare och klaffar", ["förmak", "kammare", "klaff"]),
        ("G2", "Lilla och stora kretsloppet", ["lungorna", "kretslopp"]),
        ("G3", "Varför vänster kammare har tjockare vägg", ["vänster kammare", "tjock"]),
        ("G4", "Skillnaden mellan artärer, vener och kapillärer", ["artär", "ven", "kapillär"]),
        ("G5", "Röda blodkroppar och hemoglobin", ["hemoglobin", "syre"]),
        ("G6", "Vita blodkroppar, blodplättar och plasma", ["vita blodkroppar", "blodplättar", "plasma"]),
        ("G7", "Hur motion påverkar hjärtat", ["motion", "vilopuls"]),
        ("G8", "Högt blodtryck och hjärtinfarkt", ["blodtryck", "hjärtinfarkt", "kranskärl"]),
    ],
    outside=["blodgrupper", "blodtransfusion", "njurarna", "lymfsystemet", "stamceller"],
)

H["ho-fy1-newton"] = dict(
    subject="Fysik", grade="Fysik 1", grade_ok=["fysik 1", "fysik1", "gy1", "gymnasiet", "gymnasiet år 1", "gy 1"],
    max_q=None, topic="Kraft och rörelse, Newtons lagar",
    pages=[
        "Fysik 1 (gymnasiet) – Kraft och rörelse\nEn kraft mäts i newton (N). Kraft är en vektor: den har både storlek "
        "och riktning. Om flera krafter verkar på samma föremål kan de läggas ihop till en resulterande kraft.",
        "Newtons första lag (tröghetslagen)\nOm den resulterande kraften på ett föremål är noll fortsätter det att "
        "ligga still eller röra sig med konstant fart rakt fram. Det är därför man kastas framåt när en buss "
        "tvärbromsar: kroppen vill fortsätta i samma fart.",
        "Newtons andra lag\nDen resulterande kraften är lika med massan gånger accelerationen, F = m · a. "
        "Exempel: en vagn på 20 kg som påverkas av en resulterande kraft på 60 N får accelerationen 3 m/s². "
        "Samma kraft ger ett tyngre föremål mindre acceleration.",
        "Newtons tredje lag\nNär ett föremål påverkar ett annat med en kraft påverkar det andra tillbaka med en lika "
        "stor kraft i motsatt riktning. När du går trycker foten bakåt mot marken och marken trycker dig framåt. "
        "Krafterna verkar på olika föremål och tar därför inte ut varandra.",
        "Tyngdkraft och friktion\nTyngdkraften på ett föremål är F = m · g, där g är ungefär 9,8 N/kg på jorden. "
        "Friktion är en kraft som motverkar rörelse mellan två ytor. Friktionen beror på ytornas material och på hur "
        "hårt de trycks mot varandra (normalkraften).",
    ],
    formats=[("pdf", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "Kraft som vektor och resulterande kraft", ["vektor", "resulterande"]),
        ("G2", "Newtons första lag, tröghet", ["tröghet", "konstant fart"]),
        ("G3", "Newtons andra lag F = m·a och vad den betyder", ["massa", "acceleration"]),
        ("G4", "Newtons tredje lag, kraft och motkraft", ["motsatt riktning", "lika stor"]),
        ("G5", "Tyngdkraften och g", ["tyngdkraft", "9,8"]),
        ("G6", "Friktion och normalkraft", ["friktion", "normalkraft"]),
    ],
    outside=["rörelsemängd", "impuls", "gravitationslagen", "cirkelrörelse", "arbete och effekt"],
)

H["ho-hi-medeltid"] = dict(
    subject="Historia", grade="", grade_ok=None, max_q=None, topic="Medeltiden i Sverige",
    pages=[
        "Medeltiden i Sverige\nMedeltiden i Sverige räknas ofta från omkring år 1050 till 1520. Under den här tiden blev "
        "Sverige kristet, ett kungarike med lagar som gällde hela riket, och de första städerna växte fram.",
        "Kyrkans makt\nKyrkan byggde kyrkor i nästan varje socken och tog ut tionde, en tiondel av böndernas skörd. "
        "Klostren skötte sjukvård och undervisning. Kyrkan blev en av de största jordägarna i landet.",
        "Ståndssamhället\nSamhället delades in i fyra stånd: adel, präster, borgare och bönder. Adeln slapp betala skatt "
        "mot att de ställde upp med en ryttare och häst i krig. Det kallades frälse. De flesta människor var bönder.",
        "Hansan och städerna\nTyska köpmän från Hansan styrde mycket av handeln runt Östersjön. Visby och Stockholm blev "
        "viktiga handelsstäder. Sverige sålde järn, koppar och smör och köpte salt, tyg och vin.",
        "Digerdöden\nÅr 1350 kom pesten, digerdöden, till Sverige. Ungefär en tredjedel av befolkningen dog. Många gårdar "
        "blev öde, och de bönder som överlevde kunde ibland få bättre villkor eftersom det var brist på arbetskraft.",
        "Kalmarunionen\nÅr 1397 enades Danmark, Norge och Sverige i Kalmarunionen under en gemensam regent, drottning "
        "Margareta. Många i Sverige var missnöjda med danska fogdar och höga skatter, och unionen bröts slutligen 1523 "
        "när Gustav Vasa blev kung.",
    ],
    formats=[("docx", [0, 1, 2, 3, 4, 5])],
    goals=[
        ("G1", "Vad som förändrades i Sverige under medeltiden", ["kristet", "städer"]),
        ("G2", "Kyrkans makt och tionde", ["kyrkan", "tionde"]),
        ("G3", "Ståndssamhället och frälse", ["stånd", "frälse", "adel"]),
        ("G4", "Hansan och handeln", ["hansan", "handel"]),
        ("G5", "Digerdöden och dess följder", ["digerdöden", "pest", "tredjedel"]),
        ("G6", "Kalmarunionen och varför den bröts", ["kalmarunionen", "1397", "gustav vasa"]),
    ],
    outside=["vikingatiden", "reformationen i detalj", "stockholms blodbad", "korstågen", "riddarborgar i europa"],
)

H["ho-tunn-separation"] = dict(
    subject="Kemi", grade="", grade_ok=None, max_q=6, topic="Separationsmetoder",
    pages=[
        "Att skilja ämnen åt\nEn blandning kan delas upp med olika metoder. Filtrering skiljer en fast substans från en "
        "vätska, till exempel sand från vatten. Indunstning används när ett ämne är löst i vatten: vattnet får avdunsta "
        "och saltet blir kvar. Destillation skiljer vätskor åt genom att de har olika kokpunkt.",
    ],
    formats=[("photo", [0])],
    goals=[
        ("G1", "Filtrering", ["filtrering", "fast"]),
        ("G2", "Indunstning", ["indunstning", "avdunsta"]),
        ("G3", "Destillation och kokpunkt", ["destillation", "kokpunkt"]),
    ],
    outside=["kromatografi", "centrifugering", "magnetisk separation", "dekantering"],
)

# O57 (D162): fyra prov till så att första meningen mäts på över 100 frågor som Kevin inte har sett.
H["o57-tk-konstruktioner"] = dict(
    subject="Teknik", grade="", grade_ok=None, max_q=None, topic="Hållfasta konstruktioner",
    pages=[
        "Konstruktioner\nEn konstruktion ska klara de krafter den utsätts för. De vanligaste påfrestningarna är tryck, "
        "drag, böjning och vridning. En pelare utsätts för tryck, en vajer i en kran för drag.",
        "Profiler och form\nEn I-balk och ett rör är starka i förhållande till hur mycket material de innehåller, "
        "eftersom materialet sitter långt från mitten där påfrestningen är störst vid böjning. Därför används rör i "
        "cykelramar och I-balkar i hus.",
        "Trianglar\nEn fyrkantig ram kan tryckas snett, men en triangel behåller sin form. Därför förstärker man "
        "konstruktioner med diagonala stag, så kallade fackverk, till exempel i elstolpar, kranar och broar.",
        "Broar\nEn balkbro vilar på stöd och böjs av lasten. En valvbro leder trycket ut i fästena på sidorna, därför "
        "kan den byggas av sten. En hängbro har kablar som hänger mellan höga torn och bär vägbanan med drag.",
        "Material\nBetong tål tryck bra men drag dåligt. Därför gjuter man in armeringsjärn av stål, som tål drag. "
        "Trä är lätt och starkt längs fibrerna. Stål är starkt men tungt och måste skyddas mot rost.",
    ],
    formats=[("photo", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "Påfrestningarna tryck, drag, böjning och vridning", ["tryck", "drag", "böjning"]),
        ("G2", "Varför rör och I-balkar är starka", ["i-balk", "rör"]),
        ("G3", "Trianglar och fackverk", ["triangel", "fackverk"]),
        ("G4", "Balkbro, valvbro och hängbro", ["balkbro", "valvbro", "hängbro"]),
        ("G5", "Armerad betong och materialval", ["betong", "armering"]),
    ],
    outside=["hållfasthetsberäkning", "skyskrapor", "jordbävningssäkring", "kompositmaterial"],
)

H["o57-ke-syror"] = dict(
    subject="Kemi", grade="åk 8", grade_ok=["åk 8", "åk8", "y8", "årskurs 8"], max_q=None, topic="Syror och baser",
    pages=[
        "Kemi åk 8 – Syror och baser\nEn syra avger vätejoner (H⁺) när den löses i vatten. Exempel är saltsyra, "
        "svavelsyra och ättiksyra. En bas tar upp vätejoner eller bildar hydroxidjoner (OH⁻) i vatten, till exempel "
        "natriumhydroxid och ammoniak.",
        "pH-skalan\npH-skalan går från 0 till 14. pH 7 är neutralt. Under 7 är lösningen sur och över 7 är den basisk. "
        "Ett steg på skalan betyder tio gånger så många vätejoner, så pH 3 är tio gånger surare än pH 4.",
        "Indikatorer\nEn indikator byter färg beroende på pH. BTB är gul i sur lösning, grön i neutral och blå i basisk. "
        "Rödkålssaft kan också användas som indikator.",
        "Neutralisation\nNär en syra och en bas blandas i rätt mängd tar de ut varandra. Vätejonerna och hydroxidjonerna "
        "bildar vatten, och kvar blir ett salt. Saltsyra och natriumhydroxid ger vatten och koksalt.",
        "Syror i vardagen\nMagsäcken innehåller saltsyra som hjälper till att bryta ner maten. Surt regn bildas när "
        "svaveldioxid och kväveoxider från förbränning löser sig i regnvatten, och det kan skada sjöar och skog. "
        "Man kalkar sjöar för att höja pH.",
    ],
    formats=[("docx", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "Vad syror och baser är (vätejoner, hydroxidjoner)", ["vätejoner", "hydroxidjoner"]),
        ("G2", "pH-skalan och tiogångersregeln", ["ph", "neutral", "tio gånger"]),
        ("G3", "Indikatorer och BTB", ["indikator", "btb"]),
        ("G4", "Neutralisation och salt", ["neutralisation", "salt", "vatten"]),
        ("G5", "Surt regn och kalkning", ["surt regn", "kalk"]),
    ],
    outside=["buffertlösningar", "titrering", "oxidation", "joniseringsenergi"],
)

H["o57-ma-procent"] = dict(
    subject="Matematik", grade="", grade_ok=None, max_q=None, topic="Procent och förändringsfaktor",
    pages=[
        "Procent\nProcent betyder hundradelar. 25 % är samma sak som 0,25 eller en fjärdedel. För att räkna ut 25 % av "
        "80 kronor multiplicerar man 0,25 med 80 och får 20 kronor.",
        "Procentenheter\nOm räntan går från 2 % till 3 % har den ökat med en procentenhet, men med 50 procent. "
        "Procentenheter är skillnaden mellan två procenttal, procent är den relativa förändringen.",
        "Förändringsfaktor\nEn ökning med 20 % ger förändringsfaktorn 1,20 och en minskning med 20 % ger 0,80. "
        "Det nya värdet är det gamla värdet gånger förändringsfaktorn. En jacka för 500 kr som sänks med 20 % kostar "
        "500 · 0,80 = 400 kr.",
        "Upprepade förändringar\nOm priset först höjs med 10 % och sedan sänks med 10 % blir det inte samma som från "
        "början: 1,10 · 0,90 = 0,99, alltså en minskning med 1 %. Vid flera förändringar multiplicerar man "
        "förändringsfaktorerna.",
    ],
    formats=[("pdf", [0, 1, 2, 3])],
    goals=[
        ("G1", "Procent som hundradelar och att räkna procent av", ["hundradelar", "0,25"]),
        ("G2", "Skillnaden mellan procent och procentenheter", ["procentenhet"]),
        ("G3", "Förändringsfaktor vid ökning och minskning", ["förändringsfaktor", "1,20", "0,80"]),
        ("G4", "Upprepade förändringar", ["multiplicera", "0,99"]),
    ],
    outside=["exponentialfunktioner", "logaritmer", "promille", "moms"],
)

H["o57-idh-traning"] = dict(
    subject="Idrott och hälsa", grade="", grade_ok=None, max_q=None, topic="Träningslära",
    pages=[
        "Träningslära\nKondition är kroppens förmåga att arbeta länge. När man tränar kondition blir hjärtat starkare och "
        "kan pumpa mer blod per slag, och musklerna blir bättre på att ta upp syre.",
        "Styrka\nStyrketräning gör att musklerna växer och blir starkare. Musklerna byggs upp under vilan efter passet, "
        "inte under själva passet. Därför behöver samma muskelgrupp ofta ett till två dygn av vila.",
        "Uppvärmning\nUppvärmningen höjer kroppstemperaturen och pulsen så att musklerna blir smidigare och mindre "
        "känsliga för skador. Den förbereder också nervsystemet så att rörelserna blir snabbare.",
        "Återhämtning och kost\nSömn, vila och mat behövs för att kroppen ska anpassa sig. Kolhydrater ger energi till "
        "träningen och protein behövs för att bygga upp musklerna. Den som tränar hårt utan vila riskerar överträning.",
    ],
    formats=[("text", [0, 1, 2, 3])],
    goals=[
        ("G1", "Kondition och vad konditionsträning gör", ["kondition", "hjärtat"]),
        ("G2", "Styrketräning och vila", ["styrka", "vila"]),
        ("G3", "Varför man värmer upp", ["uppvärmning", "skador"]),
        ("G4", "Återhämtning, kost och överträning", ["protein", "kolhydrater", "överträning"]),
    ],
    outside=["mjölksyra", "intervallträning i detalj", "dopning", "maxpuls"],
)

H["ho-sh-privatekonomi"] = dict(
    subject="Samhällskunskap", grade="", grade_ok=None, max_q=None, topic="Privatekonomi",
    pages=[
        "Privatekonomi – att ha koll på sina pengar\nEn budget är en plan över inkomster och utgifter under en månad. "
        "Fasta utgifter, som hyra och mobilabonnemang, är lika stora varje månad. Rörliga utgifter, som mat och "
        "nöjen, ändras från månad till månad.",
        "Lön och skatt\nBruttolön är lönen före skatt. Nettolön är det som kommer in på kontot efter att skatten dragits. "
        "Skatten går till kommunen, regionen och staten och betalar till exempel skola, sjukvård och vägar.",
        "Sparande och ränta\nDen som sparar på ett konto får ränta. Med ränta på ränta växer sparandet snabbare ju längre "
        "tid pengarna får ligga. En buffert är pengar som sparas för oväntade utgifter, till exempel en trasig telefon.",
        "Lån och krediter\nDen som lånar pengar betalar ränta till banken. Ett sms-lån eller en kredit i en webbutik kan "
        "ha mycket hög ränta och avgifter. Om man inte betalar i tid kan skulden gå till Kronofogden och man kan få "
        "en betalningsanmärkning, som gör det svårt att få hyra en lägenhet eller ta lån.",
    ],
    formats=[("text", [0, 1, 2, 3])],
    goals=[
        ("G1", "Budget, fasta och rörliga utgifter", ["budget", "fasta", "rörliga"]),
        ("G2", "Bruttolön, nettolön och skatt", ["bruttolön", "nettolön", "skatt"]),
        ("G3", "Sparande, ränta på ränta och buffert", ["ränta på ränta", "buffert"]),
        ("G4", "Lån, sms-lån och betalningsanmärkning", ["sms-lån", "kronofogden", "betalningsanmärkning"]),
    ],
    outside=["aktier", "fonder", "pension", "inflation", "bolån"],
)
