# Kevin – Ljudhack i testsidan och /tts (D67)

## Orsak (verified in code, ej i öronen: jag har ingen enhet)
Testsidan spelade ett **separat mp3-klipp per mening** i ett enda `<audio>`-element. Tre saker ger "drar ut" och hackar:
1. **Glapp mellan klipp.** Varje klipp hämtades helt innan det började spelas, och hämtningen startade först när meningen var klar. Är nästa klipp inte färdigt när det förra tar slut (korta meningar!) blir det tyst en stund, och `ended` → ny `src` → `play()` ger extra 50–300 ms i Safari.
2. **mp3-kodarens utfyllnad** i början och slutet av varje klipp: små klickljud och "utdragna" skarvar.
3. **Fel ljudsession.** Uppspelningen låg kvar i samtalssessionen (`play-and-record`, med brusreducering) efter mikrofonen. Det låter tunnare och kan ducka/hacka.

## Ändring (`backend/webtest/index.html`, samma lösning går att flytta till appen)
- **Ett kontinuerligt PCM-flöde via Web Audio.** `/tts` anropas med `output_format: pcm_24000` (rå 16-bit PCM, ingen kodek, inga utfyllnader). Bitarna konverteras till `AudioBuffer` och schemaläggs **sample-exakt direkt efter varandra** (`nextAt += duration`) medan de strömmar in. Nästa mening hämtas **medan den förra spelas**. En liten jitterbuffert (0,25 s) före första ljudet efter tystnad.
- **Sammanslagning av korta meningar.** Första meningen går direkt till TTS (snabbast första ljud); resten slås ihop till klipp på minst 90 tecken (högst 440, gränsen är 500). Färre klipp, bättre satsmelodi.
- **Ljudläge i Safari.** `navigator.audioSession.type = "playback"` sätts innan första ljudet; mikrofonen är helt avstängd innan dess (`stopMicNow()`: alla spår stoppade, talbehandlaren avbruten, Scribe-kontexten stängd). `play-and-record` sätts bara när mikrofonen startar igen.
- **A/B och fallback.** Listan "Ljud: ström (PCM) / klipp (mp3)" i sidan; utan Web Audio används gamla vägen. Apples röst är kvar som reserv vid fel.
- **Röstinställningar.** `/tts` tar nu `voice_settings` {stability, similarity_boost, style, speed, use_speaker_boost} (validerade, ej i demon), och sidan har val för stabilitet/likhet samt ett **Röstlabb** som läser 10 meningar med långa svenska ord med flash, turbo och multilingual och visar tid till första ljud (median/max) och låter dig lyssna.

## Test
`node backend/webtest/pcm_test.cjs` (Playwright + Chromium, ingen nätverkstrafik): stubbar `/answer` (fyra korta meningar) och `/tts` (PCM) och kontrollerar att **(1) allt ljud är schemalagt utan glapp** (största glapp 0,000 ms), **(2)** första meningen går ensam och resten slås ihop (2 TTS-anrop för 4 meningar), **(3)** `audioSession.type` är `playback` vid första sampeln, **(4)** inga sidfel. Alla kontroller gröna. Enhetstest för `voice_settings` i `tts/handler_test.ts` (197 gröna totalt).

## Inte gjort / att verifiera
- **Verified on device: ingenting.** Hur det låter på iPhone + AirPods (och att `AudioContext` på 24 kHz startar i Safari efter mikrofonen) måste lyssnas på. Fallbacken (mp3) finns kvar för jämförelse.
- **Modell- och inställningsval (punkt 2):** mätningen kräver driftsatt `/tts` med `voice_settings` och öron. Röstlabbet är byggt för att ägaren ska kunna köra det själv; tills dess **untested assumption**: flash (snabbast), stabilitet 0,5, likhet 0,75. Högre stabilitet minskar utdragna ljud men gör rösten plattare.
- Driftsättning av `tts` väntar på `supabase-lumen` (se STATUS).

## Så görs det i appen (för Angela)
1. Begär `pcm_24000` (eller `pcm_16000`) från `/tts`, spela med **en** `AVAudioEngine` + `AVAudioPlayerNode`; skapa `AVAudioPCMBuffer` av varje inkommande bit och `scheduleBuffer` direkt efter den förra (inga nya noder per mening).
2. Starta hämtning av nästa mening medan den förra spelas; slå ihop korta meningar (>= 90 tecken, första direkt).
3. Sätt sessionen till `.playback` (eller `.playAndRecord` med `.voiceChat` bara när mikrofonen behövs), ta bort mikrofonens tap och stoppa `AVAudioEngine`s input innan första bufferten, och återställ när mikrofonen ska lyssna igen.
