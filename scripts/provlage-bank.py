"""D87: builds scripts/provlage-bank.json, the Provläge test bank (own cases, written for this bank; none of them is a
prompt example). Spoken cases for åk 7-9 and gymnasiet 1-3 in NO, SO, Språk and Matte: bare key words, half
sentences, follow-ups that need the earlier turns, misheard subject words and common exam questions.
Run: python -I scripts/provlage-bank.py  (writes the JSON next to it)."""
import json, os

def prof(grade, subject, extra="Förklaringar: mellanlånga förklaringar."):
    return f"Årskurs: {grade}. Ämne: {subject}. {extra}"

cases = []
def add(grade, subject, kind, q, expect, context=None, profile=None):
    cases.append({
        "id": f"pl-{len(cases) + 1:03d}", "grade": grade, "subject": subject, "kind": kind, "q": q,
        "expect": expect, "context": context or [], "profile": profile or prof(grade, subject),
    })

T = lambda q, a: {"q": q, "a": a}

# ---------------- NO: biologi ----------------
B7, B9, BG1 = "Åk 7", "Åk 9", "Gymnasiet 1, kurs Biologi 1"
for g, q, e in [
    (B7, "fotosyntes", "ljusenergi, koldioxid och vatten blir socker och syre, i kloroplasterna"),
    (B7, "cellen", "cellens delar: cellmembran, cellkärna, cytoplasma; växtceller har cellvägg och kloroplaster"),
    (B9, "cellandning", "glukos och syre blir koldioxid, vatten och energi (ATP) i mitokondrierna"),
    (B9, "evolution", "naturligt urval, variation, ärftlighet, anpassning över många generationer"),
    (B9, "ekosystem", "producenter, konsumenter, nedbrytare, energiflöde och kretslopp"),
    (BG1, "DNA", "dubbelspiral av nukleotider med baserna A T C G, bär genetisk information, gener kodar för proteiner"),
    (BG1, "mitos", "celldelning till två identiska dotterceller, faser profas metafas anafas telofas"),
    (B9, "immunförsvaret", "ospecifikt och specifikt försvar, vita blodkroppar, antikroppar, minnesceller, vaccin"),
]:
    add(g, "Biologi", "term", q, e)
for g, q, e in [
    (B7, "vad är skillnaden mellan", "half sentence with context about plant and animal cells", ),
]:
    pass
add(B7, "Biologi", "half", "och vad behöver växten för att", "vad växten behöver för fotosyntes: ljus, vatten, koldioxid",
    [T("fotosyntes", "Fotosyntes är när växter med hjälp av ljusenergi gör socker av koldioxid och vatten, och syre bildas.")])
add(B9, "Biologi", "half", "eh skillnaden mellan mitos och", "skillnaden mellan mitos och meios")
add(B9, "Biologi", "followup", "och cellandning då?", "cellandning: glukos och syre till koldioxid, vatten, energi; motsatsen till fotosyntesen",
    [T("fotosyntes", "Fotosyntes är när växter med ljusenergi bygger glukos av koldioxid och vatten, och syre släpps ut.")])
add(B9, "Biologi", "followup", "varför då?", "varför växter behöver ljus: ljusenergin driver fotosyntesen, utan ljus ingen glukos",
    [T("varför växer inte växter i mörker", "Växter som står i mörker kan inte göra fotosyntes, så de får ingen ny energi.")])
add(BG1, "Biologi", "followup", "och den andra?", "den andra typen av celldelning: meios, könsceller, halverat kromosomtal",
    [T("vilka två typer av celldelning finns det", "Det finns två typer av celldelning: mitos och meios. Mitos ger två identiska celler för tillväxt.")])
add(B9, "Biologi", "followup", "ge ett exempel", "ett exempel på naturligt urval, t.ex. björkmätare eller antibiotikaresistens",
    [T("naturligt urval", "Naturligt urval betyder att individer med egenskaper som passar miljön överlever och får fler avkommor.")])
