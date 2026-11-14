"""O63: sex nya påhittade hållout-prov för svarskvaliteten, skrivna av Oscar (QA) 2026-11-14. Aldrig elevtext.
Samma format som materials_holdout.H. Ligger utanför exams.json, så att Kevins scripts/k45-measure.py inte mäter på dem.
"""

H3 = {}

H3["h3-hi-franska-revolutionen"] = dict(
    subject="Historia", grade="åk 8", grade_ok=["åk 8", "åk8", "årskurs 8"], max_q=None, topic="Franska revolutionen",
    pages=[
        "Historia åk 8 – Franska revolutionen 1789\nFöre revolutionen var Frankrike indelat i tre stånd. Präster var första "
        "ståndet och adeln andra ståndet. Alla andra, bönder, hantverkare och borgare, var tredje ståndet. Tredje ståndet "
        "var nästan hela befolkningen men betalade nästan alla skatter.",
        "Orsaker\nStaten var nära konkurs efter dyra krig, bland annat stödet till den amerikanska revolutionen. Dåliga "
        "skördar 1788 gjorde brödet så dyrt att många svalt. Upplysningens tänkare, som Rousseau, menade att makten "
        "borde komma från folket och inte från kungen.",
        "Revolutionen börjar\nKung Ludvig XVI kallade in generalständerna 1789 för att få mer skatt. Tredje ståndet "
        "bröt sig ut och bildade nationalförsamlingen. Den 14 juli 1789 stormade folket i Paris fängelset Bastiljen, "
        "som var en symbol för kungens makt.",
        "Deklarationen och terrorn\nI augusti 1789 antogs deklarationen om människans och medborgarens rättigheter: alla "
        "föds fria och lika i rättigheter. 1793 avrättades kungen. Under skräckväldet 1793–1794 lät Robespierre avrätta "
        "tusentals människor som ansågs vara revolutionens fiender.",
        "Följder\nRevolutionen spred idéerna frihet, jämlikhet och broderskap i Europa. 1799 tog generalen Napoleon "
        "Bonaparte makten, och 1804 krönte han sig till kejsare.",
    ],
    formats=[("photo", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "De tre stånden och skattebördan", ["stånd", "adel", "präst", "skatt"]),
        ("G2", "Orsakerna: statsskuld, svält och upplysningen", ["konkurs", "bröd", "upplysning", "rousseau"]),
        ("G3", "Generalständerna, nationalförsamlingen och Bastiljen", ["generalständerna", "nationalförsamling", "bastiljen"]),
        ("G4", "Deklarationen om mänskliga rättigheter", ["deklarationen", "rättigheter", "fria och lika"]),
        ("G5", "Skräckväldet och Robespierre", ["skräckvälde", "robespierre", "avrätta"]),
        ("G6", "Följderna och Napoleon", ["napoleon", "frihet, jämlikhet"]),
    ],
    outside=["giljotin", "marie antoinette", "versailles", "waterloo", "jakobiner"],
)

H3["h3-ke-atomer"] = dict(
    subject="Kemi", grade="åk 7", grade_ok=["åk 7", "åk7", "årskurs 7"], max_q=None, topic="Atomer och periodiska systemet",
    pages=[
        "Kemi åk 7 – Atomer\nAllt omkring oss är uppbyggt av atomer. En atom har en kärna med protoner, som är positivt "
        "laddade, och neutroner, som saknar laddning. Runt kärnan rör sig elektroner, som är negativt laddade.",
        "Grundämnen\nEtt grundämne består av bara ett slags atomer. Antalet protoner, atomnumret, bestämmer vilket "
        "grundämne det är: väte har 1 proton, kol har 6 och syre har 8. En atom har lika många elektroner som protoner "
        "och är därför oladdad.",
        "Periodiska systemet\nI periodiska systemet står grundämnena i ordning efter atomnummer. Ämnen i samma grupp, "
        "alltså samma kolumn, har lika många elektroner i det yttersta skalet och reagerar därför på liknande sätt. "
        "Ädelgaserna längst till höger har fullt yttersta skal och reagerar nästan inte alls.",
        "Molekyler och kemiska föreningar\nNär atomer binds ihop bildas molekyler. En kemisk förening består av två "
        "eller flera olika grundämnen, till exempel vatten, H2O, där två väteatomer sitter ihop med en syreatom.",
    ],
    formats=[("docx", [0, 1, 2, 3])],
    goals=[
        ("G1", "Atomens byggnad: protoner, neutroner, elektroner", ["proton", "neutron", "elektron"]),
        ("G2", "Atomnummer och grundämne", ["atomnummer", "grundämne"]),
        ("G3", "Varför atomen är oladdad", ["oladdad", "lika många"]),
        ("G4", "Grupper i periodiska systemet och yttersta skalet", ["grupp", "yttersta skal"]),
        ("G5", "Ädelgaser", ["ädelgas"]),
        ("G6", "Molekyler och kemiska föreningar", ["molekyl", "förening", "h2o"]),
    ],
    outside=["isotop", "jon", "kovalent", "metall", "radioaktiv"],
)

