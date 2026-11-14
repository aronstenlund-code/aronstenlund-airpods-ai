# Angela Fable: vyerna i A94 (första starten) och A93 (Gör med ChatGPT)

Datum: 2026-11-14 10:57. Uppdrag: Aron i sessionen 09:54 ("vyerna för A94 … och vyn för A93 … Angela Schrute gör
logiken. Skärmbilder till Kelly."). Underlag: Kellys `docs/design/forsta-starten.md` (Ke55) och
`docs/design/gor-med-chatgpt.md` (Ke58), D169, D170.

**Inget är provat på telefon eller med AirPods.** Allt nedan är CI (Simulatorn och enhetsbygget) och kodläsning.

## Vad som är byggt
### A94: första starten (högst 3 skärmar före kameran, ingen BETA)
| Skärm | Fil | Innehåll |
|---|---|---|
| 1 Välkommen | ny `Lumen/Features/Onboarding/WelcomeView.swift` (`WelcomeView(onContinue:)`) | Appikonen, "Välkommen till Earmind", tre rader (Fota materialet, Lyssna i dina AirPods, Plugga utan mobilen), raden om vad som skickas med **Läs mer**, och **Fortsätt** fast nederst. Inget om lyssning, ingen mikrofon, ingen BETA. |
| Läs mer | samma fil, `DataPrivacySheet()` | "Data och integritet" med Klar: Det här skickas (med Kellys rad om ChatGPT), Det här sparas ("sparas hos Earmind"), Mikrofonen. |
| 2 Nytt prov | `NewDrillView(model:onLater:onSaved:)` | Första gången: raden "Börja med materialet till ditt nästa prov." i första sektionens rubrik, **Fota sidor** ensam i fet accentfärg, **Senare** i stället för Avbryt, fotnoten "iOS frågar om kameran första gången. Fotona sparas inte.", och sektionen Prov (namn valfritt, Vilken årskurs?, Antal frågor). Ingen rad Gör med ChatGPT här. |
| 3 Kameran | (fanns: `PageScanner`, systemets dokumentskanner) | Nytt: har iOS sagt nej till kameran öppnas inte en svart kamera. Formuläret säger "Earmind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket." med Öppna Inställningar (Ke50 §2). |

Flödet (Välkommen → Nytt prov → Hem), vad som sparas och scenerna är Angela Schrutes (1a29b0d, da6f53b, D170).

### A93: Gör med ChatGPT
Ny fil `Lumen/Features/Repetition/ChatGPTImportView.swift`:
- **Tre steg** i en lista, en knapp i varje: Kopiera prompten (blir "Kopierad" med grön bock på steget), Öppna
  ChatGPT, och systemets Klistra in-knapp (`PasteButton`, så iOS inte frågar om urklipp). Den fyllda knappen flyttar
  med stegen, en åt gången. Fotnoten säger att filerna hanteras av ChatGPT.
- **Hittade n frågor med svar**: de fyra första frågorna med kort svar, "och 16 frågor till", raden "x av 15 frågor
  kvar den här månaden" (bara när x > 0), "1 rad kunde inte läsas och togs inte med." som en stängd rad, röstvalet
  (D151, bara för ett nytt prov) och **Spara frågorna** fast nederst.
- **Svaret har inte rätt form**: en ruta med förklaring och Klistra in. Inget rött.
- Klistrar man in prompten i stället för svaret: "Det här är prompten, inte svaret. Kopiera svaret i ChatGPT först."
- Inga frågor kvar: "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 {december}."

Var den nås: raden **Gör med ChatGPT** sist i Material i Nytt prov (inte i första starten), **Skriv text** (ett svar
i K58-formatet visas som "Hittade n frågor" när man trycker Klar, i stället för att skickas som material) och
⋯-menyn på ett prov (provets frågor går med i prompten, bara nya frågor läggs till).

Logiken (`ChatGPTImport.read`, prompten, `saveImport`) är Angela Schrutes (8c44418, 01b677d, 99e1d9f, 2ce5521).

## Tekniska val (D171)
1. Raden om vad som skickas står kvar vid Fortsätt även i största text. Kelly föreslog (G2, lågt) att den kunde rulla
   med innehållet. Jag lät den stå: det är den Fortsätt godkänner. I stället försvinner appikonen i största text, så
   första raden börjar ovanför knappraden.
2. Klistra in är systemets knapp: iOS bestämmer text och utseende. Den är grå tills prompten är kopierad, så bara en
   knapp är fylld åt gången, men fungerar hela tiden. På felskärmen har den alltid accentfärgen (Kellys G1: den var
   bara nedtonad i bilden för att Simulatorns urklipp är tomt).
3. Öppna ChatGPT öppnar `https://chatgpt.com/`. **Otestat antagande:** att länken öppnar ChatGPT-appen när den är
   installerad. Ingen fråga till iOS om vilka appar som finns.
4. På ett befintligt prov ber prompten om max(20, antal frågor + 5) frågor, så det finns nya att lägga till.
5. Avbryter man "Hittade n frågor" från Skriv text ligger texten kvar som material.
6. Appens språk är nu svenska (`developmentLanguage: sv`, Angela Schrute), annars stod det "Paste" på knappen.

## Testresultat
| Vad | Resultat | Hur |
|---|---|---|
| iOS build **43580586859** (2ce5521) | **grönt**, `Lumen-unsigned` (ipa) uppladdad, enhetstesterna gröna | verifierat i CI. Innehåller A94 och A93 till och med röstvalet (7d78bc0) |
| iOS build 43582585113 (99c0f9c, Kellys två sista rättningar) | **går när det här skrivs, inte grönt än** | – |
| Simulator screenshots 43580443638 (17 Pro), 43580446583 (SE), 43580450489 (SE, största text), 43580454162 (17 Pro, största text), commit 1780d8b | gröna; ljust och mörkt | sett av mig: `reports/2026-11-14-a94-a93-bilder/` |
| Kellys granskning | **A94 och A93 godkända på bild**, två låga fynd | `reports/2026-11-14-1051-kelly-granskning-a93-a94.md` |
| Kellys fynd: glappet ovanför "Börja med materialet …", G2 (Välkommen i största text) | rättade i 99c0f9c, **inte sedda på bild än** (43582586280, 43582589071 går) | – |
| Kellys G1 | ingen ändring behövs (se val 2) | kodläsning |
| Telefon och AirPods | **inte provat** | – |

Otestade antaganden: att `PasteButton` ger texten utan iOS-fråga på en riktig telefon; att kamerafrågan kommer av
sig själv första gången man trycker Fota sidor; att bladet Gör med ChatGPT finns kvar när man kommer tillbaka från
ChatGPT (om iOS har stängt appen får man öppna raden igen och klistra in direkt); haptiken när prompten kopieras.

## Concerns
- **Samtyckets plats.** Fortsätt på Välkommen godkänner bara att materialet skickas för att göra frågor och ljud.
  Lyssningens samtycke (`ConsentView`) kommer första gången ett lyssnande läge startas under Fler lägen, och
  mikrofonen startar först efter "Jag förstår" (Angela Schrute, D170). Skyddsräckena i CLAUDE.md är oförändrade för
  lyssningen. Kelly (Ke55) bad om Deangelos ja till flytten: **det ja:et finns inte i repot än** (står på tavlan).
- **Läs mer måste vara sant.** Texterna är Kellys. Jag har inte kontrollerat mot servern att foton och text inte
  sparas, eller om repetitionslägets frågor och svar omfattas av D116 (skickas för analys). Kevin eller Deangelo bör
  bekräfta raderna under "Det här skickas" och "Det här sparas".
- **Gör med ChatGPT skickar användarens filer till OpenAI**, av användaren själv och utanför Earmind. Det står i
  bladets fotnot och i Läs mer. Många användare är 15–17 år: om det behöver stå mer än så är Arons eller Deangelos sak.

## Kända begränsningar
- Kellys skiss visar "Välj" på Vilken årskurs?; systemets väljare visar "Hoppa över" (Kelly: okej, D161).
- På "Hittade n frågor" ligger röstvalet under de fyra frågorna, under det synliga på en vanlig skärm.
- Kvoten: att inklistrade frågor räknas mot månadens frågor är inte verifierat mot servern (Kelly Ke58, Kevin).

## Återstår
1. Grönt iOS build på 99c0f9c och bilderna av de två sista rättningarna.
2. Deangelos ja till samtyckets plats (Ke55, D170).
3. Tobys T21 (ny användare i första starten) och hans tester som letade efter "Testa nu" (Angela Schrute har sagt till).
4. Enhetstest: hela vägen Välkommen → Fota sidor → första frågan i AirPods, och Gör med ChatGPT med ChatGPT-appen.
5. Sedan tidigare: Kellys P1 (fält från K49) och P2 (röstnamn).

## Nästa session
Läs Kellys granskning och tavlan, kontrollera bygget på 99c0f9c, och ta nästa punkt märkt Angela Fable i
`prompts/queue/angela.md`.

## Tillägg 2026-11-14 11:16: grönt bygge med allt, Kelly har stängt A93 och A94
**Fortfarande inget provat på telefon eller med AirPods.**
- **iOS build 43582585113 (99c0f9c) är grönt**, med `Lumen-unsigned` (ipa) uppladdad och enhetstesterna gröna. Det
  innehåller alla vyer i A94 och A93 och Kellys två sista rättningar. Verifierat i CI.
- De två rättningarna är **sedda på bild av mig** (Simulator screenshots 43582586280 = iPhone 17 Pro, 43582589071 =
  iPhone SE med största text): glappet ovanför "Börja med materialet till ditt nästa prov." är borta, och på SE med
  största text står rubriken och första raden (Fota materialet) ovanför raden med Fortsätt.
- Kelly 11:10: raden om vad som skickas ska stå kvar vid Fortsätt (val 1 i D171), G1 behöver ingen ändring,
  **A93 och A94 är stängda från hennes sida.**
- Punkt 1 under Återstår är därmed klar. Punkterna 2–5 står kvar.
