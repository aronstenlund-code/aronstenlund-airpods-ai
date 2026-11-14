import Foundation

/// T20: made-up study pages (Toby, 2026-11-13), never a pupil's text. One page each, biology for year 8: the body and
/// ecology, so 30 photos carry 30 different things to ask about.
enum UploadPages {
    static let text: [String] = [
        "Fotosyntes. Gröna växter tillverkar druvsocker av koldioxid och vatten. Energin kommer från solljuset, som fångas av klorofyllet i bladens kloroplaster. Syre bildas som en restprodukt och släpps ut genom klyvöppningarna.",
        "Cellandning. Alla celler bryter ner druvsocker med hjälp av syre för att få energi. Det sker i mitokondrierna. Koldioxid och vatten bildas. Cellandningen är fotosyntesens omvända reaktion.",
        "Näringskedjor. En näringskedja visar vem som äter vem, till exempel gräs, hare, räv. Växterna kallas producenter. Djuren är konsumenter av första, andra eller tredje ordningen. Nedbrytare tar hand om döda rester.",
        "Energipyramiden. Bara ungefär en tiondel av energin går vidare till nästa led i en näringskedja. Resten används till rörelse och värme. Därför finns det färre rovdjur än växtätare i ett ekosystem.",
        "Kolets kretslopp. Kol finns i luften som koldioxid. Växterna tar upp den vid fotosyntesen. När djur andas, när växter ruttnar och när vi eldar fossila bränslen går kolet tillbaka till luften.",
        "Växthuseffekten. Koldioxid och metan i atmosfären släpper in solljus men håller kvar värme. Det gör jorden beboelig. När halten ökar, till exempel genom förbränning av olja och kol, blir det varmare.",
        "Nedbrytare. Svampar, bakterier och maskar bryter ner döda växter och djur. Näringsämnen som kväve och fosfor blir då tillgängliga för växterna igen. Utan nedbrytare skulle kretsloppen stanna.",
        "Ekosystem. Ett ekosystem är alla levande organismer i ett område tillsammans med den icke-levande miljön, som vatten, jord, ljus och temperatur. Exempel är en sjö, en granskog och en äng.",
        "Population och samhälle. En population är alla individer av en art i ett område. Alla populationer i området bildar ett samhälle. Populationens storlek styrs av föda, rovdjur, sjukdomar och plats.",
        "Biologisk mångfald. Mångfald betyder variation mellan arter, inom arter och mellan ekosystem. Ett ekosystem med många arter klarar störningar bättre, eftersom andra arter kan ta över när en försvinner.",
        "Cellen. Alla levande organismer är uppbyggda av celler. Djurceller har cellkärna, cellmembran, cytoplasma och mitokondrier. Växtceller har dessutom cellvägg, kloroplaster och en stor vakuol.",
        "Matsmältningen. Maten sönderdelas i munnen av tänderna och saliven. I magsäcken bryter saltsyra och enzymer ner proteiner. I tunntarmen tas näringsämnena upp genom tarmluddet till blodet.",
        "Tjocktarmen. I tjocktarmen tas vatten och salter upp. Där lever också många bakterier som bryter ner fibrer och bildar vitaminer. Det som inte tas upp lämnar kroppen som avföring.",
        "Hjärtat. Hjärtat är en muskel med fyra hålrum: två förmak och två kammare. Höger sida pumpar syrefattigt blod till lungorna. Vänster sida pumpar syrerikt blod ut i kroppen. Klaffar hindrar blodet att rinna bakåt.",
        "Blodet. Blodet består av blodplasma, röda blodkroppar, vita blodkroppar och blodplättar. De röda transporterar syre med hjälp av hemoglobin. De vita försvarar kroppen. Blodplättarna hjälper blodet att levra sig.",
        "Andningen. Luften går genom luftstrupen till luftrören och vidare till lungblåsorna. Där går syret över till blodet och koldioxiden ut. Mellangärdet och revbensmusklerna gör att lungorna fylls.",
        "Immunförsvaret. Huden och slemhinnorna stoppar de flesta bakterier. Kommer de in angriper vita blodkroppar dem. Vissa vita blodkroppar bildar antikroppar och minns smittan, så att man blir immun.",
        "Vaccin. Ett vaccin innehåller försvagade eller döda smittämnen, eller delar av dem. Kroppen bildar antikroppar och minnesceller utan att bli sjuk. Om den riktiga smittan kommer kan kroppen försvara sig snabbt.",
        "Bakterier och virus. Bakterier är levande encelliga organismer som kan föröka sig själva. Virus är mycket mindre och kan bara föröka sig inne i en cell. Antibiotika fungerar mot bakterier men inte mot virus.",
        "Antibiotikaresistens. När antibiotika används för ofta överlever de bakterier som tål medlet. De förökar sig och sprider motståndskraften. Därför ska antibiotika bara användas när det behövs.",
        "Nervsystemet. Hjärnan och ryggmärgen bildar det centrala nervsystemet. Nerverna leder signaler mellan kroppen och hjärnan. En reflex går bara via ryggmärgen, och därför går den mycket snabbt.",
        "Sinnena. Ögat tar in ljus genom pupillen och linsen, och bilden bildas på näthinnan. Örat fångar ljudvågor som får trumhinnan och hörselbenen att vibrera. Signalerna skickas till hjärnan via nerver.",
        "Hormoner. Hormoner är signalämnen som skickas med blodet. Insulin från bukspottkörteln sänker blodsockret. Adrenalin från binjurarna gör kroppen redo för kamp eller flykt.",
        "Skelett och muskler. Skelettet ger stöd, skyddar organen och bildar blodkroppar i benmärgen. Musklerna kan bara dra ihop sig, så de arbetar i par, till exempel biceps och triceps.",
        "Puberteten. Under puberteten börjar könshormonerna bildas. Hos flickor börjar äggstockarna mogna ägg och mens kommer. Hos pojkar börjar testiklarna bilda spermier. Kroppen växer och förändras.",
        "Arv och DNA. Arvsanlagen finns i DNA i cellkärnan. En gen är en bit DNA som bär information om en egenskap. Vi får hälften av våra kromosomer från mamman och hälften från pappan.",
        "Evolution. Inom en art varierar individerna. De som är bäst anpassade till miljön överlever och får fler ungar. Deras egenskaper blir då vanligare. Det kallas naturligt urval och beskrevs av Charles Darwin.",
        "Anpassningar. Djur och växter är anpassade till sin miljö. Isbjörnen har tjock päls och fettlager. Kaktusen har tjocka stammar som lagrar vatten och taggar i stället för blad, så att den förlorar mindre vatten.",
        "Allemansrätten. Allemansrätten låter alla röra sig i naturen, men man ska inte störa eller förstöra. Man får plocka bär och svamp. Man får inte skada träd eller störa fåglar som häckar.",
        "Hållbar utveckling. Hållbar utveckling betyder att vi tillgodoser våra behov utan att förstöra för kommande generationer. Det handlar om att minska utsläppen, återvinna, äta mer växter och skydda den biologiska mångfalden.",
    ]
}
