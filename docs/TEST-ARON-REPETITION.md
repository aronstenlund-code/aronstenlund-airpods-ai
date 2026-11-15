# Testa repetitionsläget på telefonen

Kelly (moln), Ke65, 2026-11-15. Ersätter Tobys lista från 2026-11-13. Det här är bara det som kräver din iPhone och dina
AirPods. Resten testar Toby i simulatorn.

**Bygget:** iOS build **43721548487** (6cc6307) eller nyare, grönt på main. Installera med Sideloadly som förut
(`docs/INSTALL-SIDELOADLY.md`).

> **ElevenLabs har 0 krediter tills du fyller på.** Då kan inget nytt ljud göras. Del A går att göra nu, och vid
> Starta prov ska appen säga **"Ljudet kan inte göras just nu. Försök igen om en stund."** Det är rätt, inte ett fel.
> Del B (trycken, utan nät, dela) kräver ljud: fyll på krediter först, eller använd ett prov som redan har ljud.

Text att klistra in (eller fota en sida ur en bok):
> Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial.

## Del A: går nu, utan krediter (cirka 5 min)
| Steg | Gör så här | Det här ska hända | Skicka tillbaka |
|---|---|---|---|
| A1. Nytt prov: Frågor | **Nytt prov**. Under **Gör** står **Frågor** valt. Tryck **Fota sidor** och fota en sida (eller **Skriv text** och klistra in texten). Antal frågor **5**. **Skapa frågor**, sedan **Ser rätt ut**. | Provet har 5 frågor med svar. Under namnet: "Ljudet görs när du startar provet." Inget ljud görs än. | ok / vad som var fel |
| A2. Redigera ett svar | Tryck på fråga 2. Ändra ett ord i svaret. **Spara**. | Ändringen syns i listan. Fotnoten säger "Ljudet görs när du startar provet. Ändra så mycket du vill först." | ok / fel |
| A3. Nytt prov: Läs upp texten | **Nytt prov**. Välj **Läs upp texten** under **Gör**. Fota en sida eller klistra in texten. **Skapa uppläsning**, sedan **Ser rätt ut**. | Antal frågor och årskurs försvinner. Stämmer det här? visar rubriker och "Texten räknas som 1 fråga". Provet visar hela texten. | ok / fel |
| A4. Starta prov utan krediter | Öppna provet från A1. Under knappen: "Räknas som 5 av dina … frågor kvar." Tryck **Starta prov**. | Spelaren öppnas och säger **"Ljudet kan inte göras just nu. Försök igen om en stund."** Avsluta fungerar. | Kom meningen? Minskade antalet frågor kvar ändå? (*untested assumption* att de inte räknas när ljudet misslyckas) |

## Del B: efter påfyllda krediter (cirka 10 min)
Båda AirPods i öronen, ingen annan app spelar (pausa Spotify).

| Steg | Gör så här | Det här ska hända | Skicka tillbaka |
|---|---|---|---|
| B1. Starta prov (ljudet görs då) | Öppna provet från A1. Tryck **Starta prov**. Titta uppe till höger. | "Gör ljudet …" och sedan första frågan i AirPods inom några sekunder. Första gången visas **Styr med dina AirPods** först: tryck 1, 2 och 3 gånger när appen ber om det. **Ingen orange prick** (mikrofonen). | Sekunder till första frågan. Bockar på alla tre? Prick ja/nej. |
| B2. 1, 2 och 3 tryck (låst skärm) | Lås telefonen. Under en fråga eller tystnaden efter: tryck **1 gång** (3 frågor), **2 gånger** (3 frågor), **3 gånger** och sedan 3 igen. | 1: hela långa svaret. 2: bara första meningen. 3: paus, och 3 igen fortsätter från början av meningen. | Rätt av 3 för 1, 2 och 3 tryck. |
| B3. Läs upp texten | Öppna texten från A3 och tryck **Starta prov**. Tryck **1 gång** (paus), **1 gång** (fortsätt), **2 gånger**, **3 gånger**. Tryck på en mening på skärmen. | Meningen som läses är markerad. 1: paus/fortsätt från meningens början. 2: nästa mening. 3: förra meningen. Tryck på en mening läser därifrån. | ok / fel per tryck |
| B4. Utan nät | När ljudet är klart: slå på **Flygplansläge**. Avsluta och starta provet igen. Öppna **Nytt prov**. | Provet spelas som vanligt. Nytt prov säger "Ingen internetanslutning …" och Skapa frågor är grå. Dela och Publicera säger att de fungerar när du är uppkopplad. | ok / fel. Stäng av flygplansläget efteråt. |
| B5. Publicera | I provet: **⋯ › Publicera prov**. Välj skola, ämne och provdatum. **Publicera prov**. | Provet syns under **Prov från din skola** för den skolan. Ta bort publiceringen efteråt i samma meny. | ok / fel |
| B6. Dela | Tryck **Dela** (pilen uppåt) och skicka länken till dig själv i Meddelanden. Öppna länken. | Provet läggs till med frågor, svar och ljud. Det räknas inte mot dina frågor. | ok / fel |

Avsluta alltid med **Avsluta** i appen.

## Skicka tillbaka
En rad per steg i chatten, till exempel: "A1 ok. A2 ok. A3 ok. A4 meningen kom, kvar 12 → 12. B1 4 s, 3 bockar, ingen
prick. B2 3/3, 3/3, 3/3. B3 ok. B4 ok. B5 ok. B6 ok." Skriv också iPhone-modell, iOS-version och vilka AirPods.

## För Toby
- A4: kontrollera i serverns logg att inget ElevenLabs-anrop gick igenom och att kvoten inte räknades när ljudet
  misslyckades (D191). Stämmer det inte, skriv det till Kevin.
- B1–B3 är det enda som visar riktiga AirPods-tryck och låst skärm. Simulatorns resultat står i Tobys rapporter (T24, T28).
