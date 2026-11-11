# Stående uppgift, omgång 2: Oscars O34 (självsvar och länkar) och O39 (Mina svar) (Kevin, 2026-11-11 11:28)

Uppgift: `prompts/queue/kevin.md` "K-stående – K4-loopen, omgång 2" (PLAN 2b), med Oscars fynd till Kevin i `reports/qa/2026-11-11-1049-oscar-o34-verklighetsbanken-o15c.md` (prio 2) och `…-1044-oscar-o39-k37-mina-svar.md` (prio 3).

**Kostnad:** cirka 0,45 USD.
- Regressionen: 0,32 USD.
- Live grupp 13 och 14 i tre omgångar: cirka 0,12 USD (webbsökning 0,01 per sökning).
- ElevenLabs: 0.

## 1. Självsvaren om Lumen (O34 grupp 13, integritet)
**Före:** tre fasta texter. Bara 5 av 11 svarade på det som frågades, och 8 av 11 sa "ljud sparas inte", vilket inte stämmer: ElevenLabs sparar Scribe-sessionerna på vår nivå, enligt O16 och verifierat live.

**Nu** väljs svaret efter vad som frågas (`answer/self.ts` `selfTopic`): människa/robot, vem har gjort appen, ChatGPT, lyssnar du, vem kan se mina frågor, säljer ni data, vart går ljudet, sparas det.

**Texterna säger det som är sant i dag:**
- "Lumen sparar inget ljud, men ElevenLabs, som skriver ut talet, kan spara det enligt sina villkor."
- Frågor och svar går via Lumens server till en AI-modell (Claude från Anthropic).
- Lärare och föräldrar kan inte se frågorna. Med samtycket läser utvecklaren dem, och de raderas inom 14 dagar (K30).
- "Nej, vi säljer ingen data."
- "Nej, Lumen är inte ChatGPT."

**Resultat:**
- Oscars missar från O36 träffar nu också: "hör du vad min lärare säger", "är du typ en bot", "vem programmerade dig", "kan någon annan läsa det här", "tar du upp ljud i bakgrunden".
- Fall som inte handlar om Lumen ger fortfarande null.
- **Live (Auto):** 10/10 får självsvaret med rätt ämne.
- **Obs, Oscar:** `o24_k20_offline.mjs` och `o36_…` känner igen svaret på de gamla texterna ("sparas inte"). De visar därför 10/20 och 5/9, men det är skriptet. Använd `selfTopic` eller de nya texterna. Alla 20 O24-fall och de 5 O36-fallen ligger med rätt ämne i `answer/k27_test.ts`.

## 2. Länkar med egna ord (O34 grupp 14, K19)
**Före:** 0/10 med länk, 2 tysta i Auto, och 3 svar "jag kan inte söka eller skicka länkar".

**Orsaker:**
1. I Auto gick ingen länkbegäran till K19 (D46: Auto söker aldrig på webben).
2. **UR Play svarar 403 på automatiska kontroller** fast sidan finns. Det syns från Supabase, och i loggen var status 403 för UR-länkar. Därför kastades bra länkar.
3. Ämneskontrollen jämförde de sex första bokstäverna ("cellen" ≠ "celler").
4. Modellen skrev ibland "INGEN LÄNK" fast sökningen hade hittat en sida på listan.

**Ändringar:**
- Sökningens egna resultat (url och titel) läses nu ur svaret (`source`-chunks, bara för länksökningen).
- **En adress som sökningen själv gav** godkänns även när sajten blockerar kontrollen (401, 403, 429, 503). En adress som bara modellen skrev måste fortfarande svara 200, så **B7 håller** och ingen påhittad adress släpps igenom.
- Upp till tre resultat som handlar om ämnet provas.
- Ämnet tas efter sista "om" ("på UR om demokrati" blir "demokrati").
- Ämneskontrollen tar bort svenska ändelser.
- **I Auto** går bara en begäran som **inleder** yttrandet till länksökningen ("kan du hitta en film om …", "någon youtube om …", "jag vill se en film om …"). Ett samtal mellan andra ("igår sa hon att hon har en film om …") gör det inte. Auto söker fortfarande inte på webben efter svar.
- Jag har **inte** tagit mig förbi bot-skyddet.
- Är sökningen spärrad (5 per minut) säger Lumen "Jag kan inte leta upp fler länkar just nu", i stället för "hittade ingen".

