# PRODUKTRAPPORT – FÖRSLAG PÅ NYA EARMIND-FUNKTIONER

## Uppdrag till Claude

ChatGPT har analyserat möjliga nya funktioner för Earmind och tagit fram förslagen nedan utifrån produktens vision och befintliga funktioner.

Jag vill att du agerar som en självständig senior produktstrateg, iOS-arkitekt och teknisk granskare.

**Viktigt: Se ALLT i denna rapport som förslag. Du ska inte automatiskt godkänna eller implementera någonting.**

Granska idéerna självständigt. Du har mandat att:
- Förkasta idéer som inte skapar tillräckligt användarvärde.
- Förbättra eller kombinera idéer.
- Hitta bättre namn och lösningar.
- Identifiera funktioner som redan finns i projektet.
- Undersöka tekniska begränsningar.
- Föreslå bättre alternativ som inte nämns här.

Målet är att hitta funktioner som gör Earmind till en riktigt användbar AI-agent i AirPods.

---

# 1. Produktens grundidé

Earmind är en iPhone-app som fungerar som en personlig AI-agent genom Apple AirPods.

Användaren startar assistenten en gång och kan sedan säga exempelvis:

"Earmind, hur blir vädret idag?"

"Earmind, hjälp mig med det här."

"Earmind, lägg in det i min matlogg."

Assistenten ska förstå naturligt tal, sammanhang och avsikt och svara direkt i användarens öron.

Målgruppen är främst 13–25 år, men produkten ska fungera för alla åldrar.

Den stora konkurrensfördelen bör vara att användaren kan få hjälp utan att behöva plocka fram telefonen, öppna olika appar eller navigera genom menyer.

# 2. Befintliga funktioner – undvik dubbelarbete

Följande funktioner finns redan eller är planerade:

- Standardsvar på frågor genom AirPods.
- Provläge med förhör, övningsprov, studieplanering, repetition, vändkort och egna modellsvar.
- Möjlighet att fotografera boksidor och bli förhörd.
- Intervjuläge.
- Socialt läge och Rizzläge.
- Kalender och påminnelser.
- Timers och anteckningar.
- Spotify-styrning och telefonsamtal.
- Shopify-statusrapporter.
- Webbsökning och länkar till lärofilmer.
- Språklig uttalsträning.
- Roliga kommandon, exempelvis sång, rap och skämt.
- Sömnfunktion som registrerar och sammanfattar sömnprat och snarkning.
- Personligt minne.
- Offline-svar på nyare iPhones.
- Väckarklocka kopplad till sömnfunktionen.
- Träningsfunktion/kurs.

Granska projektet och kontrollera vad som faktiskt är byggt respektive bara planerat innan du föreslår ytterligare utveckling.

# 3. Förslag på funktioner att undersöka

## A. Mat- och hälsologg

Det här är ett av de mest intressanta förslagen.

Tanken är att användaren ska kunna registrera vad den äter genom att helt enkelt prata med Earmind.

Exempel:

Användaren:
"Earmind, jag äter ris med kyckling och currysås. Lägg in det i min matlogg."

Earmind:
"Registrerat! Jag uppskattar måltiden till cirka 650 kalorier."

Förslag på funktionalitet:
- Registrera måltider genom vanligt tal.
- Möjlighet att fotografera maten för att få en bättre uppskattning.
- Uppskatta kalorier, protein, kolhydrater och fett.
- Spara måltider i användarens personliga profil.
- Visa daglig och veckovis översikt.
- Följa personliga näringsmål.
- Registrera allergier och kostbegränsningar.
- Varningar om registrerad mat sannolikt innehåller något användaren inte tål.

Viktigt:
Röstregistrering ska vara den huvudsakliga användningen. Fotografering ska vara ett komplement.

Undersök om funktionerna bör byggas som en samlad mat- och hälsologg eller om allergihantering bör vara en separat del.

Undersök även:
- Hur kalorier och näringsvärden kan uppskattas tillförlitligt.
- Vilka externa näringsdatabaser som är lämpliga.
- Om HealthKit bör användas eller om egen datalagring är bättre.
- Hur användaren kan korrigera portionsstorlekar och uppskattningar.
- Hur funktionen kan utformas ansvarsfullt för yngre användare.

Det ska aldrig presenteras som att kalorier från en muntlig beskrivning är exakta värden.

## B. Avgångskollen – tidigare kallad Busskompisen

Förslag på nytt namn: Avgångskollen.

En kollektivtrafikassistent som hjälper användaren under hela resan.

Exempel:

"Earmind, säg till när jag ska gå av."

