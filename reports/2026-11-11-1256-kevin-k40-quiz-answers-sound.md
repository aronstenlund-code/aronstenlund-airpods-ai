# K40: korta förhörssvar jämförs ljudmässigt (Kevin, 2026-11-11 12:56)

Uppgift: `prompts/queue/kevin.md` K40 (Arons telefontest 2026-11-11).
- Lumen frågade "Vilken flod rinner ut genom Egypten?", Aron svarade "Nilen", och Scribe hörde "Nilan" / "om ni har redan svarat".
- "Seine" uttalat "sän" hördes som "såg en".
- Appens del är A62, testet O43.

**Kostnad:** cirka 0,6 USD.
- Regressionen för `259f3f8`: 0,31 USD.
- Två live-körningar i Provläge (Sonnet): cirka 0,25 USD.
- Studieprofil med Haiku: 0,002 USD.
- ElevenLabs: 0.

## Vad som är byggt
**1. Svarsnyckel efter varje kontrollfråga** (`answer/prompt.ts` `QUIZ_KEY_RULE`, `answer/speech.ts`):
- När ett Provläge-svar (eller "förhör mig") slutar med en kontrollfråga skriver modellen en dold rad: `[[SVAR]] Nilen | Kongo, Niger, Zambezi, Amazonas`.
- Raden läses aldrig upp; den döljs som sammanfattningen och fungerar i båda ordningarna.
- Den skickas i `done.quiz_key` = `{"answer": "Nilen", "alternatives": ["Kongo", …]}`.

**2. Svaret jämförs ljudmässigt** (`answer/soundalike.ts`):
- Det sker när appen skickar tillbaka nyckeln som `context.quiz_key` och eleven svarar inom svarsfönstret (`gradeReply`, 2 minuter).
- Metoden är en svensk fonetisk nyckel (sj/tj/k/g före mjuk vokal, dubbelkonsonanter, ä=e, å=o …) plus redigeringsavstånd över fönster om 1–3 ord, så att "ni len" blir "nilen".
- Svenskt uttal av utländska namn finns i en tabell ("sän" = Seine, "loar" = Loire, "rån" = Rhône, "marsej" = Marseille, "bordå" = Bordeaux …) och via franska stavningsregler.
- **Besked:**
  - **correct**: modellen får "It is RIGHT: start with Rätt."
  - **near**: "Menade du Seine? Rätt i så fall."
  - **alternative**: låter som ett av de felaktiga alternativen.
  - **none**: modellen avgör själv.
- `done.quiz_sound` = `{verdict, answer}` visar beskedet, för appen och för loggen.

**3. Utan nyckel** (innan A62 finns) säger bedömningsregeln (`GRADE_NOTE`):
- svaret kommer från taligenkänning och är ofta felhört;
- bedöm om det **låter som** rätt svar, även med svenskt uttal av utländska namn;
- tolka det aldrig som en kommentar eller ett kommando;
- är det osäkert: "Menade du …? Rätt i så fall."

**4. `/study-profile`:**
- Profilen har ett nytt fält, `topic` ("50 mest kända sjöar, floder och kuststäder").
- När ämnet är en mängd namn blir `terms` själva namnen (Vänern, Ladoga, Viktoriasjön, Göta älv, …; 50 stycken) och inte bara ämnesord.
- Det första live-försöket gav en tom profil: svaret med 50 namn gick inte att tolka. Nu repareras avslutande kommatecken och avklippta listor, och taket är 1 200 tokens.

## Tester
- **Ljudbanken** `backend/testdata/k40-quiz-sound.json`: **43 fall** (Nilen, Seine, Loire, Rhen, Donau, Volga, Mississippi, Amazonas, Ladoga, Viktoriasjön, Bajkalsjön, Vänern, Marseille, Bordeaux, Göteborg, Lissabon, Themsen; felhörda rätta svar och felaktiga svar): **43/43**. Fallen är skrivna av mig, så Oscars O43 är det oberoende provet.
- `deno task test`: **470 gröna** (ny `answer/k40_test.ts`; `study-profile/handler_test.ts` uppdaterad). `deno task check` är ren.
- **Live, driftsatt (`259f3f8`, `56ee5b9`), Provläge Geografi åk 8:**
  - Svarsnyckeln kom 3/3, och 0 gånger lästes den upp ("Vilken flod rinner genom Kairo …?" gav `{answer: "Nilen", alternatives: [Kongo, Niger, Zambezi, Amazonas]}`).
  - Med nyckeln: **7/7**:
    - "Nilan" och "ni len" gav "Rätt.";
    - "såg en" gav "Menade du Seine? Rätt i så fall.";
    - "sän" gav "Rätt.";
    - "Loire" gav "Inte riktigt. Det är Seine …";
    - "mar säj" gav "Rätt." (Marseille);
    - "Vänern" gav "Inte riktigt" (Ladoga).
  - **Arons eget fall utan nyckel**, "om ni har redan svarat", ger nu "Menade du Nilen? Rätt i så fall."
  - `/study-profile` med Arons mening gav topic plus 50 namn, två gånger av två.
  - Rådata: `reports/eval/2026-11-11-125601-k40-quiz-live.json` och den första körningen `reports/eval/2026-11-11-125251-k40-quiz-live.json`.
- **Regressionen:** 90,5 % (term 4/6). De två fall som föll gäller svenska i svaren: "lövkorg" och "en skräckvälde". Ingen nyckel läckte i de 21 svaren.
- **Ej verifierat:** på telefon och med riktig Scribe. Appen ska ge nyckeln till Scribe som keyterms (A62).

## Till Angela (A62)
- **Spara `done.quiz_key`** från svaret som slutade med kontrollfrågan.
- **Ge `answer` och `alternatives` till Scribe** som keyterms för svarsfönstret.
- **Skicka nyckeln med** i nästa `/answer` som `context.quiz_key` (samma form).
- **Läs `done.quiz_sound`** om du vill visa "Menade du …?".
- Tolka **inte** yttrandet som ett kommando i svarsfönstret förrän servern har svarat. Det gäller till exempel "har redan svarat".
- `profile.topic` från `/study-profile` ska sparas och skickas med som de andra profilfälten.

## Begränsningar
- Om modellen glömmer `[[SVAR]]`-raden finns ingen nyckel. Då gäller bara bedömningsregeln (punkt 3).
- Ett felhört svar som låter som både rätt svar och ett alternativ ger "near" eller "none". Därför säger modellen hellre "Menade du …?" än "Rätt".
- I testkörningen kom samma fråga tre gånger. Det berodde på att skriptet inte skickar `already_asked`, vilket appen gör.

## Nästa
Oscar: O43 (oberoende fall, gärna med riktiga Scribe-felhörningar).
