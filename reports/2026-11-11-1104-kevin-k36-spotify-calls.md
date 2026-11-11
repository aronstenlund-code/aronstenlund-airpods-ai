# K36: Spotify och samtal som verktyg (D125) (Kevin, 2026-11-11 11:04)

Uppgift: `prompts/queue/kevin.md` K36. Det står "efter K35 fas 2", men Shopify (fas 2) väntar på Aron. Därför byggde jag den kopplingsgrund som fas 2 också behöver (`connections`, kryptering, OAuth) som en del av K36. Appens del är A-punkter till Angela. Kostnad: **cirka 0,02 USD** (26 live-anrop med Haiku). ElevenLabs: 0.

## Vad som är byggt
**Samtal: telefonverktyget `call_contact`** (`answer/phonetools.ts`):
- Indata är `name` och/eller `number`. Appen slår upp namnet i Kontakter och öppnar `tel:`, och iOS frågar själv innan samtalet. Därför har servern ingen egen `confirm`.
- **Ett nummer tas bara om användaren själv sa siffrorna** (B6). Ett påhittat nummer slås aldrig. Med ett namn utan siffror tas numret bort.
- Live gick "ring tandläkaren" först fel: modellen ville ha ett nummer och svarade på engelska. Rättat i beskrivningen ("ett namn räcker alltid, appen slår upp det").

**Musik utan koppling: telefonverktyget `music_open`.** Appen öppnar Spotify med en sökning. Det fungerar för alla, men användaren trycker själv på spela.

**Spotify med OAuth (D125):**
- `/functions/v1/connect` startar kopplingen, tar emot callbacken, listar och kopplar bort.
- Tabellen `connections` (migreringen `20261111120000_connections.sql`, applicerad via MCP) har RLS och bara tjänstenyckeln når den.
- Tokens krypteras med AES-GCM (`_shared/crypto.ts`) och förnyas automatiskt (`_shared/spotify.ts`).
- **Serververktygen** `spotify_play` (låt, spellista, album eller artist; elevens egna spellistor först), `spotify_pause`, `spotify_next` och `spotify_previous` körs av servern direkt i `/answer` efter modellens tur. Lumen säger en mening skriven i koden ("Nu spelas spellistan Plugg.").
- Verktygen erbjuds bara när appen skickar `connections: ["spotify"]`, aldrig i demon eller i Auto.
- **Begränsningarna** (verifierat i Spotifys dokumentation och blogg i dag):
  - uppspelning bara med **Premium**;
  - en app i Development Mode har **högst 5 användare**, och ägaren måste ha Premium;
  - Extended quota bara för organisationer med cirka 250 000 månadsanvändare;
  - sökningen ger högst 10 träffar.
- **Spotify är alltså en pilot för Aron och några testare.** Allt står märkt i `docs/AGENT.md` (möjligt / med begränsningar / inte möjligt).

## Tester
- `deno task test`: **441 gröna**, varav 7 nya i `answer/k36_test.ts`:
  - krypteringen: ny IV varje gång, signerad state som går ut och inte kan ändras;
  - callbacken sparar bara krypterade tokens;
  - förnyelse av token;
  - Spotify-anropen mot en låtsad API: egen spellista före sökning, telefonen väljs utan aktiv enhet, Premium och felen på svenska;
  - nummerkontrollen;
  - att `/answer` bara erbjuder Spotify med `connections`.
- `deno task check` är ren.
- **Live, driftsatt (`1153ff2`), Standardläge:** **13/13 rätt**, och inget sades före verktyget:
  - ring mamma, Elin, pappa och tandläkaren;
  - "ring 070 123 45 67" gav numret;
  - "spela lugn pluggmusik" och "sätt på lite musik av Veronica Maggio" gav `music_open`;
  - en timer;
  - 5 vanliga frågor med "ringde", "signal" och "spelar" gav inget verktyg.
  - Rådata: `reports/eval/2026-11-11-1103-k36-tools-live.json`. Första körningen (`…-1100-…`) gav 12/13.
- **Live, `/connect` utan Spotify-nycklar:** POST ger 503 `unconfigured`, GET ger `available.spotify: false`, utan JWT blir det 401, och en förfalskad callback ger `lumen://connect?provider=spotify&status=error`.
- **Ej verifierat:** riktig Spotify-koppling och uppspelning (kräver Arons Spotify-app och Premium), appens del, och iOS samtalsfråga på enhet. Att iOS frågar säger utvecklarforum, inte Apples dokumentation.

## Beslut
- Spotify körs på servern i samma tur, med en mening från koden (inget andra modellanrop och ingen rundtur via appen).
- Ingen bekräftelse för spela, pausa och nästa, eftersom det inte ändrar något som inte går att ångra direkt. Ingen egen bekräftelse för samtal, eftersom iOS frågar.
- Krypteringsnyckeln är `CONNECTIONS_KEY`, eller härleds ur tjänstenyckeln tills den finns. Supabase-verktyget för hemligheter kräver att Aron skriver in värdet, så jag kunde inte sätta den.

## Till Angela (nya A-punkter, Deangelo lägger in dem)
- **Samtal:** `call_contact` i `tools_available`.
  1. Fråga om tillåtelse till Kontakter första gången.
  2. Matcha `name` mot kontakternas namn och smeknamn ("mamma"). Vid flera träffar: fråga vilken.
  3. `UIApplication.shared.open(tel:)`.
  4. Resultat: `{ok: true}`, eller `{error: "no_contact"}` om inget hittas.
- **Musik:** `music_open` öppnar `spotify:search:<query>`, eller webben om Spotify-appen saknas.
- **Spotify:** protokollet står i `docs/AGENT.md` (koppla, status, `connections` i `/answer`, `done.server_tool`, koppla bort). Visa "Koppla Spotify" bara när `GET /connect` ger `available.spotify: true`, och skriv "Kräver Spotify Premium".

## Till Aron
- **Spotify**, om du vill prova (cirka 10 min, kräver Premium): klickvägen står i `docs/AGENT.md` under "Kvar för Aron". Högst 5 Spotify-konton kan provas, som du lägger in själv.
- **Rekommendation:** visa Spotify-styrning i appen som "för testare" tills vidare. För alla användare gäller `music_open` (öppna Spotify med sökning).
- **Valfritt senare:** en egen `CONNECTIONS_KEY` (Supabase › Edge Functions › Secrets) innan det finns riktiga användare med kopplingar. Jag ger dig ett värde och en klickväg när det blir aktuellt.

## Kvar
- Riktig Spotify-test när nycklarna finns (Oscar eller Kevin). Shopify (K35 fas 2) kan nu byggas på samma `connections`-grund när Aron har Partner-appen; `provider` får då ett nytt tillåtet värde.
