# K99 (D223): röster som skiljer sig åt, Blanda röster och AI:s röstval

Kevin (moln), 2026-11-17 23:30. 0 ElevenLabs-krediter: koden testas med fejk, och röstsökningen är bara en listning i röstbiblioteket.

## Vad som är gjort
1. **Blanda röster** (`drill.mix_voices: true`, av som standard). När texten sparas lottas en röst ur katalogen för varje del eller fråga. Fröet är `drill.id:pos` (SHA-256). Rösten sparas i `drill_items.voice_id`, så varje varv låter likadant, och samma text med samma röst kostar 0 igen. Kostnaden är densamma som med en röst, eftersom krediter räknas per tecken. Valet är låst efter första sparningen, precis som rösten (D151). Testat med fejk.
2. **AI väljer röst.** När `style` har text och ingen röst är vald, väljer Haiku en röst ur katalogen. Svaret är `voice_id` plus en kort `voice_reason`, och det kommer redan i `cost`, innan något ljud skapas. Ett id som inte finns i katalogen godtas inte; då används standardrösten. Testat med fejk.
3. **Röster under granskning** (`voice_catalog.review`). `/voices` visar dem bara för admin (credit_admins). Blanda och AI-valet använder bara röster som inte är under granskning. Testat med fejk.
4. **Sökning utanför svenska:** `/voices?library=1&lang=any` söker i alla språk. Det behövs för att hitta röster med kinesisk eller indisk bakgrund. Körd live, utan krediter.
5. Felkoden heter nu `voice_not_in_catalog`, på Angela Fables fråga.
6. **Katalogen:** 22 röster i `backend/supabase/migrations/20261117230002_k99_catalog_seed.sql`, som Deangelo kör. 14 syns för alla, och 8 är under granskning: Kines, Kines B, Hindi, Hindi B och fyra karikatyrer.

## Katalogen
Jag sökte i röstbiblioteket via `scripts/k99-voice-search.py` (kevin-live run 44199326777) och fick 98 kandidater.

**Synliga för alla (14):**
- Jonas: man, medelålder, Stockholm, samtalston
- Saga: ung kvinna, Stockholm, pigg
- Johan: man, Göteborg, berättare
- Karin: kvinna, stadig
- Robert: äldre man, skånsk
- Signe: kvinna, mjuk
- Ale: SFI-lärare från södra Sverige
- Lisa: ung kvinna, Stockholm, vardaglig
- Bertil: djup dokumentärröst
- Elin: kvinna, bestämd
- Martin: man, Helsingborgsskånska
- Louise: kvinna, lugn
- Sam: ung, busig, kön inte angivet
- Ola: djup sagoröst

Det finns ingen äldre kvinna; biblioteket hade ingen på svenska.

**Bara för admin tills Aron har lyssnat (8):**
- **Kines** (Mr. Chen, talar mandarin) och **Kines B** (Yung-Lung Chen, engelska med kinesisk brytning)
- **Hindi** (Arjun, hindi/hinglish) och **Hindi B** (Mayur, indisk engelska)
- Karikatyrerna Piraten, Trötta gubben, Cowboyen och Sagofarfar

**Verifierat i biblioteket (listningen):** namn, beskrivning, accent, språk och preview_url för alla 22.

**Ej verifierat:**
- Hur rösterna låter när de läser svenska (eleven_v3/multilingual), och om brytningen hörs. Provljudet är på rösternas eget språk.
- Om en biblioteksröst går att använda för TTS innan den lagts till på kontot.

Båda kräver ett riktigt ljudprov, alltså krediter och Arons ja (TILL-ARON #28).

## Beslut (D225)
Kines och Hindi är `review: true` från början, trots att D223 säger att de ska synas i appen. Skälet är att D223 också säger "varje röst provlyssnas på svenska före valet; en röst som inte går att förstå tas inte med". Det kan bara göras med krediter, vilket D180 förbjuder utan Arons ja. Därför finns två kandidater för varje. När Aron har lyssnat görs den han väljer synlig med en rad, som Deangelo kör:
`update public.voice_catalog set review=false where name='Kines';` (eller 'Hindi', 'Kines B', 'Hindi B')

Följden är att AI-valet inte väljer Kines eller Hindi ännu, inte ens för en stil som "med kinesisk brytning", eftersom AI:n bara ser röster som inte är under granskning.

## Tester
- `deno test -A` i backend/supabase/functions: 700 passed, 0 failed (fejkade svar för Haiku och ElevenLabs). K99-commiten 40ffffe7 angav 701; nu räknas 700.
- Deploy-backend 44199044992 grön för 2b9e518d.
- Röstsökningen live: 12 frågor, 98 träffar, 0 fel.

## Kända begränsningar och risker
- En admin, eller någon som känner till ett id, kan välja en röst under granskning direkt med `voice_id`, eftersom `voiceAllowed` bara kräver `enabled`. Det är avsiktligt, så att Aron kan prova dem.
- Lotten tar bara de första 40 rösterna i katalogen (limit=40), och 14 är synliga nu.
- **Concerns:** Jag tog inte med "Oolong", som beskriver sig själv som en "performed Chinese accent". Det är en karikatyr av en etnisk brytning, som kan uppfattas som nedsättande. Kines och Hindi är vanliga röster med den bakgrunden. Om Aron vill ha den ändå är det ett beslut för honom.

## Att göra
- **Deangelo:** kör `20261117230001_k99_mix_review.sql` och sedan `20261117230002_k99_catalog_seed.sql`. Kör också K98-migreringarna 20261117220001–4 om de inte är körda.
- **Aron:** provlyssna Kines, Kines B, Hindi, Hindi B och karikatyrerna (gratis provljud i appen som admin) och säg vilka som ska synas. Bestäm om ett riktigt svenskt ljudprov får kosta krediter (TILL-ARON #28).
- **Oscar:** O81.
- **Angela Fable:** A140, med fälten i hennes kö.

## Tillägg 23:45: Oscars låga O77-fynd
`action:"cost"` svarar nu med en egen text när dagens gräns (300 per konto) är nådd: "Du har förhandsvisat många texter i dag. Försök igen i morgon." Minutens gräns behåller "För många förhandsvisningar just nu. Vänta en stund." Koden (`rate_limited`) och `retry-after` är oförändrade, så appen påverkas inte. Testat med fejk: ett nytt test, och 701/701 i backend/supabase/functions.
