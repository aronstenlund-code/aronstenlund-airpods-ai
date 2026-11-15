# Kevin (moln): K74 – naturligare uppläsning utan att använda krediter – 2026-11-15 17:05

Aron: "ibland låter det rätt konstigt när jag lyssnar på AI:ns svar". Driftsatt i `aad5e5a` (deploy 43733041794 grön). **0 ElevenLabs-anrop** (enhetstester utan nät, livetest med testkonto och tystljud).

## Del 1 – regeltabell för röstens text
- Ny fil `backend/supabase/functions/drill/voicerules.ts`: `VOICE_RULES`, 45 regler med typ och språk (sv, en eller båda), körs som sista steg i `voiceText` efter K18/K66/K67 (siffror, enheter och formler var redan ord). Bara det rösten får ändras; den sparade frågan, svaret och `screen` rörs inte.
  - **Förkortningar:** kap., fr.o.m., t.o.m., inkl., exkl., ung., jfr, obs, etc., "Ca" med stor bokstav, "stycken." mitt i en mening; på engelska e.g., i.e., etc., vs., approx. (t.ex., bl.a., osv., ca, s., nr fanns redan.)
  - **Parenteser** blir en kort inskjutning mellan kommatecken ("Fotosyntesen, som sker i bladen, ger socker").
  - **Snedstreck** mellan två ord blir "eller"/"or" ("han eller hon", "och eller").
  - **Punktlistor** inne i en rad ("• luft • vatten") blir en uppräkning med kommatecken.
  - **Symboler:** ~ (ungefär/about), %, °, °C, °F, &; på engelska → ± ≈ (på svenska fanns de redan).
  - **Citattecken** tas bort (" “ ” „ « » och enkla citattecken runt ord).
  - **Årtal och decimaltal:** var redan ord på svenska ("femtonhundratjugotre", "tre komma fem"); engelska behåller siffror (D182, rösten läser dem på engelska). Inget ändrat, men testat.
  - **Meningar över 30 ord** delas där de andas: semikolon eller kolon, en konjunktion efter kommatecken (men, och, så, eftersom …), annars ett kommatecken nära mitten, annars före "eftersom"/"because" ("Det beror på att …"). Minst 6 ord på var sida.
- **Versionerat per prov (D196):** `drills.voice_rules`. Nya prov får 2. Prov från före K74 behåller 1, alltså samma text och samma hashar, så en redigering eller Starta prov gör inget ljud om och räknar ingen kvot. Kopior får originalets version (de delar filer).
- **Mätt på verklig data:** 203 svar ur O63/O64-körningarna (`backend/testdata/voice/o63-o64-answers.json`). Före: 11 meningar över 30 ord, efter: 0. Inga parenteser, citattecken eller ordsnedstreck kvar, och inget ord som fanns före försvinner (testet jämför orden). 9 av 406 rösttexter ändras (modellens svar är redan rena; reglerna tar mest det som kommer från importerade och inklistrade svar).

## Del 2 – eleven_v4 förberett, av
- `eleven_v4` finns i `VOICE_MODELS` och i databasens kontroll, men `save` svarar 409 `voice_model_unavailable` så länge `drill_settings.allow_eleven_v4 = 0` (det är 0). Med `v4_pause_tag = 1` börjar ett v4-provs långa svar med en enda tagg, `[short pause]`, och var det korta svaret slutar flyttas med.
- Taggens stavning för v4 är en **untested assumption** (v3:s taggar står i hakparentes). v4 skickas utan `language_code`, som v3 (också **untested assumption**). `/voice-lab sample` tar `eleven_v4` för A/B-skriptet (bara service role).

## Del 3 – A/B-skriptet (inte kört)
- `scripts/k74-ab.py`: 5 vanliga A-svar (fråga + kort svar, rösttext version 2) ur `backend/testdata/voice/k74-ab-texts.json`, som v2, v4 och v4 med tagg. 15 filer, **3 046 tecken** (spärr vid 3 200). Namnen blandas (1A–5C) och facit går bara till `FACIT.md`, som i K48.
- **Kör ingenting** utan både `--yes-from-aron "<Arons ord och tid>"` och `K74_AB_CONFIRM=aron-ja` (exit 2, kontrollerat). `--dry-run` visar planen. Behöver `SUPABASE_SERVICE_ROLE_KEY`, alltså ett flöde som `voice-blindtest.yml`. **Till Aron:** säg ja i chatten om testet ska köras (cirka 3 000 krediter).

## Tester
- `deno task test` 641/641, `deno task check` grön. Nytt: `drill/voicerules_test.ts` (25 svenska och engelska fall, version 1 oförändrad, långa meningar, 203 verkliga svar, A/B-texterna stämmer med koden) och två fall i `drill/handler_test.ts` (version per prov, v4 nekas).
- **verified live** (`scripts/k74-live.py`, run 43733315221, plus SQL på `drill_audio_files`): nytt prov `voice_rules = 2`; rösten fick "Vad gör klorofyll, i bladen, …", "till exempel solljus", "kapitel tre och eller sidan tolv om fotosyntes från och med måndag", och den långa meningen delad: "… går förlorad. Det kan göra det ännu svårare …". Visningstexten oförändrad. `eleven_v4` gav 409.

## Begränsningar
- Inget är lyssnat på. Reglerna är bedömda på text; hur v2 läser "och eller" eller en delad mening hörs först i Arons telefon eller A/B-testet.
- Gamla prov (version 1) får inte de nya reglerna förrän de görs om. Att höja dem skulle göra om allt ljud och kosta krediter.
- Decimaler med flera siffror läses "noll komma två fem" (oförändrat, vanligt i skolan).

## Nästa
Oscar O68: listan med de 15 vanligaste konstiga sakerna (hans `o68_voice.py`) mot version 2. Det som återstår blir nya rader i tabellen.
