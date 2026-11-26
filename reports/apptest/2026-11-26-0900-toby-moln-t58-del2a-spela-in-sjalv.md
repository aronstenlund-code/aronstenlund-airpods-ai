# T58 del 2a: Spela in själv, kärnan från appens egen koppling (Toby (moln), 2026-11-26 09:00)

Uppdrag: T58 punkt 2 (Deangelo 2026-11-26 08:49), D263. A164 (Angela Schrutes kärna) ligger på main (84408a65). A165 (Angela Fables vyer och bladet vid 402 och `provider_*`) ligger inte på main än, så del 2b, bladet och knapparna, väntar.

## Vad testet gör

`AppTests/E2E/OwnDeck/OwnDeckE2ETests.swift` (Swift Testing, `@testable import Lumen`). Körs med `scripts/apptest/t58.sh` och `.github/workflows/apptest-t58.yml` på en macOS-maskin.

- **Hela appens koppling:** `AppContainer()`, `listening.repetition` och dess `ownDecks`, och den riktiga provspelaren (`RepetitionSession`, `FileRepetitionAudioSource`) som spelar riktiga filer i Simulatorn.
- **Låtsasinspelning:** simulatorn i CI har ingen mikrofon. Kärnans inspelare ligger bakom protokollet `OwnRecording`, så testet sätter en egen inspelare i mikrofonens ställe. Den skriver 1,5 s tystnad som AAC i den m4a-fil appen ber om. Därför behövdes ingen ny krok i appen, och den första kroken jag bad om behövs inte längre.
- **Inga nätanrop:** en `URLProtocol` i testprocessen stoppar och skriver upp **varje** http(s)-anrop från att samlingen skapas tills övningen är slut. `/answer`, `/stt-token` och `/tts` är stängda hela tiden.
- **Krediterna:** läses från riktiga `/drill quota` före och efter. Grinden är bara öppen för de två läsningarna.

## Resultat (Apptest own deck 45785180053, `toby/t58b` 3690f0a6, Simulator iPhone 17 Pro iOS 26.5, Xcode 26.6). Grön i första körningen.

| Fall | Utfall | Anrop under övningen | Krediter |
|---|---|---|---|
| make-record-practise | ok | 0 | 1500 → 1500 |
| seeded-practise (`-SeedOwnDeck 1`) | ok | 0 | 1500 → 1500 |

- **make-record-practise:**
  - Samlingen "T58 Biologi" fick två kort, skrivna med `addCard` och `setText`.
  - Kort 1 spelades in, fråga och svar, med låtsasmikrofonen (2 starter). Båda inspelningarna sparades: `….m4a` finns i `Application Support/OwnDecks/audio`, och mappen är utanför säkerhetskopian.
  - Kort 2 har ingen inspelning och läses av telefonens egen röst (AVSpeechSynthesizer, inte ElevenLabs).
  - `start(own:)` gav spelaren och spelarskärmen (`showsPlayer`), med provet "T58 Biologi" och 2 frågor.
  - Spelaren gick: question 0 → thinking 0 → (ett tryck) answer 0 long → question 1 → thinking 1 → question 0, alltså ett helt varv (lap 1).
  - Provlagret (`DrillStore`) ändrades inte.
- **seeded-practise:**
  - Angela Schrutes krok gav "Glosor vecka 12" (sv) med 3 kort och en tyst telefonröst.
  - Spelaren gick: waiting 0 → question 0 → thinking 0 → question 1 → thinking 1 → question 2 → thinking 2 → question 0.

Allt detta är **verifierat i CI (Simulator)**. **Untested assumption:**

- att den riktiga mikrofonen och AirPods-mikrofonen spelar in, och att telefonens röst låter rätt i AirPods. Det kräver en telefon (Arons prov, A164 §6).
- att telefonens svenska röst finns i Simulatorn. Kort 2 spelades, men testet lyssnar inte på ljudet.

Sammanslaget till main (ba970b56, [skip ci]). Arbetsflödet ligger på main sedan a3bf1ffb, så att det går att starta för hand.

## Kvar

- **Del 2b (A165):** ingången "Spela in själv – helt gratis", vyerna i skärmturen, och bladet "Slut på krediter? …" när `/drill` eller `/answer` svarar 402 eller `provider_quota`. Det testas också i processen, med samma grind men 402/503-svar, och med en bild i skärmturen när Angela Fables vyer och id:n ligger på main.
- **Skärmturen med id:n:** `toby/t3-ids` (f77c0f68) letar efter raderna i Inställningar med `settings.*` och har texten kvar som reserv. Den körs när en macOS-maskin är ledig.

0 ElevenLabs, inga anrop till /answer. T1 är fortfarande röd med flit (D180). **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.
