# Granskning av ChatGPT:s funktionsrapport (Deangelo, 2026-11-11)

Underlag: `docs/ideer/chatgpt-rapport-2026-11-11.md`. Allt är förslag tills Aron säger ja. Märkning: **möjligt / möjligt med begränsningar / osäkert, kräver test / inte möjligt**. Kontrollerat mot koden där det står "finns".

## A. Vad som redan finns (bygg inte om)
- **Väder** finns delvis: `web.ts` söker på SMHI när man frågar om väder i en ort. Saknas: "här" (plats), snabbhet och regn timme för timme.
- **Matlagning** finns i bitar: frågor, timers (A48), minnet ("mitt favoritrecept"). Saknas: steg-för-steg-läge och flera namngivna timers.
- **Funktionsbiblioteket** är påbörjat: "Vad kan Lumen?" (A52). Saknas: status (finns / kommer), webbplatsen, och tips i rätt situation.
- **Felsökning, prisfrågor och vanlig kunskap** sköter standardagenten redan med webbsökning. Ingen egen funktion behövs.

## B. Bedömning
| Förslag | Värde | Hur ofta | Unik | Teknik | Insats | Beslut |
|---|---|---|---|---|---|---|
| **Funktionsbibliotek + tips i rätt situation** | Mycket högt: funktioner som ingen hittar finns inte | Varje dag | Medel | möjligt | Liten–medel | **Bygg först** |
| **Matlagningsläget** (recept steg för steg, "nästa", flera timers med namn, byta ingrediens, ändra portioner) | Högt | Flera gånger i veckan | Hög ("handsfree i köket") | möjligt, nästan bara befintliga delar | Liten–medel | **Bygg** |
| **Väder här** (SMHI:s öppna API + plats när appen används; regn kommande timmar) | Medel–högt | Varje dag | Låg, men förväntat | möjligt. SMHI är gratis; WeatherKit kräver betalt Apple Developer-konto | Liten | **Bygg (snabb vinst)** |
| **Avgångskollen** ("säg till när jag ska gå av", nästa avgång, förseningar) | Mycket högt för målgruppen | Varje dag | Hög | möjligt med begränsningar: Trafiklab har nationella tidtabeller (GTFS Sverige) och realtid för många regioner, men **täckningen är inte verifierad**; "säg till när" kräver platsövervakning i bakgrunden (zoner runt hållplatsen, iOS tillåter det med tillåtelse "Alltid"), vilket kostar batteri och App Store-granskning av platsbehörigheten | Stor | **Bygg, Stockholm först**, sedan fler regioner när realtiden är kontrollerad |
| **Matloggen** (säga vad man äter, uppskattade näringsvärden, allergivarning) | Medel–högt | Varje dag för de som använder den | Medel (många kaloriappar) | möjligt; uppskattning från tal är grov, Livsmedelsverkets databas är öppen | Medel | **Bygg senare, med försiktig design:** loggen och allergivarningen först; kalorier och mål bara om användaren själv slår på dem, aldrig mål om viktminskning för användare under 18, alltid "ungefär" |
| **Röstöversättaren** | Högt | Sällan | **Låg:** Apple har redan Live-översättning med AirPods i iOS 26 (ej kontrollerat i detalj vilka modeller) | möjligt med begränsningar, 2–4 s fördröjning per mening | Medel | **Vänta**, gör bara "hjälp mig säga det här på spanska" i standardagenten |
| **Mötesminnet** | Medel–högt (jobb) | Varje vecka | Medel | möjligt (bygger på Standardläge + minne) | Medel | **Senare**: kräver samtycke från de andra och GDPR-genomgång; passar inte målgruppen 13–25 först |
| **Prisjämföraren** | Medel | Sällan | Låg (Prisjakt) | möjligt via webbsökning | Liten via sökning | **Inte egen funktion** |
| **Smart hem** | Medel | Varje dag för de som har det | Låg | möjligt (HomeKit med tillåtelse) | Medel | **Senare** |

## C. Slutlig lista (de fem som är värda att bygga, i ordning)
1. **Upptäck Lumen** (funktionsbibliotek + tips i rätt situation): status per funktion, exempelfraser, vad som måste ställas in, samma lista på webbplatsen. Tips: efter tre timers "Visste du att jag kan guida dig genom ett recept?", kl. 16 före ett prov "Vill du köra dagens 10 minuter?". Högst ett tips per dag, går att stänga av.
2. **Köksläget**: "Earmind, hjälp mig laga kycklinggryta för fyra" → ingredienser, sedan ett steg i taget med "nästa", "upprepa", "hur gör man det?", flera timers med namn ("riset klart"), byt ingrediens.
3. **Väder här**: SMHI + plats. "Kommer det regna närmaste timmen?" svaras på 1 s.
4. **Avgångskollen**: Stockholm (SL) först, sedan Västtrafik och Skånetrafiken när realtiden är kontrollerad. "Säg till när jag ska gå av" med platszon runt hållplatsen.
5. **Matdagboken**: tal → logg, allergivarning, näringsvärden bara om man slår på det.

## D. Teknik (kort)
- 1–3 bygger på det som finns: verktygslagret (K35/A48), timers, minnet, `web.ts`. Inga nya externa kostnader utom SMHI (gratis).
- 4 kräver ett nytt serververktyg mot Trafiklab (API-nyckel, gratis nivå med gränser, ej verifierat för vår volym) och platsbehörighet i appen.
- 5 kräver en egen tabell (inte HealthKit först, så att det fungerar utan att dela hälsodata), Livsmedelsverkets livsmedelsdatabas för värden.

## E. Ordning
Vecka 1: 1, 2, 3. Vecka 2: 4 (Stockholm). Efter beta: 5, sedan Mötesminnet och Smart hem om användarna efterfrågar det.