add(B7, "Biologi", "misheard", "fo to syn tes", "fotosyntes")
add(B9, "Biologi", "misheard", "ri bo so mer", "ribosomer: där proteiner byggs i cellen")
add(BG1, "Biologi", "misheard", "pro tein syntes", "proteinsyntes: transkription och translation, mRNA, ribosomer")
add(B9, "Biologi", "misheard", "nat urligt ur val", "naturligt urval")
for g, q, e in [
    (B9, "förklara varför antibiotika inte hjälper mot virus", "antibiotika angriper bakteriers egna strukturer, virus saknar dem och förökar sig i värdceller"),
    (B7, "vad är skillnaden mellan en växtcell och en djurcell", "växtcell har cellvägg, kloroplaster, stor vakuol"),
    (BG1, "hur fungerar ett vaccin", "försvagat eller delar av smittämnet, immunförsvaret bildar antikroppar och minnesceller"),
    (B9, "vad händer i en näringskedja om rovdjuren försvinner", "bytesdjuren ökar, växterna minskar, obalans"),
]:
    add(g, "Biologi", "exam", q, e)

# ---------------- NO: kemi ----------------
K8, KG1, KG2 = "Åk 8", "Gymnasiet 1, kurs Kemi 1", "Gymnasiet 2, kurs Kemi 2"
for g, q, e in [
    (K8, "periodiska systemet", "grundämnen ordnade efter atomnummer, perioder och grupper, liknande egenskaper i grupper"),
    (K8, "atom", "kärna med protoner och neutroner, elektroner i skal"),
    (KG1, "jonbindning", "metall lämnar elektroner till icke-metall, positiva och negativa joner attraheras, t.ex. NaCl"),
    (KG1, "kovalent bindning", "atomer delar elektronpar, t.ex. vatten, polär och opolär"),
    (KG1, "substansmängd", "mol, Avogadros tal, n = m/M"),
    (K8, "syror och baser", "syror avger vätejoner, baser tar upp, pH-skalan, neutralisation"),
    (KG2, "jämvikt", "reaktion åt båda håll, lika hastighet, Le Chateliers princip"),
    (KG2, "buffert", "svag syra och dess korresponderande bas, motverkar pH-ändring"),
]:
    add(g, "Kemi", "term", q, e)
add(K8, "Kemi", "misheard", "perifera systemet", "tolkas som periodiska systemet i kemi")
add(K8, "Kemi", "misheard", "neutra lisation", "neutralisation: syra plus bas ger salt och vatten")
add(KG1, "Kemi", "misheard", "ele ktro negativitet", "elektronegativitet: hur starkt en atom drar till sig elektroner")
add(KG2, "Kemi", "misheard", "kata lysator", "katalysator: sänker aktiveringsenergin, förbrukas inte")
add(K8, "Kemi", "half", "varför är vatten så", "varför vatten är polärt eller ett bra lösningsmedel")
add(KG1, "Kemi", "half", "vad är skillnaden på jon och", "skillnaden mellan jonbindning och kovalent bindning eller jon och atom")
add(KG1, "Kemi", "followup", "och metallbindning då?", "metallbindning: elektronmoln, positiva metalljoner, leder ström",
    [T("jonbindning", "Jonbindning är när en metall lämnar elektroner till en icke-metall och de laddade jonerna dras till varandra.")])
add(K8, "Kemi", "followup", "varför då?", "varför pH under sju är surt: hög koncentration vätejoner/oxoniumjoner",
    [T("vad betyder pH tre", "pH tre betyder att lösningen är sur, eftersom pH under sju är surt.")])
add(KG2, "Kemi", "followup", "och om man höjer temperaturen?", "Le Chatelier: jämvikten förskjuts åt det endoterma hållet",
    [T("vad händer med jämvikten om man ökar trycket", "Om trycket ökar förskjuts jämvikten åt den sida som har färre gasmolekyler.")])
for g, q, e in [
    (KG1, "hur många mol är tjugo gram natriumhydroxid", "molmassa ca 40 g/mol, ca 0,5 mol"),
    (K8, "vad händer när man blandar en syra och en bas", "neutralisation, salt och vatten"),
    (KG1, "förklara varför salt löser sig i vatten", "vattnets polära molekyler omger jonerna, hydratisering"),
    (KG2, "vad är skillnaden mellan en stark och en svag syra", "stark protolyseras fullständigt, svag delvis"),
]:
    add(g, "Kemi", "exam", q, e)

