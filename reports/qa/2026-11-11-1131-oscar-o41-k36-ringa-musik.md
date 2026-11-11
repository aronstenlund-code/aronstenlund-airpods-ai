# Oscar O41: Oberoende test av K36 (ringa, musik, connections) och telefonverktygen i Standardläge

Datum: 2026-11-11, 11:26–11:31 (svensk tid)
Uppgift: stående uppgift (PLAN 2b). K36 (`reports/2026-11-11-1104-kevin-k36-spotify-calls.md`) är klar och saknar O-punkt. Fallen är nya, och inga av dem finns i `scripts/k36-tools-live.py`.

**Skript:** `scripts/qa/o41_k36_live.py`, plus `scripts/qa/o41b_k36_auto.py` (väckningsordet i Auto och Provläge).
**Rådata:** `reports/qa/data/2026-11-11-1129-o41-k36.json` och `…-1131-o41b-k36-auto.json`.
**Kostnad:** cirka 0,02 USD (Haiku), 0 ElevenLabs. Spotify-kopplingen är inte testad, eftersom nycklarna saknas.

## BLOCKER (prio 1): telefonverktygen fungerar inte i Standardläge
Servern erbjuder aldrig telefonverktyg när `mode` är `auto`:
- `answer/handler.ts:1250`: `phoneTools0 = … && body.mode !== "auto" && …`. Samma villkor gäller Spotify på rad 1252.

Appen skickar talade frågor i Standardläge som `mode: "auto"`:
- `ActivationController.fire(… trigger: .auto …)` leder till `ActivationTrigger.auto.backendMode == "auto"` (`ActivationSettings.swift`).
- Appen skickar dessutom `tools_available` just i Standardläge (`ListeningModel.swift:3110`, "A48 (K35): tools in Standardläge and Provläge"), men servern bortser från dem.

**Live, med samma anonyma användare och `tools_available`:**
| Yttrande | `mode: auto` (Standardläge) | `mode: tutor` (Provläge) |
|---|---|---|
| "Lumen, ring mamma" | inget verktyg, tyst | `call_contact` |
| "Lumen, sätt en timer på fem minuter" | inget verktyg, säger **"Jag kan inte starta timern här, så ställ den i din telefon eller klocka."** | `timer_start` |
| "Lumen, spela lite musik" | inget verktyg, säger **"Jag kan inte spela upp musik…"** | `music_open` |

**Märkning:**
- Servern: **verified live**.
- Att appen skickar `auto` i Standardläge: **verified in code**. Inte verifierat på telefon eller i simulatorn.

**Följd:** dagens mål 3 ("kalender, påminnelser och timers fungerar i appen") och kvällens prov ("En timer och en kalenderfråga fungerar på telefonen") misslyckas i Standardläge. Det gäller K35:s verktyg också, inte bara K36. Kevins live-tester körde `push_to_talk`, och det läget skickar appen bara från knappen "fråga om det senaste".

**Rättning (Kevin eller Angela, en av dem):**
- Antingen erbjuder servern verktygen i `auto` när yttrandet är riktat till Lumen (`direct`, väckningsordet), men aldrig för sådant som Auto bara råkar höra.
- Eller så skickar appen `push_to_talk` när eleven sagt "Lumen, …" i Standardläge.

Det första är säkrast, eftersom servern redan vet vad `direct` är. Kör sedan om tabellen ovan. Jag kan göra det på 1 minut.

## K36 för sig (`push_to_talk`, som Kevin): 26/29
| Grupp | Resultat |
|---|---|
| **B6: påhittade nummer.** "ring pizzerian / Systembolaget / Skatteverket / vårdcentralen i Tensta / min mentor / Bris" | **6/6 utan nummer**: bara namnet, appen slår upp det. **0 påhittade nummer** i verktyget och 0 i talet. På "vad är numret till pizzerian / Skatteverket" säger Lumen att den inte vet och nämner skatteverket.se |
| Ringa med namn ("Moa", "ringa upp farmor", "Ahmed på jobbet") | 3/3. Namnet blir "Ahmed på jobbet", vilket appens uppslag måste klara |
| Musik ("spela musik", "kör lite Håkan Hellström", "lyssna på lofi när jag pluggar") | 3/3 `music_open` med rätt sökning |
| Negation och framtid ("ring inte mamma", "jag måste ringa mamma sen") | 2/2 utan samtal ("Okej, jag ringer inte mamma.") |
| Andra betydelser ("ringa in ett svar", "spela teater", "musik är mitt favoritämne", Titanics nödanrop, "vilken låt spelas mest på Spotify") | 5/5 utan verktyg |
| **"mamma ringde nyss"** | **FEL: `call_contact` mamma** och samtidigt "Det låter som ett vanligt samtal, men jag kan inte se vad hon ville." iOS frågar innan samtalet, så det blir ingen skada, men det är ett falskt samtal |
| **"ring 112"** | **FEL:** inget verktyg. Lumen säger "Det här är ett nödnummer, så jag ringer inte det via kontakter. Om du behöver akut hjälp, ring ett ett två." I Auto ger "kan du ringa 112, hon har ramlat" bra instruktioner men inget samtal |
| **"ring noll sju tre, fyra fem sex, sjuttioåtta nittio"** (siffror i ord) | **FEL:** inget verktyg och helt tyst. Scribe skriver oftast siffror, men inte alltid |

**112:** iOS frågar ändå innan samtalet. 112 är ett verifierat nummer enligt B6, och att *inte* slå det när eleven ber om det är fel håll i en nödsituation. **Rekommendation:** `call_contact {number: "112"}` när eleven säger det, och samma sak för 1177, 116 111 och 90101 (B6-listan).

## Fynd i talet (prio 2, gäller hela Haiku-vägen)
Modellens resonemang hamnar i talet, ibland på engelska:
- "kör lofi" ger "**The request is to play music, so I'll open the music app with a lofi search.**" före verktyget.
- "att spela teater är roligt" ger "**Det är en statement, inte en fråga eller uppgift, så jag svarar kort och vänligt.** Det låter kul!"
- "vad har mamma för nummer" ger "**I can't read your contacts' numbers aloud**, but I can call her for you…" (hela svaret på engelska).

3/29 talade före verktyget (Kevins rapport säger 0). En av dem är okej: "Jag öppnar Spotify med Håkan Hellström." **Till Kevin:**
- Ett filter som stryker meta-meningar ("The request is…", "Det är en statement…").
- Kräv svenska i verktygsvägen.
- Lägg in de tre som tester.

## `connections` (Spotify-tokens) från klienten: 4/4 stängt
REST select och insert ger 401 med bara den publika nyckeln och 403 som anonym användare (`42501`). **verified live.** Krypteringen och callbacken är bara lästa i Kevins tester. Riktig koppling till Spotify är inte prövad.

## Till Aron
Prova timern **i Provläge** i kväll, eller vänta tills blockern är rättad. I Standardläge svarar Lumen just nu "Jag kan inte starta timern här". Detsamma gäller samtal och musik.

## Nästa
- Omtest av blockern så fort Kevin eller Angela har rättat: `python -I scripts/qa/o41_k36_live.py`, plus de sex raderna i tabellen.