H3["h3-sh-riksdagen"] = dict(
    subject="Samhällskunskap", grade="åk 9", grade_ok=["åk 9", "åk9", "årskurs 9"], max_q=None, topic="Demokrati och riksdagen",
    pages=[
        "Samhällskunskap åk 9 – Så styrs Sverige\nSverige är en representativ demokrati. Det betyder att medborgarna "
        "väljer politiker som fattar beslut åt dem. Val till riksdagen, regionerna och kommunerna hålls vart fjärde år.",
        "Riksdagen och regeringen\nRiksdagen har 349 ledamöter och stiftar lagar, beslutar om statens budget och "
        "granskar regeringen. Regeringen leds av statsministern och styr landet genom att genomföra riksdagens beslut. "
        "Riksdagen kan avsätta en minister genom misstroendeförklaring.",
        "Maktdelning\nMakten är delad så att ingen får för mycket. Riksdagen stiftar lagarna, regeringen styr och "
        "domstolarna dömer självständigt. Fria medier granskar makthavarna och kallas ibland den tredje statsmakten.",
        "Fyraprocentsspärren\nEtt parti måste få minst 4 procent av rösterna i hela landet för att komma in i riksdagen. "
        "Spärren ska göra det lättare att bilda en stabil regering, men den gör också att små partier får svårare att "
        "komma in.",
    ],
    formats=[("pdf", [0, 1, 2, 3])],
    goals=[
        ("G1", "Representativ demokrati och val vart fjärde år", ["representativ", "fjärde år", "val"]),
        ("G2", "Riksdagens uppgifter", ["riksdagen", "lagar", "budget", "granskar"]),
        ("G3", "Regeringen och misstroendeförklaring", ["regeringen", "statsminister", "misstroende"]),
        ("G4", "Maktdelning och mediernas roll", ["maktdelning", "domstol", "medier"]),
        ("G5", "Fyraprocentsspärren, för- och nackdelar", ["4 procent", "spärr"]),
    ],
    outside=["eu", "kommunfullmäktige", "grundlag", "tryckfrihet", "monarki"],
)

H3["h3-en-climate"] = dict(
    subject="Engelska", grade="åk 8", grade_ok=["åk 8", "åk8", "årskurs 8"], max_q=None, topic="Climate change (reading)",
    pages=[
        "English, year 8 – Reading: A warmer world\nThe Earth's climate is getting warmer. Since about 1850 the average "
        "temperature has risen by roughly 1.2 degrees. Most scientists agree that humans are the main cause.",
        "The greenhouse effect\nGases such as carbon dioxide trap heat in the atmosphere, a bit like the glass roof of a "
        "greenhouse. When we burn coal, oil and gas, we release more carbon dioxide, so more heat is trapped.",
        "Consequences\nAs the ice in Greenland and Antarctica melts, sea levels rise, which threatens cities near the "
        "coast. Heatwaves, droughts and heavy rain are becoming more common. Some animals, like polar bears, are losing "
        "their habitat.",
        "What can we do?\nCountries have promised to cut their emissions in the Paris Agreement from 2015. People can "
        "help too, for example by taking the train instead of flying, eating less meat and wasting less food.",
    ],
    formats=[("text", [0, 1, 2, 3])],
    goals=[
        ("G1", "How much warmer and why (humans)", ["1.2", "1,2", "humans", "människ"]),
        ("G2", "The greenhouse effect and carbon dioxide", ["greenhouse", "växthus", "carbon dioxide", "koldioxid"]),
        ("G3", "Melting ice and rising sea levels", ["sea level", "havsnivå", "greenland", "grönland"]),
        ("G4", "Extreme weather and habitats", ["heatwave", "värmebölj", "drought", "torka", "polar bear", "isbjörn"]),
        ("G5", "The Paris Agreement and what people can do", ["paris", "train", "tåg", "meat", "kött"]),
    ],
    outside=["methane", "metan", "kyoto", "electric car", "elbil"],
)