# ---------------- NO: fysik ----------------
F8, F9, FG1 = "Åk 8", "Åk 9", "Gymnasiet 1, kurs Fysik 1"
for g, q, e in [
    (F8, "densitet", "massa per volym, rho = m/V, kg per kubikmeter"),
    (F9, "ohms lag", "U = R gånger I, spänning, resistans, ström"),
    (F9, "tryck", "kraft per area, p = F/A, pascal"),
    (FG1, "newtons andra lag", "F = m gånger a, kraft, massa, acceleration"),
    (F9, "energiprincipen", "energi kan inte skapas eller förstöras, bara omvandlas"),
    (FG1, "rörelseenergi", "Ek = mv²/2, beror på massa och hastighet"),
    (F8, "ljud", "longitudinella vågor, behöver medium, frekvens och tonhöjd"),
]:
    add(g, "Fysik", "term", q, e)
add(F9, "Fysik", "misheard", "gra vi ta tion", "gravitation: dragningskraft mellan massor")
add(FG1, "Fysik", "misheard", "acce le ration", "acceleration: hastighetsändring per tid, m/s²")
add(F9, "Fysik", "misheard", "ele ktrisk resi stans", "resistans: motstånd mot ström, ohm")
add(F8, "Fysik", "half", "varför flyter en båt fast den är", "flytkraft, Arkimedes princip, båtens medeldensitet lägre än vattnets")
add(FG1, "Fysik", "followup", "och den tredje?", "Newtons tredje lag: kraft och motkraft",
    [T("newtons första lag", "Newtons första lag säger att en kropp behåller sin hastighet om ingen resulterande kraft verkar."),
     T("och den andra?", "Newtons andra lag är F lika med m gånger a: kraften ger massan en acceleration.")])
add(F9, "Fysik", "followup", "räkna ut det", "U = R·I med givna värden från tidigare tur: 2 A och 6 ohm ger 12 V",
    [T("en lampa har resistansen sex ohm och strömmen är två ampere vad är spänningen", "Använd Ohms lag, U är lika med R gånger I.")])
add(F8, "Fysik", "followup", "varför då?", "varför ljud inte går i vakuum: behöver partiklar att svänga",
    [T("kan ljud gå i rymden", "Nej, ljud kan inte gå i rymden.")])
for g, q, e in [
    (F9, "vad är skillnaden mellan serie och parallellkoppling", "serie: samma ström, delad spänning; parallell: samma spänning, delad ström"),
    (FG1, "hur långt faller en sten på två sekunder", "s = gt²/2 ≈ 19,6 m"),
    (F8, "varför är det kallare på vintern", "jordaxelns lutning, solinstrålning i lägre vinkel, kortare dagar"),
]:
    add(g, "Fysik", "exam", q, e)

# ---------------- SO ----------------
H8, H9, HG1 = "Åk 8", "Åk 9", "Gymnasiet 1, kurs Historia 1b"
for g, q, e in [
    (H8, "franska revolutionen", "1789, orsaker: ojämlikhet, skulder, upplysning; följder: republik, mänskliga rättigheter"),
    (H8, "industriella revolutionen", "Storbritannien 1700-1800-tal, ångmaskin, fabriker, urbanisering"),
    (H9, "första världskriget", "1914-1918, allianser, skotten i Sarajevo, skyttegravskrig, Versaillesfreden"),
    (H9, "kalla kriget", "USA mot Sovjet, kapitalism mot kommunism, kapprustning, Berlinmuren"),
    (HG1, "upplysningen", "1700-tal, förnuft, Voltaire, Rousseau, maktdelning"),
    (H9, "förintelsen", "nazisternas folkmord på sex miljoner judar, rasideologi, koncentrationsläger"),
]:
    add(g, "Historia", "term", q, e)
add(H9, "Historia", "followup", "och andra världskriget då?", "andra världskriget 1939-1945, orsaker och följder, kopplat till första",
    [T("första världskriget", "Första världskriget pågick 1914 till 1918 och slutade med Versaillesfreden som straffade Tyskland hårt.")])