**Live (Auto plus två i Provläge):**
| Omgång | Länk |
|---|---|
| Före (Oscar O34) | 0/10 |
| Efter Auto och sökresultaten | 3/10 (5 slog i min egen gräns på 5 per minut) |
| Efter ändelserna, 16 s mellan anropen | 7/10 |
| **Efter "tre resultat" och "sista om"** | **9/10** |

- Rådata: `reports/eval/2026-11-11-1127-k-standing2-live.json` (och `…-1114-…`, `…-1120-…`).
- **Kvar:** "kan du rekommendera en film om derivata" (Matematik 3c) ger ingen länk. "Någon youtube om derivata" gav en engelsk Khan Academy-video om derivator av inversa funktioner, alltså rätt sida men för smalt ämne. Svenska matteklipp om derivata finns sällan på listan.

## 3. Mina svar (O39 prio 3)
- "Hur funkar X" räknas nu som samma slags fråga som "vad är X", men bara för kontrollen och en säker träff i koden när allt annat stämmer.
- `suggest` och `compress`: prompten säger 2–4 meningar och högst 60 ord, utan symboler. Koden byter `→` mot "blir" och `+` mellan ord mot "och", och tar bort parenteser.
- **Oscars 41 fall ligger som hållout** (`answer/k37_test.ts`): en säker träff får aldrig vara fel. De används inte för att justera trösklarna.
- Årtalsfallet ("varför blev det krig 1914") är inte ändrat. Det föll på ordlikhet, inte på siffrorna.

## Tester
- `deno task test`: **445 gröna**, nya `answer/k19b_test.ts` och fler fall i `k27`, `k37` och `my-answers`. `deno task check` är ren.
- **Regressionen (D87-urvalet, 21 fall)** för `ec5f5c1`: första svaret räcker **90,5 %** mot baslinjen 97,1 %, alltså två fall av 21 (ett "exam" och ett "followup").
  - Ändringarna rör inte vanliga Provläge-svar: självsvar, länkvägen, `saved_answers`, verktyg bara med `tools_available` eller `connections`.
  - Samma urval har gett 81,0–100 % de senaste dagarna utan relevanta ändringar (95,2, 81,0, 95,2, 100, 95,2, 90,5, 85,7, 90,5).
  - **Bedömning:** brus. **Ej verifierat** fall för fall, eftersom regressionen inte sparar raderna. Ett förslag till senare: att den sparar rådata som artefakt.

## Concerns (till Architect)
Jag instämmer i Oscars Concern i O39. "Mina svar" läser upp elevens förberedda svar ordagrant när en fråga hörs i Provläget, som lyssnar handsfree och alltså även hör läraren. Det kan användas som fusk under ett riktigt prov. Tekniskt går det att begränsa på två sätt:
- bara elevens egen röst triggar (appen har talaretiketter, D81);
- funktionen presenteras som "öva på dina svar".

Det är Architects och Arons beslut, och jag har inte lagt till någon spärr. Det är inte en restriktion i del B.

## Till Angela
- Texten i Om appen (`AboutView.swift:38`) och samtycket bör säga samma sak som självsvaren, efter Arons beslut i O16. Förslag: "Lumen sparar inget ljud. ElevenLabs, som skriver ut talet, kan spara det enligt sina villkor."
- Självsvaren är inte längre ordagrant samma som Om appen.

## Till Aron
O16-beslutet (ElevenLabs med zero retention före beta) är fortfarande öppet. Servern säger nu sanningen om det.