H3["h3-ma-pythagoras"] = dict(
    subject="Matematik", grade="åk 9", grade_ok=["åk 9", "åk9", "årskurs 9"], max_q=None, topic="Pythagoras sats och area",
    pages=[
        "Matematik åk 9 – Pythagoras sats\nI en rätvinklig triangel kallas den längsta sidan hypotenusa. Den står "
        "mitt emot den räta vinkeln. De två andra sidorna kallas kateter.",
        "Satsen\nPythagoras sats säger att a² + b² = c², där a och b är kateterna och c är hypotenusan. Exempel: om "
        "kateterna är 3 cm och 4 cm blir c² = 9 + 16 = 25, så hypotenusan är 5 cm.",
        "Använda satsen baklänges\nOm man vet hypotenusan och en katet kan man räkna ut den andra kateten: a² = c² − b². "
        "Satsen gäller bara i rätvinkliga trianglar. Om a² + b² = c² stämmer för en triangel, så är den rätvinklig.",
        "Area\nArean av en triangel är basen gånger höjden delat med 2, A = b · h / 2. Arean av en cirkel är "
        "A = π · r², där r är radien och π är ungefär 3,14.",
    ],
    formats=[("pdf", [0, 1, 2, 3])],
    goals=[
        ("G1", "Hypotenusa och kateter", ["hypotenusa", "katet"]),
        ("G2", "Pythagoras sats och exemplet 3–4–5", ["a² + b² = c²", "a i kvadrat", "kvadrat", "5 cm"]),
        ("G3", "Räkna ut en katet", ["c² − b²", "katet"]),
        ("G4", "Bara rätvinkliga trianglar, och omvändningen", ["rätvinklig"]),
        ("G5", "Area av triangel och cirkel", ["area", "π", "pi", "radie"]),
    ],
    outside=["sinus", "cosinus", "volym", "omkrets", "trigonometri"],
)

H3["h3-bi-anteckningar"] = dict(
    subject="Biologi", grade="", grade_ok=None, max_q=None, topic="Ekologi (slarviga anteckningar)",
    pages=[
        "bio ekologi anteckn. 12/10\n- ekosystem = alla levande + icke lev. (ljus, vatten, jord) på ett ställe\n"
        "- producenter = växter, gör energi m fotosyntes -> solenergi blir socker\n- konsumenter äter andra. "
        "1:a ordn äter växter (t ex hare), 2:a ordn äter 1:a (räv)",
        "näringskedja: gräs -> hare -> räv. pilen = energin går vidare\nbara ca 10% av energin går vidare till nästa "
        "steg!! resten blir värme / rörelse. därför få rovdjur högst upp\nnäringsväv = många kedjor ihop",
        "nedbrytare (svampar, bakterier, maskar) bryter ner döda växter o djur -> näring tillbaka till jorden\n"
        "utan dem tar näringen slut ?? (läraren: JA viktigt på provet)",
        "om ett djur försvinner påverkas hela väven, t ex om rävarna dör -> fler harar -> mindre gräs\n"
        "fotosyntes: koldioxid + vatten + ljus -> socker + syre",
    ],
    formats=[("text", [0, 1, 2, 3])],
    goals=[
        ("G1", "Ekosystem: levande och icke levande", ["ekosystem", "icke levande", "levande"]),
        ("G2", "Producenter och fotosyntes", ["producent", "fotosyntes"]),
        ("G3", "Konsumenter av första och andra ordningen", ["konsument", "ordningen", "ordning"]),
        ("G4", "Näringskedja och 10 % av energin", ["näringskedja", "10", "energi"]),
        ("G5", "Nedbrytare och kretsloppet av näring", ["nedbrytare", "svamp", "bakterie"]),
        ("G6", "Näringsväv och vad som händer om ett djur försvinner", ["näringsväv", "försvinn", "rävar"]),
    ],
    outside=["kväve", "biologisk mångfald", "invasiv", "pollinering", "fotosyntesens ljusreaktion"],
)