add(H8, "Historia", "followup", "varför då?", "varför franska revolutionen började: ojämlikhet, statsskuld, svält, nya idéer",
    [T("när började franska revolutionen", "Franska revolutionen började 1789 när folket stormade Bastiljen.")])
add(HG1, "Historia", "misheard", "re nässansen", "renässansen: 1400-1500-tal, Italien, humanism, konst och vetenskap")
add(H9, "Historia", "misheard", "kall a kriget", "kalla kriget")
add(H8, "Historia", "half", "vad hände efter att napoleon", "Napoleons fall, Wienkongressen 1815")
add(H9, "Historia", "exam", "vilka var orsakerna till första världskriget", "militarism, allianser, imperialism, nationalism, skotten i Sarajevo")
add(HG1, "Historia", "exam", "jämför demokratin i antikens aten med dagens", "direktdemokrati, bara fria män, idag representativ och allmän rösträtt")

S8, S9, SG1 = "Åk 8", "Åk 9", "Gymnasiet 1, kurs Samhällskunskap 1b"
for g, q, e in [
    (S9, "demokrati", "folkstyre, fria val, yttrandefrihet, maktdelning, rättsstat"),
    (S9, "riksdagen", "349 ledamöter, stiftar lagar, beslutar om budget, väljs vart fjärde år"),
    (SG1, "inflation", "stigande priser, penningvärdet minskar, Riksbanken styr med räntan"),
    (S8, "mänskliga rättigheter", "FN:s deklaration 1948, universella, yttrandefrihet, rätt till utbildning"),
    (SG1, "ideologier", "liberalism, konservatism, socialism, synen på stat och individ"),
    (S9, "globalisering", "ökad handel och kontakt över gränser, för- och nackdelar"),
]:
    add(g, "Samhällskunskap", "term", q, e)
add(S9, "Samhällskunskap", "followup", "och regeringen då?", "regeringen styr landet, verkställer, statsministern, skillnad mot riksdagen",
    [T("riksdagen", "Riksdagen är Sveriges folkvalda församling som stiftar lagar och beslutar om statens budget.")])
add(SG1, "Samhällskunskap", "followup", "varför då?", "varför höjd ränta minskar inflation: dyrare lån, mindre konsumtion",
    [T("vad gör riksbanken när inflationen är hög", "När inflationen är hög höjer Riksbanken styrräntan.")])
add(S9, "Samhällskunskap", "misheard", "demo kratin", "demokratin")
add(SG1, "Samhällskunskap", "misheard", "ma kt del ning", "maktdelning: lagstiftande, verkställande, dömande makt")
add(S8, "Samhällskunskap", "half", "vad är skillnaden mellan riksdag och", "skillnaden mellan riksdag och regering")
add(S9, "Samhällskunskap", "exam", "förklara hur en lag blir till", "förslag, utredning, remiss, proposition, riksdagen röstar")
add(SG1, "Samhällskunskap", "exam", "vilka för och nackdelar finns med globalisering", "tillväxt, billigare varor; utflyttning av jobb, miljö")

G7, G9 = "Åk 7", "Åk 9"
for g, q, e in [
    (G7, "klimat och väder", "väder är kortsiktigt, klimat är genomsnitt över 30 år"),
    (G9, "växthuseffekten", "gaser som koldioxid håller kvar värme, förstärkt av människan"),
    (G7, "plattektonik", "jordskorpans plattor rör sig, jordbävningar, vulkaner, bergskedjor"),
    (G9, "urbanisering", "fler flyttar till städer, orsaker och följder"),
]:
    add(g, "Geografi", "term", q, e)
add(G9, "Geografi", "followup", "och vad kan man göra åt det?", "minska utsläpp: förnybar energi, mindre fossila bränslen",
    [T("växthuseffekten", "Den förstärkta växthuseffekten beror på att människan släpper ut koldioxid som håller kvar mer värme.")])
add(G7, "Geografi", "misheard", "platt tektonik", "plattektonik")
add(G9, "Geografi", "exam", "varför bor det så många människor nära floder", "vatten, bördig jord, transporter, handel")