Föreslagen funktionalitet:
- Hålla koll på avgångar.
- Hålla koll på byten.
- Meddela när det är dags att kliva av.
- Hantera förseningar och inställda avgångar.
- Hjälpa användaren hitta rätt hållplats.
- Stöd för buss, tunnelbana, pendeltåg, spårvagn och tåg.

Ett mycket viktigt krav är att funktionen på sikt ska fungera i hela Sverige, inte enbart Stockholm.

Trafiklab och deras GTFS-data är exempel på tekniska lösningar att undersöka.

Granska:
- Vilka svenska kollektivtrafikoperatörer som faktiskt kan täckas.
- Tillgång till tidtabeller och realtidsinformation.
- Hur förseningar och ändrade avgångar ska hanteras.
- Om det finns tillräckligt bra API-täckning.
- Kostnader, användningsbegränsningar och eventuella licenser.
- Hur platspositionering fungerar i bakgrunden på iOS 26.
- Hur man kan göra funktionen pålitlig utan att tömma batteriet.

Vi ska inte marknadsföra nationell realtidstäckning innan det är verifierat.

## C. Röstöversättaren

Förslag på funktion där användaren kan förstå och kommunicera med människor som talar andra språk.

Exempel:

"Earmind, översätt vad personen säger till svenska."

Möjliga funktioner:
- Översätta tal i realtid eller nära realtid.
- Spela upp översättningen i AirPods.
- Hjälpa användaren formulera svar på det andra språket.
- Stödja flera språk.

Undersök fördröjning, språkstöd, kostnader och om en naturlig konversation faktiskt är tekniskt genomförbar.

## D. Väderkollen

En funktion där Earmind kan svara på frågor om vädret i användarens område.

Exempel:
- "Hur blir vädret här idag?"
- "Kommer det regna de närmaste timmarna?"
- "När blir det uppehåll?"
- "Hur blir vädret i Sollentuna imorgon?"

Förslag på funktionalitet:
- Aktuellt väder.
- Timprognoser.
- Dagsprognoser.
- Regnvarningar.
- Väder på användarens nuvarande plats.
- Väder för manuellt valda platser.

Undersök gärna Apples WeatherKit och jämför med relevanta alternativ.

Funktionen ska vara snabb och naturlig att använda genom AirPods.

## E. Mötesminnet – tidigare kallad Mötesradarn

Förslag på nytt namn: Mötesminnet.

En funktion som hjälper användaren komma ihåg innehållet från möten och diskussioner.

Exempel:
"Earmind, vad bestämde vi om deadline?"

Möjliga funktioner:
- Sammanfatta möten.
- Identifiera beslut.
- Komma ihåg vem som ansvarade för olika uppgifter.
- Hitta deadlines som nämnts.
- Svara på frågor om tidigare möten.

Undersök vad som eventuellt redan kan uppnås med Earminds befintliga mikrofon- och minnessystem.

Integritet och tydligt samtycke från andra mötesdeltagare är avgörande.

## F. Matlagningsassistenten

En funktion som hjälper användaren laga mat helt eller nästan helt handsfree.

Exempel:
"Earmind, hjälp mig laga en kycklinggryta."

Möjliga funktioner:
- Hitta och föreslå recept.
- Ge muntliga instruktioner steg för steg.
- Anpassa portioner och mängder.
- Hålla koll på flera tillagningstider.
- Svara på frågor under matlagningen.
- Förklara hur man utför olika moment.
- Hjälpa användaren ersätta ingredienser.

En viktig del är att användaren ska kunna fortsätta laga mat utan att hela tiden titta på telefonen.

Undersök hur mycket som kan byggas med befintlig AI-funktionalitet och vad som kräver nya integrationer.

# 4. Andra idéer att spara till senare eller inte utveckla separat

## Prisjämföraren

Ett framtida förslag där användaren kan fråga:

"Earmind, hitta den billigaste versionen av de här hörlurarna."

Tanken är att Earmind ska kunna söka på hela internet efter produkter och priser, ungefär som Prisjakt.

Möjligheter:
- Jämföra priser hos olika återförsäljare.
- Hitta billigaste tillgängliga alternativ.
- Jämföra specifikationer.
- Hitta erbjudanden.

Detta är inte en prioriterad funktion för den första utvecklingsomgången. Undersök möjligheten och lägg den i en framtida utvecklingsplan.

## Smart hem

En idé om att styra kompatibla smarta hemprodukter genom naturliga röstkommandon.

Exempel:
"Earmind, släck alla lampor."

Det är ännu inte bestämt om detta ska utvecklas. Undersök om det ger tillräckligt stort mervärde.

