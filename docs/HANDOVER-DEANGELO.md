# Överlämning: Deangelo (projektledare), 2026-11-09 22:00

Läs först: `CLAUDE.md`, `docs/STATUS.md`, `prompts/queue/BOARD.md`, `prompts/queue/README.md`, köfilerna i `prompts/queue/`, `docs/PRINCIPLES.md`, `docs/COMMANDS.md` och `docs/marketing/karaktar.md`.

## Hur Aron vill ha det
- Svara alltid på **svenska**, kort och med en sammanfattning. Detaljerna skrivs i repot.
- Märk påståenden med verifierat, möjligt, möjligt med begränsningar eller ej verifierat.
- Prompter till sessioner:
  - Börja aldrig med "Du är …" till en session som redan kör.
  - Ange alltid effort.
  - Skriv ut hela prompten när något läggs till.
- Uppdrag läggs i `prompts/queue/<namn>.md`. Aron skickar bara "kolla kön". Självväckning med `send_later` har inte fungerat.
- Ha koll på tavlan (`BOARD.md`): modell, effort, vad varje session gör och vad den kommit fram till.
- **Öppna saker åt Aron** i webbläsaren när du föreslår dem, så att han bara behöver trycka.
- Aron fattar egna beslut. Verkställ dem, men säg rakt ut när något bryter mot regler eller CLAUDE.md, och flagga det.

## Läget
- **Backend:** Provläge kör Sonnet 5.5, och 91,6 % av första svaren räcker. Första ljudet kommer efter 2,2 s (p50). API-nyckeln ligger i Max-kontots Console-organisation (100 USD API-kredit/mån). Gmail-organisationens nyckel finns kvar som reserv.
- **TTS:** ägarbeslut att byta till `eleven_v4_turbo` (K14). Aron tycker att demoljudet låter dåligt, och svenska kandidatröster jämförs i O12.
- **App:** A1–A12 och A14 är klara. Pågår: A13 (design och Elias i introt). I kö: A15 (mer-fönster), A16 (övningsprov), A17 ("igen").
- **Demosida:** live med Elias i en scrollstyrd hero. Ke8 lägger honom i ett kort med budskap, eftersom friläggningen såg oproffsig ut. `site/` får vara högst 2 MB (i dag 1,7 MB).
- **Karaktär:** Elias, 17 år, i varm stiliserad 3D (se `docs/marketing/karaktar.md`). Hörluren ser ut som en AirPod, och det är en möjlig risk i granskningen (5.2.5).
- **Google AI Studio** (Aron själv, stenlundaron@gmail.com): 50 kr förbetalt, auto-reload av, cirka 15 kr använt. Nyckeln måste väljas om i varje ny chatt. Omni kan bara göra 16:9 eller 9:16, så startbilden ska ha samma format.
- **Telefon:** iPhone 14 Pro, Sideloadly, appen går ut **lör 14 nov**. TestFlight kräver ett Apple Developer-konto, som Aron köper senare.

## Öppna beslut och saker att ta upp
- Namnet (Lumen, Proviska eller Testvisk).
- En vuxen karaktär till annonser för Socialt och Rizz (inte Elias, inget med alkohol i fokus).
- Hörluren i bilden: byta till en rund modell utan skaft?
- Aron vill ha dolda kodord ("atjo", "oj") för att få svar på frågan man är på. **Avböjt som fuskfunktion.** Den legitima varianten (övningsprov med "nästa") är K15/A16. Flaggat under Concerns.
- Spotify Client ID (stegen finns i Angelas A6-rapport).
