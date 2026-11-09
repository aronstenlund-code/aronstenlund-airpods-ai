# A6 – Musik ↔ Lumen och egna kommandon (Angela, 2026-11-09)

Kort:
- **Byggt:** musikkommandon ("nästa låt", "förra låten", "pausa musiken", "spela musik"), Spotify-styrning via
  Spotifys iOS-SDK och en kommandotabell med egna fraser (Inställningar › Röstkommandon). A7 bygger på tabellen.
- **Vägen från musik tillbaka till Lumen** blir Siri, Action-knappen eller kontrollen.
- **Status:** grönt i CI (körning 42654364887). **Inget verifierat på enhet.**

## 1. Lumen → musik
| Väg | Hur | Status |
|---|---|---|
| "Lumen, pausa" / "spela musik" (D58) | Ljudsessionen släpps med `notifyOthersOnDeactivation`, och Spotify, som Lumen avbröt, fortsätter. | Finns. **Verified in docs**, ej på enhet. |
| Ett tryck på AirPods medan Lumen lyssnar (D74) | `MPRemoteCommandCenter` play/pause/toggle går till Lumen, som är Now Playing. Samma paus som ovan. | Finns. **Untested on device.** |
| "nästa låt" / "förra låten" | Lumen säger "Nästa låt." och släpper ljudet. Efter 0,8 s byter Lumen låt i Spotify, eller i Apple Music. | Nytt. **Untested on device.** |

## 2. Musik → Lumen: beslut (b)
- **(b) Siri "Starta Lumen", Action-knappen eller kontrollen (D58). Valt.**
  - Fungerar handsfree med låst skärm, och kostar ingenting medan musiken spelar.
  - Status: **verified in docs** (App Shortcuts från låsskärm). Siri-frasen är **ej verifierad på enhet**.
- **(a) Lyssna efter "Lumen" i iPhone-mikrofonen medan musiken spelar** (`.mixWithOthers`, A2DP ut, igenkänning i
  telefonen). **Möjlig med begränsningar, inte byggd.**
  - Den orange pricken lyser hela tiden.
  - Batteri: igenkänning hela tiden.
  - Risk att ljudvägen byts.
  - Inspelning i bakgrunden är tillåten med läget `audio`.
  - Kan byggas om Aron vill ha det trots pricken. Det är en fråga till Aron.
- **(c) Spotify App Remote** kan inte starta Lumen, bara styra Spotify.
- **AirPods-trycket när Spotify spelar** går till Spotify. iOS bestämmer det (**verified in docs**: Now Playing-appen
  får fjärrkommandona), så trycket kan inte ta tillbaka Lumen.

## 3. Spotify-styrning
**Beroende:** Spotify iOS SDK 5.0.1 (App Remote) via SPM, binärt xcframework. Inget OSS-licensnamn: Spotify
Developer Terms gäller. Står i DECISIONS (A6).

**Begränsningar (verified in docs, Spotifys README):**
- Spotify-appen måste vara installerad och spela när vi kopplar upp.
- Token kommer från ett appbyte till Spotify (Inställningar › Röstkommandon › Koppla Spotify) och gäller cirka en
  timme.
- Spotify ber appar koppla ner i bakgrunden, så vi kopplar upp per kommando och kopplar ner 2 s senare.
- Premium behövs bara för att spela en viss låt. Vi använder bara pausa, fortsätt och hoppa.

**Reserv:**
- Apple Music via `MPMusicPlayerController.systemMusicPlayer`, bara när dess kö har en låt (annars skulle den starta
  Apple Music i stället för Spotify).
- Annars: "Tryck två gånger på AirPods för att byta låt."

**Ingen nyckel i repot:**
- Client ID går från hemligheten `SPOTIFY_CLIENT_ID` via Info.plist till `LumenSpotifyClientID`.
- Utan den syns "Spotify: inte aktiverat" och Spotify gör ingenting.

