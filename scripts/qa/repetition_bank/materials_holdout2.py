"""O60 (D176): fem nya påhittade hållout-prov, skrivna av Oscar (QA) 2026-11-14 innan Kevins K61. Aldrig elevtext.
Samma format som materials_holdout.H. Ligger utanför exams.json, så att Kevins scripts/k45-measure.py inte mäter på dem.
"""

H2 = {}

H2["h2-ge-klimatzoner"] = dict(
    subject="Geografi", grade="åk 7", grade_ok=["åk 7", "åk7", "årskurs 7"], max_q=None, topic="Klimat och klimatzoner",
    pages=[
        "Geografi åk 7 – Klimat och väder\nVäder är hur det är ute just nu, till exempel regn eller sol. Klimat är "
        "vädret på en plats under lång tid, ofta 30 år. Klimatet styrs främst av hur mycket solljus platsen får.",
        "Varför är det varmare vid ekvatorn?\nVid ekvatorn faller solstrålarna nästan rakt ner, så energin sprids på en "
        "liten yta. Närmare polerna kommer strålarna snett, och samma energi sprids på en större yta. Därför blir det "
        "kallare ju längre från ekvatorn man kommer.",
        "Klimatzonerna\nRegnskogsklimat är varmt och fuktigt hela året. Ökenklimat har nästan inget regn, heta dagar och "
        "kalla nätter. Tempererat klimat, som i södra Sverige, har fyra årstider. Polarklimat är kallt hela året.",
        "Hav och höjd\nHavet värms och kyls långsammare än land. Därför har kustorter mildare vintrar och svalare somrar. "
        "Golfströmmen för varmt vatten till Norden, så Norge har isfria hamnar långt norrut. Högt upp i bergen är det "
        "kallare, ungefär 0,6 grader per 100 meter.",
    ],
    formats=[("photo", [0, 1, 2, 3])],
    goals=[
        ("G1", "Skillnaden mellan väder och klimat", ["väder", "klimat", "30 år"]),
        ("G2", "Varför det är varmare vid ekvatorn", ["ekvatorn", "rakt", "snett"]),
        ("G3", "De fyra klimatzonerna", ["regnskog", "öken", "tempererat", "polar"]),
        ("G4", "Havets och Golfströmmens påverkan", ["havet", "golfströmmen", "kust"]),
        ("G5", "Höjdens påverkan", ["höjd", "berg", "0,6"]),
    ],
    outside=["monsun", "passadvind", "el niño", "växthuseffekten", "ozon"],
)

H2["h2-re-buddhism"] = dict(
    subject="Religionskunskap", grade="", grade_ok=None, max_q=None, topic="Buddhismen",
    pages=[
        "Buddhismen\nBuddhismen grundades i Indien för ungefär 2 500 år sedan av Siddhartha Gautama. Han kallas Buddha, "
        "som betyder den upplyste.",
        "Buddhas liv\nSiddhartha växte upp som prins i lyx. När han lämnade palatset såg han en gammal man, en sjuk man, "
        "en död man och en munk. Han förstod att allt liv innehåller lidande och lämnade sitt liv som prins för att "
        "hitta en väg ut ur lidandet.",
        "De fyra ädla sanningarna\n1. Livet innehåller lidande. 2. Lidandet orsakas av begär. 3. Lidandet kan upphöra. "
        "4. Vägen dit är den åttafaldiga vägen.",
        "Den åttafaldiga vägen\nDen åttafaldiga vägen handlar om att tänka, tala och handla rätt, och om meditation. "
        "Buddha kallade den mellanvägen, eftersom den varken är ett liv i lyx eller ett liv i hård självplågeri.",
        "Karma och nirvana\nKarma betyder att goda och onda handlingar får följder, också i nästa liv. Buddhister tror "
        "på återfödelse. Målet är nirvana, då begäret slocknar och kretsloppet av återfödelser tar slut.",
        "Buddhismen i dag\nDet finns två stora inriktningar: theravada i till exempel Thailand och mahayana i till exempel "
        "Japan och Kina. Många buddhister mediterar och besöker tempel.",
    ],
    formats=[("docx", [0, 1, 2, 3, 4, 5])],
    goals=[
        ("G1", "Buddhas liv och de fyra mötena", ["prins", "palatset", "lidande"]),
        ("G2", "De fyra ädla sanningarna", ["begär", "lidande", "sanning"]),
        ("G3", "Den åttafaldiga vägen och mellanvägen", ["åttafaldiga", "mellanvägen"]),
        ("G4", "Karma, återfödelse och nirvana", ["karma", "återfödelse", "nirvana"]),
        ("G5", "Theravada och mahayana", ["theravada", "mahayana"]),
    ],
    outside=["dalai lama", "zen", "tibet", "hinduism", "kastsystem"],
)

