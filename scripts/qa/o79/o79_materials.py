"""O79 (Oscar moln, 2026-11-17): fem nya testmaterial, skrivna för O79 och inte med i någon tidigare bank eller i Kevins testdata.
Olika ämnen och längder; ett på engelska; ett blir ett foto (OCR i exam drill). Delarna (rubrik + text) används för
täckningskontrollen: varje del ska ha minst en fråga när antalet frågor räcker, och ingen del mer än hälften."""

O79 = {
    "o79-bi-ekosystem": {
        "subject": "Biologi", "grade": "Åk 8", "lang": "sv", "format": "text", "parts": [
            ("Producenter och konsumenter",
             "I ett ekosystem kallas växterna producenter. De tar energi från solljuset och bygger socker genom fotosyntesen. "
             "Djur som äter växter kallas förstahandskonsumenter, till exempel rådjur och sniglar. Djur som äter andra djur kallas "
             "andrahandskonsumenter, som räven som äter sorkar. En toppkonsument är ett djur som inget annat djur i området äter, "
             "till exempel lodjuret i en svensk skog."),
            ("Energipyramiden",
             "Bara ungefär en tiondel av energin följer med från en nivå i näringskedjan till nästa. Resten används till att röra "
             "sig, hålla värmen och andas, och försvinner till slut som värme. Därför finns det mycket mer växter än växtätare, och "
             "mycket fler växtätare än rovdjur. Det förklarar också varför näringskedjor sällan har mer än fyra eller fem led."),
            ("Nedbrytare och kretslopp",
             "Svampar, bakterier och maskar är nedbrytare. De bryter ner döda växter och djur till enkla ämnen, som kväve och fosfor, "
             "som växterna kan ta upp igen genom rötterna. Utan nedbrytare skulle näringen bli kvar i döda löv och kroppar, och nya "
             "växter skulle inte kunna växa. Materia går alltså runt i ett kretslopp, medan energin hela tiden måste tillföras från solen."),
            ("När en art försvinner",
             "Om en art försvinner påverkas många andra. När vargen försvann från stora delar av Sverige ökade antalet älgar och rådjur "
             "i vissa områden. Fler älgar betar mer på unga tallar, och då förändras skogen. Ett ekosystem med många arter klarar "
             "sådana förändringar bättre, eftersom andra arter kan ta över en roll som har försvunnit."),
        ]},
    "o79-en-printing": {
        "subject": "Engelska", "grade": "Gy Engelska 6", "lang": "en", "format": "text", "parts": [
            ("Before the press",
             "Before the fifteenth century, books in Europe were copied by hand, mostly by monks working in monasteries. Copying a "
             "single Bible could take a scribe more than a year. Books were therefore rare and expensive, and only the Church, "
             "universities and the very rich owned them. Most people could not read, and there was little reason to learn."),
            ("Gutenberg's invention",
             "Around 1450, Johannes Gutenberg, a goldsmith in Mainz, combined several existing ideas into a new system. He cast "
             "individual letters in metal, so that the same letters could be arranged, inked, printed and then reused for the next "
             "page. He also developed an oil-based ink that stuck to metal and adapted a screw press, similar to those used for "
             "making wine. His best-known work, the Gutenberg Bible, was finished around 1455."),
            ("A faster spread of ideas",
             "Within fifty years, printing presses were working in more than two hundred European cities, and millions of books had "
             "been printed. Because many identical copies could be made, a text no longer changed a little every time it was copied. "
             "Scientists could compare their results with others, and new ideas travelled faster than ever before. When Martin Luther "
             "criticised the Church in 1517, printed pamphlets carried his arguments across Germany in a few weeks."),
            ("Long-term effects",
             "Cheaper books gave more people a reason to learn to read, and literacy slowly increased. Printing in local languages "
             "instead of Latin helped to standardise languages such as German and English. Some historians argue that the printing "
             "press was one of the conditions that made the Reformation and the Scientific Revolution possible, although it did not "
             "cause them on its own."),
        ]},
    "o79-fy-ljud": {
        "subject": "Fysik", "grade": "Åk 7", "lang": "sv", "format": "text", "parts": [
            ("Vad ljud är",
             "Ljud är vibrationer som sprids som vågor genom ett ämne, till exempel luft, vatten eller trä. När en gitarrsträng "
             "svänger trycker den ihop och tunnar ut luften omkring sig, och de förtätningarna sprids vidare till örat. I ett "
             "vakuum, där det inte finns några partiklar, kan ljud inte spridas. Därför är det tyst i rymden."),
            ("Tonhöjd och ljudstyrka",
             "Hur många svängningar som sker varje sekund kallas frekvens och mäts i hertz. Hög frekvens ger en ljus ton och låg "
             "frekvens en mörk ton. Människor hör ungefär mellan 20 och 20 000 hertz. Hur starkt ett ljud är beror på hur stora "
             "svängningarna är och mäts i decibel. Ljud över ungefär 85 decibel kan skada hörseln om man lyssnar länge."),
            ("Ljudets hastighet",
             "I luft färdas ljudet cirka 340 meter per sekund. I vatten går det ungefär fyra gånger så fort, och i stål ännu snabbare, "
             "eftersom partiklarna sitter tätare och för vibrationerna vidare snabbare. Ljuset går mycket fortare än ljudet. Därför ser "
             "man blixten innan man hör åskan, och genom att räkna sekunderna emellan kan man uppskatta hur långt bort åskan är."),
        ]},
    "o79-hi-vasa-foto": {
        "subject": "Historia", "grade": "Åk 7", "lang": "sv", "format": "photo", "parts": [
            ("Gustav Vasa och det nya Sverige",
             "År 1520 lät den danske kungen Kristian II avrätta omkring 80 svenska adelsmän och borgare i Stockholm. Händelsen kallas "
             "Stockholms blodbad. Den unge adelsmannen Gustav Eriksson Vasa flydde till Dalarna och fick med sig bönder i ett uppror mot "
             "danskarna. År 1523 valdes han till kung i Strängnäs, och den 6 juni samma år räknas i dag som Sveriges nationaldag."),
            ("Reformationen",
             "Kronan hade stora skulder till Lübeck efter kriget. Gustav Vasa ville komma åt kyrkans rikedomar och makt. Vid riksdagen i "
             "Västerås 1527 beslutades att kyrkans jord och egendom skulle gå till kronan. Sverige blev steg för steg lutherskt. Bibeln "
             "översattes till svenska, och Gustav Vasas bibel trycktes 1541. Gudstjänsterna hölls nu på svenska i stället för på latin."),
            ("En starkare kungamakt",
             "Gustav Vasa byggde upp en central förvaltning med fogdar som drev in skatter över hela landet, och han skapade en egen här. "
             "Missnöjet var stort på många håll, och Dackefejden i Småland 1542–1543 var det största upproret mot honom. År 1544 beslutade "
             "riksdagen att Sverige skulle vara ett arvrike, så att kronan gick i arv till kungens söner i stället för att kungen valdes."),
        ]},
    "o79-sh-inflation": {
        "subject": "Samhällskunskap", "grade": "Gy Samhällskunskap 1b", "lang": "sv", "format": "text", "parts": [
            ("Vad inflation är",
             "Inflation betyder att den allmänna prisnivån stiger, så att man får mindre för samma summa pengar. Om inflationen är "
             "fem procent kostar en varukorg som kostade 100 kronor förra året nu 105 kronor. I Sverige mäts inflationen med "
             "konsumentprisindex, KPI, som räknas fram av Statistiska centralbyrån varje månad. Motsatsen, att priserna sjunker, "
             "kallas deflation."),
            ("Varför priserna stiger",
             "Inflation kan uppstå när efterfrågan är större än det som produceras, till exempel när hushållen har mycket pengar och "
             "vill köpa mer än företagen hinner tillverka. Den kan också komma från kostnaderna: om priset på energi eller råvaror stiger "
             "måste företagen höja sina priser. Höga löneökningar som inte följs av högre produktivitet kan också driva upp priserna."),
            ("Riksbankens uppdrag",
             "Riksbanken är Sveriges centralbank och ska hålla priserna stabila. Målet är att inflationen ska vara två procent per år, "
             "mätt med KPIF, ett mått där effekten av ändrade bolåneräntor är borttagen. Riksbankens viktigaste verktyg är styrräntan. "
             "När inflationen är för hög höjer Riksbanken styrräntan. Då blir det dyrare att låna och mer lönsamt att spara, hushållen "
             "och företagen köper mindre, och prisökningarna bromsas."),
            ("Vem vinner och vem förlorar",
             "Hög inflation drabbar den som har sparpengar på ett konto med låg ränta, eftersom pengarna förlorar i värde. Den som har "
             "lån kan i stället vinna, eftersom skulden blir mindre värd, så länge räntan inte stiger lika mycket. Personer med fasta "
             "inkomster, till exempel en pension som inte räknas upp, får det sämre när priserna stiger snabbare än inkomsterna."),
            ("2022 och efteråt",
             "Under 2022 steg inflationen i Sverige till den högsta nivån på över trettio år, främst på grund av dyrare energi och "
             "livsmedel efter Rysslands invasion av Ukraina. Riksbanken höjde styrräntan flera gånger under 2022 och 2023. När "
             "inflationen sedan sjönk mot målet började Riksbanken sänka räntan igen under 2024."),
        ]},
}