R8, R9 = "Åk 8", "Åk 9"
for g, q, e in [
    (R8, "buddhismen", "Buddha, de fyra ädla sanningarna, åttafaldiga vägen, nirvana, återfödelse"),
    (R9, "etik", "läran om rätt och fel, konsekvensetik, pliktetik, dygdetik"),
    (R8, "islam", "Muhammed, Koranen, fem pelare, monoteism"),
]:
    add(g, "Religion", "term", q, e)
add(R9, "Religion", "followup", "och pliktetik?", "pliktetik: handlingen själv, regler och plikter, Kant",
    [T("konsekvensetik", "Konsekvensetik betyder att en handling är rätt om den ger bäst följder för flest.")])
add(R8, "Religion", "misheard", "bud dismen", "buddhismen")

# ---------------- Språk ----------------
SV7, SV9, SVG1 = "Åk 7", "Åk 9", "Gymnasiet 1, kurs Svenska 1"
for g, q, e in [
    (SV9, "argumenterande text", "tes, argument, motargument, slutsats"),
    (SV7, "berättande text", "inledning, handling, konflikt, upplösning, miljö och personer"),
    (SVG1, "retorik", "ethos, pathos, logos, partesläran"),
    (SV9, "metafor", "bildligt uttryck utan som, t.ex. livet är en resa"),
    (SVG1, "novell", "kort berättelse, få personer, ofta öppet slut"),
    (SV9, "källkritik", "äkthet, tid, beroende, tendens"),
]:
    add(g, "Svenska", "term", q, e)
add(SV9, "Svenska", "followup", "och liknelse då?", "liknelse: jämförelse med som, t.ex. stark som en björn",
    [T("metafor", "En metafor är ett bildligt uttryck där man säger att något är något annat, utan ordet som.")])
add(SVG1, "Svenska", "followup", "ge ett exempel", "exempel på pathos, t.ex. känsloladdade ord i ett tal",
    [T("pathos", "Pathos är när talaren väcker känslor hos publiken för att övertyga.")])
add(SVG1, "Svenska", "misheard", "par tes läran", "partesläran: talets delar, ordningen i retoriken")
add(SV9, "Svenska", "misheard", "käll kri tik", "källkritik")
add(SV9, "Svenska", "half", "hur börjar man en argumenterande", "hur man inleder en argumenterande text: väck intresse, presentera tesen")
add(SV9, "Svenska", "exam", "hur skriver man en bra inledning", "fånga läsaren, presentera ämnet eller tesen")
add(SVG1, "Svenska", "exam", "vad kännetecknar romantiken", "känslor, naturen, fantasi, 1800-talets början, reaktion mot upplysningen")

E7, E9, EG1 = "Åk 7", "Åk 9", "Gymnasiet 1, kurs Engelska 5"
for g, q, e in [
    (E9, "present perfect", "have/has + participle, erfarenhet eller något som fortsätter, skillnad mot past simple"),
    (E7, "oregelbundna verb", "verb som inte får -ed, t.ex. go went gone"),
    (EG1, "conditionals", "if-satser, first second third conditional"),
    (E9, "passiv form", "be + participle, the book was written"),
]:
    add(g, "Engelska", "term", q, e)
add(E9, "Engelska", "followup", "och past simple då?", "past simple: avslutad tid i dåtid, yesterday, skillnad mot present perfect",
    [T("present perfect", "Present perfect bildas med have eller has och perfekt particip, som I have eaten.")])
add(EG1, "Engelska", "followup", "och den tredje?", "third conditional: if + had + participle, would have, overkligt i dåtid",
    [T("first conditional", "First conditional är if plus presens och will, för något som kan hända."),
     T("och second?", "Second conditional är if plus imperfekt och would, för något overkligt nu.")])
add(E9, "Engelska", "misheard", "pre sent per fekt", "present perfect")
add(E7, "Engelska", "exam", "när använder man some och any", "some i jakande, any i frågor och nekande")