**Aron gör så här (gratis):**
1. Gå till developer.spotify.com › Log in (ditt Spotify-konto) › Dashboard › **Create app**.
2. Fyll i:
   - App name "Lumen", description "Röststyrning av musik".
   - Redirect URI **`lumen-spotify://callback`** (exakt så), och klicka Add.
   - Under "Which API/SDKs are you planning to use?": bocka **iOS**.
   - Bundle ID **`com.rsolutions.lumen`**.
   - Godkänn villkoren › Save.
3. Öppna appen › **Settings** › kopiera **Client ID**.
4. Gå till GitHub › repot › Settings › Secrets and variables › Actions › **New repository secret**. Name
   `SPOTIFY_CLIENT_ID`, Secret: klistra in › Add secret.
5. Nästa IPA från main har Spotify. I appen: Inställningar › Röstkommandon › **Koppla Spotify (öppnar Spotify)**,
   en gång per timme du vill styra med rösten.
6. Under utveckling är appen i "Development mode", så bara ditt eget konto fungerar tills vidare. Lägg till fler
   under User Management.

## 4. Egna fraser (Inställningar › Röstkommandon)
**`CommandRegistry`** är en tabell för hela appen. Varje åtgärd har:
- id och titel;
- standardfraser och användarens fraser;
- om den fungerar utan "Lumen", nivå och bekräftelse.

**A6:s åtgärder:**
- pausa / spela musik, tillbaka till Lumen, nästa låt, förra låten, pausa musiken;
- byt läge, förhör mig, avsluta, det där var fel.

**Skärmen:**
- Lista med sökning.
- Lägg till eller ta bort per åtgärd (svep). Standardfraser märks "standard" och kan tas bort och komma tillbaka med
  "Återställ".

**Regler:**
- Hela yttrandet måste matcha, som i dag.
- En fras som redan hör till en annan åtgärd **nekas**.
- Vanliga ord ("ja tack") och en frasstart som låter som en fråga ("vad …") ger en **varning**.
- Egna fraser blir keyterms till Scribe.
- **Ändring:** "Lumen, det där var fel" skickar nu senaste turen till /feedback. Förut gick det som en instruktion.

## Tester
- `LumenTests/A6Tests.swift`:
  - frasmatchning;
  - negativa fall ("jag vill spela musik på festen", "vad heter nästa låt på skivan" …);
  - prefix ("byta till" före "byt");
  - egna fraser, borttagna standardfraser och återställning;
  - krockar och varningar;
  - att parsarna läser tabellen.
- Gröna i CI 42654364887. Spotify-paketet hämtades (5.0.1) och bäddades in i appen.
- **Ej på enhet:** Spotify-kopplingen, låtbytet, Apple Music och AirPods-trycket. Inget av det går att prova i
  simulatorn.

## Till Toby
Lägg gärna in en rad per del i `docs/DEVICE-TEST-QUICK.md` (din fil):
1. "Lumen, pausa": Spotify fortsätter.
2. Ett AirPods-tryck medan Lumen lyssnar: pausar.
3. "Hej Siri, starta Lumen" med låst skärm medan Spotify spelar: Lumen lyssnar.
4. "Lumen, nästa låt" med och utan kopplad Spotify.
5. Inställningar › Röstkommandon: lägg till "byt låt" under Nästa låt och säg det.

## Kända risker
- Spotifys token gäller cirka en timme. Sedan måste Spotify kopplas igen i förgrunden. Utan en token-server (backend)
  går det inte att förnya i bakgrunden, och en sådan kostar ett eget backendjobb.
- `perform(selector)` används för Spotifys spelarkommandon, så att Swift-namnen i SDK:n inte spelar roll. Fel namn
  syns först på enhet, men selektornamnen kommer från SDK:ns headerfiler.

## Concerns
Inga.

## Nästa
A7 (byggd på samma tabell).