H2["h2-sv-argumentera"] = dict(
    subject="Svenska", grade="åk 9", grade_ok=["åk 9", "åk9", "årskurs 9"], max_q=None, topic="Argumenterande text",
    pages=[
        "Svenska åk 9 – Den argumenterande texten\nEn argumenterande text vill övertyga läsaren om en åsikt, som kallas "
        "tes. Tesen står tidigt i texten, ofta i inledningen.",
        "Argument och motargument\nArgumenten är skälen till att tesen stämmer. Starka argument bygger på fakta, exempel "
        "eller expertutlåtanden. Ett motargument är ett skäl som talar emot tesen. Skribenten bemöter motargumentet för att "
        "visa att tesen ändå håller, och det gör texten mer trovärdig.",
        "Struktur och sambandsord\nTexten har inledning med tes, en del med argument och motargument, och en avslutning som "
        "upprepar tesen. Sambandsord som för det första, dessutom, å andra sidan och därför visar hur tankarna hänger ihop.",
        "Retorikens tre medel\nEthos handlar om skribentens trovärdighet. Logos är förnuftsargument med fakta och logik. "
        "Pathos väcker känslor hos läsaren. En bra text blandar alla tre.",
    ],
    formats=[("text", [0, 1, 2, 3])],
    goals=[
        ("G1", "Tes och var den står", ["tes", "inledning"]),
        ("G2", "Argument och vad som gör dem starka", ["argument", "fakta"]),
        ("G3", "Motargument och varför man bemöter dem", ["motargument", "bemöt", "trovärdig"]),
        ("G4", "Struktur och sambandsord", ["sambandsord", "avslutning"]),
        ("G5", "Ethos, logos och pathos", ["ethos", "logos", "pathos"]),
    ],
    outside=["debattartikel i tidning", "insändare", "krönika", "källkritik", "novell"],
)

H2["h2-hkk-naring"] = dict(
    subject="Hem- och konsumentkunskap", grade="", grade_ok=None, max_q=None, topic="Näringsämnen",
    pages=[
        "Näringsämnen och energi\nKroppen behöver energi och byggstenar från maten. De energigivande näringsämnena är "
        "kolhydrater, fett och protein. Vitaminer, mineraler och vatten ger ingen energi men behövs för att kroppen ska fungera.",
        "Kolhydrater och fibrer\nKolhydrater är kroppens viktigaste bränsle, särskilt för hjärnan och musklerna. Fullkorn "
        "innehåller fibrer, som gör att man blir mätt längre och att blodsockret stiger långsamt. Socker ger snabb energi "
        "men blodsockret sjunker snart igen.",
        "Protein och fett\nProtein bygger upp och reparerar muskler och andra vävnader. Det finns i kött, fisk, ägg, "
        "bönor och linser. Fett ger mest energi per gram och behövs för att ta upp vitaminerna A, D, E och K. Omättat "
        "fett, som i fisk och rapsolja, är bättre för hjärtat än mättat fett.",
        "Tallriksmodellen\nTallriksmodellen visar en bra måltid: ungefär hälften grönsaker, en fjärdedel potatis, ris "
        "eller pasta och en fjärdedel protein.",
    ],
    formats=[("pdf", [0, 1, 2, 3])],
    goals=[
        ("G1", "Energigivande och icke-energigivande näringsämnen", ["kolhydrater", "fett", "protein", "vitamin"]),
        ("G2", "Kolhydrater, fibrer och blodsocker", ["fibrer", "blodsocker", "fullkorn"]),
        ("G3", "Proteinets uppgift och var det finns", ["protein", "muskler", "bönor"]),
        ("G4", "Fett, fettlösliga vitaminer och omättat fett", ["omättat", "fettlösliga", "a, d, e och k"]),
        ("G5", "Tallriksmodellen", ["tallriksmodellen", "hälften"]),
    ],
    outside=["kalorier per dag", "vegan", "laktos", "gluten", "kosttillskott"],
)

H2["h2-fy-elektricitet"] = dict(
    subject="Fysik", grade="åk 8", grade_ok=["åk 8", "åk8", "årskurs 8"], max_q=None, topic="Elektricitet",
    pages=[
        "Fysik åk 8 – Elektricitet\nElektrisk ström är elektroner som rör sig i en sluten krets. Strömmen mäts i ampere (A). "
        "Spänningen, som mäts i volt (V), är det som driver elektronerna runt, ungefär som ett tryck.",
        "Resistans och Ohms lag\nResistans är motståndet mot strömmen och mäts i ohm (Ω). Ohms lag säger att spänningen är "
        "resistansen gånger strömmen, U = R · I. Med högre resistans blir strömmen mindre vid samma spänning.",
        "Serie- och parallellkoppling\nI en seriekoppling går strömmen genom alla lampor efter varandra, och slocknar en "
        "lampa slocknar alla. I en parallellkoppling har varje lampa en egen väg, så de andra lyser kvar. Därför är "
        "eluttagen i ett hus parallellkopplade.",
        "Ledare, isolatorer och säkerhet\nMetaller leder ström bra eftersom de har fria elektroner. Plast och gummi är "
        "isolatorer. En säkring bryter strömmen om den blir för stor, så att ledningarna inte blir för varma och börjar brinna.",
    ],
    formats=[("photo", [0, 1, 2, 3])],
    goals=[
        ("G1", "Ström och spänning", ["ström", "spänning", "ampere", "volt"]),
        ("G2", "Resistans och Ohms lag", ["resistans", "ohm", "u = r"]),
        ("G3", "Serie- och parallellkoppling", ["serie", "parallell"]),
        ("G4", "Ledare och isolatorer", ["ledare", "isolator", "fria elektroner"]),
        ("G5", "Säkringens uppgift", ["säkring"]),
    ],
    outside=["växelström", "transformator", "magnetism", "kärnkraft", "solceller"],
)