# ---------------- Matte ----------------
M7, M9, MG1, MG2, MG3 = "Åk 7", "Åk 9", "Gymnasiet 1, kurs Matematik 1c", "Gymnasiet 2, kurs Matematik 2c", "Gymnasiet 3, kurs Matematik 3c"
for g, q, e in [
    (M9, "pythagoras", "a² + b² = c² i rätvinklig triangel, c är hypotenusan, exempel 3-4-5"),
    (M7, "procent", "hundradelar, del delat med det hela, procentuell förändring"),
    (M9, "linjär funktion", "y = kx + m, k lutning, m skärning med y-axeln"),
    (MG1, "ekvation", "likhet med obekant, gör samma sak på båda sidor"),
    (MG2, "andragradsekvation", "pq-formeln, x² + px + q = 0"),
    (MG3, "derivata", "förändringshastighet, lutningen på tangenten, deriveringsregler"),
    (MG3, "integral", "area under kurva, primitiv funktion, motsatsen till derivata"),
    (M9, "sannolikhet", "gynnsamma utfall delat med möjliga, mellan noll och ett"),
    (MG2, "logaritmer", "logaritmen är exponenten, lg 100 = 2"),
    (M7, "bråk", "täljare och nämnare, förlänga och förkorta"),
]:
    add(g, "Matematik", "term", q, e)
add(M9, "Matematik", "followup", "och hur räknar man ut den andra sidan?", "kateter: a² = c² − b², roten ur",
    [T("pythagoras sats", "Pythagoras sats säger att i en rätvinklig triangel är a i kvadrat plus b i kvadrat lika med c i kvadrat.")])
add(MG3, "Matematik", "followup", "och andraderivatan då?", "andraderivatan: derivatan av derivatan, maximum/minimum, konkav/konvex",
    [T("derivata", "Derivatan beskriver hur snabbt en funktion förändras, alltså lutningen på kurvan i en punkt.")])
add(M9, "Matematik", "followup", "varför då?", "varför k är lutningen: y ökar k för varje steg i x",
    [T("vad betyder k i y är lika med kx plus m", "k är lutningen, alltså hur mycket y ändras när x ökar med ett.")])
add(MG2, "Matematik", "followup", "ge ett exempel", "exempel med pq-formeln, t.ex. x² − 5x + 6 = 0 ger 2 och 3",
    [T("pq-formeln", "pq-formeln löser andragradsekvationer på formen x i kvadrat plus px plus q är lika med noll.")])
add(M9, "Matematik", "misheard", "pyt a goras", "Pythagoras sats")
add(MG3, "Matematik", "misheard", "deri vata", "derivata")
add(MG2, "Matematik", "misheard", "loga ritmer", "logaritmer")
add(M7, "Matematik", "half", "hur räknar man ut procent av", "hur man räknar ut procent av ett tal: andel gånger det hela")
add(MG1, "Matematik", "half", "när man löser ekvationer ska man", "göra samma sak på båda sidor")
for g, q, e in [
    (M9, "hur räknar man ut arean av en cirkel", "pi gånger radien i kvadrat"),
    (MG1, "vad är skillnaden mellan procent och procentenheter", "procentenheter är differensen, procent är relativ förändring"),
    (MG3, "hur hittar man en funktions maximum", "derivera, sätt derivatan lika med noll, teckenstudium"),
    (M7, "vad är medelvärde median och typvärde", "lägesmått: medel summa/antal, median mitten, typvärde vanligast"),
    (MG2, "vad är en exponentialfunktion", "y = C · a^x, förändring med samma faktor"),
]:
    add(g, "Matematik", "exam", q, e)

# ---------------- short profiles and fast exams (length and priority) ----------------
SHORT = "Kontrollfrågor: Inga kontrollfrågor. Förklaringar: korta förklaringar."
for g, s, q, e in [
    ("Åk 8", "Kemi", "molekyl", "två eller fler atomer bundna, t.ex. vatten H2O"),
    ("Åk 9", "Fysik", "effekt", "energi per tid, watt, P = U·I"),
    ("Åk 9", "Biologi", "hormoner", "signalämnen i blodet, insulin, adrenalin"),
    ("Gymnasiet 1, kurs Historia 1b", "Historia", "imperialism", "stormakter tar kolonier, 1800-tal, råvaror och makt"),
    ("Åk 9", "Matematik", "kvadratrot", "talet som gånger sig självt ger talet, roten ur 49 är 7"),
    ("Gymnasiet 1, kurs Svenska 1", "Svenska", "ethos", "talarens trovärdighet"),
]:
    add(g, s, "short", q, e, profile=f"Årskurs: {g}. Ämne: {s}. {SHORT}")