## Generell felsökning

Earmind ska kunna hjälpa användaren felsöka exempelvis:
- Wi-Fi-problem.
- Elektronik.
- Apparater.
- Tekniska problem i hemmet.

Bilmekanikern och Felsökaren hemma bör inte automatiskt bli två separata funktioner. Det kan räcka att standardagenten redan kan hantera dessa frågor.

Undersök om det finns ett konkret behov av en separat felsökningsfunktion.

# 5. Idéer som vi tills vidare väljer bort

Följande förslag bör inte prioriteras i nuläget:

- Scamvakten.
- Parkeringsminnet.
- Livecoach för hantverk.
- Bilmekanikern som separat funktion.
- Reseassistenten.
- Scenbeskrivaren, eftersom Earmind inte har en etablerad kamerafunktion för detta användningsfall.
- Personlig ekonomichef.
- Klädstylisten.
- Koncentrationsvakten.
- Kreativa gnistan.
- Museum i örat.
- Namnspanaren som separat funktion.
- Säkerhetskompisen som separat funktion.

Det betyder inte nödvändigtvis att allt är dåligt. Det betyder att de inte ska ta utvecklingsfokus från mer värdefulla funktioner.

# 6. Mycket viktigt: Funktionerna måste vara synliga för användarna

Det här är ett centralt produktkrav som jag vill att du granskar och utvecklar.

Earmind kan ha massor av funktioner, men om användaren inte vet att de finns kommer de inte att användas.

Exempelvis kan en användare använda Earmind i månader utan att upptäcka att den kan hjälpa till med matlagning.

Därför är ett förslag att skapa ett tydligt funktionsbibliotek i appen.

Det bör innehålla:

- Namnet på varje funktion.
- En enkel beskrivning av vad den gör.
- Konkreta exempel på röstkommandon.
- Vilka behörigheter eller integrationer som krävs.
- Om funktionen är tillgänglig, under utveckling eller kommer senare.

Samma funktioner bör presenteras på Earminds webbplats.

Webbplatsen ska tydligt visa vad Earmind kan göra, med konkreta vardagsscenarier och exempel på vad användaren faktiskt kan säga.

Undersök hur detta kan integreras i den befintliga appdesignen utan att skapa en överlastad användarupplevelse.

Jag vill även att du undersöker möjligheten till kontextuella rekommendationer som gör att användare upptäcker funktioner i rätt situation.

# 7. Din självständiga granskning

Jag vill inte att du bara skriver om dessa idéer.

Gör en ordentlig egen analys.

För varje funktion som du rekommenderar bör du bedöma:

1. Verkligt användarvärde.
2. Hur mycket tid den sparar.
3. Hur ofta målgruppen kan tänkas använda den.
4. Hur unik och marknadsförbar den är.
5. Teknisk genomförbarhet i iOS 26.
6. Vilka behörigheter som krävs.
7. Externa API:er och tjänster.
8. Driftkostnader.
9. Integritets- och App Store-risker.
10. Utvecklingsinsats.
11. Risk för överlappning med befintliga Earmind-funktioner.

Skilj tydligt mellan:
- Tekniskt möjligt.
- Möjligt med begränsningar.
- Osäkert och kräver tester.
- Inte möjligt med nuvarande iOS-begränsningar.

Hitta inte på API:er, bakgrundsbehörigheter eller systemfunktioner.

# 8. Leverans

Jag vill att du levererar:

**A. Din granskning**

Vilka av förslagen är faktiskt värda att bygga? Vilka bör förkastas eller kombineras?

**B. En förbättrad produktlista**

Ta fram en slutlig lista med de bästa nya funktionerna, med bra namn och tydliga beskrivningar.

**C. Prioritering**

Rangordna funktionerna efter användarvärde, wow-faktor, utvecklingsinsats och kommersiell potential.

**D. Teknisk bedömning**

Förklara hur de bästa funktionerna skulle implementeras i det befintliga Earmind-projektet.

**E. Appens och webbplatsens funktionsbibliotek**

Föreslå hur vi kan presentera och göra användarna medvetna om Earminds funktioner.

**F. Rekommenderad utvecklingsordning**

Föreslå vad som bör byggas först, vad som kan vänta och vad som inte bör byggas alls.

## Slutlig instruktion

Var kritisk. Jag vill hellre ha fem riktigt bra nya funktioner än tjugo halvbra.

Utgå från den befintliga kodbasen och arkitekturen när du granskar möjligheterna. Gör ingen onödig ombyggnad av sådant som redan fungerar.

Allt i rapporten är förslag. Du ska själv komma fram till vad som är bäst för Earmind.