TOMORROW = "Prov i {s} imorgon. Årskurs: {g}. På provet: {t}. Förklaringar: mellanlånga förklaringar."
for g, s, t, q, e in [
    ("Åk 9", "Biologi", "genetik och evolution", "vad är viktigast att kunna", "det som troligen kommer: gener, DNA, arv, naturligt urval"),
    ("Åk 8", "Kemi", "syror och baser", "vad ska jag plugga på sista kvällen", "pH-skalan, neutralisation, vätejoner, exempel"),
    ("Gymnasiet 2, kurs Matematik 2c", "Matematik", "andragradsekvationer", "vad brukar komma på provet", "pq-formeln, faktorisering, grafen, nollställen"),
    ("Åk 9", "Historia", "kalla kriget", "sammanfatta det viktigaste", "USA och Sovjet, ideologier, kapprustning, murens fall 1989"),
]:
    add(g, s, "exam_soon", q, e, profile=TOMORROW.format(s=s, g=g, t=t))

# ---------------- more spoken shapes (bare terms in all areas) ----------------
for g, s, q, e in [
    ("Åk 7", "Biologi", "näringskedja", "producent, konsument, energin minskar i varje led"),
    ("Åk 8", "Biologi", "blodomloppet", "hjärtat pumpar, stora och lilla kretsloppet, artärer och vener"),
    ("Gymnasiet 1, kurs Biologi 1", "Biologi", "genetisk kod", "tripletter av baser kodar aminosyror"),
    ("Åk 9", "Kemi", "förbränning", "ämne reagerar med syre, koldioxid och vatten bildas"),
    ("Gymnasiet 1, kurs Kemi 1", "Kemi", "oxidation", "avgivande av elektroner, redoxreaktion"),
    ("Åk 8", "Fysik", "magnetism", "nord- och sydpol, magnetfält, lika poler stöter bort"),
    ("Gymnasiet 1, kurs Fysik 1", "Fysik", "arbete", "kraft gånger sträcka, joule"),
    ("Åk 9", "Historia", "medeltiden", "ca 500-1500, feodalism, kyrkans makt, digerdöden"),
    ("Åk 9", "Samhällskunskap", "kommunen", "skola, äldreomsorg, kommunalskatt, kommunfullmäktige"),
    ("Gymnasiet 1, kurs Samhällskunskap 1b", "Samhällskunskap", "marknadsekonomi", "utbud och efterfrågan, privat ägande, konkurrens"),
    ("Åk 8", "Geografi", "befolkningspyramid", "ålder och kön, visar födelsetal och livslängd"),
    ("Åk 9", "Religion", "kristendomen", "Jesus, Bibeln, treenigheten, kyrkor"),
    ("Åk 9", "Svenska", "debattartikel", "tes, argument, motargument, uppmaning"),
    ("Gymnasiet 1, kurs Svenska 1", "Svenska", "språkhistoria", "runsvenska, fornsvenska, lånord"),
    ("Åk 9", "Engelska", "relative pronouns", "who which that, vem vad"),
    ("Åk 9", "Matematik", "volym", "längd gånger bredd gånger höjd, kubikcentimeter, liter"),
    ("Gymnasiet 1, kurs Matematik 1c", "Matematik", "potenser", "basen och exponenten, potenslagar"),
    ("Gymnasiet 3, kurs Matematik 3c", "Matematik", "gränsvärde", "värdet funktionen närmar sig, lim"),
]:
    add(g, s, "term", q, e)
for g, s, q, e, ctx in [
    ("Åk 8", "Biologi", "och lilla kretsloppet?", "lilla kretsloppet: hjärta till lungor och tillbaka, syresättning",
     [T("stora kretsloppet", "Stora kretsloppet går från hjärtat ut till kroppen och tillbaka med syrefattigt blod.")]),
    ("Gymnasiet 1, kurs Kemi 1", "Kemi", "och reduktion?", "reduktion: upptag av elektroner, sker samtidigt som oxidation",
     [T("oxidation", "Oxidation betyder att ett ämne avger elektroner.")]),
    ("Åk 9", "Historia", "vad hände sen?", "efter digerdöden: arbetskraftsbrist, högre löner, feodalismen försvagas",
     [T("digerdöden", "Digerdöden var en pestepidemi på 1300-talet som dödade ungefär en tredjedel av Europas befolkning.")]),
    ("Åk 9", "Samhällskunskap", "och landstinget då?", "regionen: sjukvård, kollektivtrafik, regionfullmäktige",
     [T("kommunen", "Kommunen ansvarar för till exempel skola och äldreomsorg och tar ut kommunalskatt.")]),
    ("Gymnasiet 3, kurs Matematik 3c", "Matematik", "hur räknar man med det?", "räkna gränsvärde: sätt in värden närmare, förenkla, faktorisera",
     [T("gränsvärde", "Ett gränsvärde är det värde en funktion närmar sig när x går mot ett visst tal.")]),
    ("Åk 9", "Engelska", "och whose?", "whose: vars, ägande",
     [T("relative pronouns", "Relative pronouns som who, which och that binder ihop satser och syftar tillbaka på något.")]),
    ("Gymnasiet 1, kurs Fysik 1", "Fysik", "och effekt då?", "effekt: arbete per tid, watt, P = W/t",
     [T("arbete", "Arbete i fysik är kraft gånger sträcka och mäts i joule.")]),
    ("Åk 9", "Religion", "vad är skillnaden mot islam?", "skillnader: Jesus som Guds son vs profet, treenighet vs strikt monoteism",
     [T("kristendomen", "Kristendomen bygger på tron på Jesus som Guds son och har Bibeln som helig skrift.")]),
]:
    add(g, s, "followup", q, e, ctx)

# ---------------- K1.3 (Oscar D83): math level, Åk 8 vs Matte 4 ----------------
M8, MG3c, MG4 = "Åk 8", "Gymnasiet 3, kurs Matematik 3c", "Gymnasiet 3, kurs Matematik 4"
NOLIM = "; grundskolenivå: inga gränsvärden, ingen kedjeregel, ingen f′-notation"
for g, q, e in [
    (M8, "derivata", "idén: hur snabbt något ändras, lutningen på en graf, vardagsexempel som hastighet" + NOLIM),
    ("Åk 9", "derivata", "idén: förändring och lutning på en graf, exempel" + NOLIM),
    (M8, "vad är derivatan av x i kvadrat", "två x (säger x), enkel förklaring: lutningen ökar ju större x är" + NOLIM),
    (M8, "ekvation", "en likhet med en obekant, gör samma sak på båda sidor, ett exempel på åk 8-nivå"),
    (M8, "lös 3x minus 7 är lika med 14", "x = 7: lägg till 7 på båda sidor ger 3x = 21, dela med 3"),
    (M8, "två x plus nio är lika med tre", "x = −3: dra bort 9 ger 2x = −6, dela med 2"),
    (MG3c, "derivatans definition", "gränsvärdet av (f(x+h) − f(x))/h när h går mot noll, lutningen på tangenten"),
    (MG4, "kedjeregeln", "derivatan av en sammansatt funktion: yttre derivatan gånger inre derivatan, exempel (3x+1)⁵ ger 15(3x+1)⁴"),
    (MG4, "derivatan av e upphöjt till två x", "2e^(2x), med kedjeregeln (inre derivatan 2)"),
    (MG4, "derivera tre x i kvadrat plus två x minus fem", "6x + 2 med potensregeln, konstanten försvinner"),
    (MG4, "produktregeln", "(f·g)′ = f′·g + f·g′, ett exempel"),
    (MG4, "derivatan av sinus x", "cos x; och derivatan av cos x är −sin x"),
]:
    add(g, "Matematik", "mathlevel", q, e)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "provlage-bank.json")
json.dump(cases, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
kinds = {}
for c in cases:
    kinds[c["kind"]] = kinds.get(c["kind"], 0) + 1
print(len(cases), kinds)
