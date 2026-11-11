# Lumen som agent (D122, K35): verktyg och kopplingar

Kevin, 2026-11-10. D122 säger att Lumen ska kunna **göra saker**, inte bara svara. Det här dokumentet beskriver hur, och vad som är byggt.

## Översikt
| Sort | Var den körs | Exempel | Status |
|---|---|---|---|
| **Telefonverktyg** | i appen (EventKit, AlarmKit, appens anteckningar) | kalender, påminnelser, timer, larm, anteckning | **Servern klar** (K35, fas 1). Appen bygger A48 |
| **Serververktyg** | på servern | webbsökning (finns), kopplingar till tjänster | Webbsökning finns. **Spotify byggd (K36)** men väntar på Arons Spotify-app. Shopify: designad nedan, inte byggd |
| **Samtal och musik-appen** (K36) | i appen | `call_contact`, `music_open` | **Servern klar och live 13/13** (K36). Appen bygger dem |

Allt går genom Claudes tool use i `/answer`. Modellen väljer ett verktyg och fyller i det. **Koden kontrollerar indata innan något händer** (`answer/phonetools.ts` `validatePhoneInput`), och **användaren bekräftar alltid innan något ändras eller skickas**.

## Telefonverktyg: protokollet (för Angela, A48)
**1. Appen anmäler vad den kan köra.** Varje `/answer` i Standardläge (tryck och prata, text) och Provläge får fältet
`"tools_available": ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add"]`.
Skicka bara de verktyg som appen faktiskt kan köra. Utan fältet ändras ingenting. Auto och de sociala lägena får inga telefonverktyg i fas 1.

**2. Modellen anropar ett verktyg.** Servern skickar en ny SSE-händelse:
```
event: tool_call
data: {"id": "toolu_…", "name": "calendar_add", "input": {"title": "Tandläkaren", "start": "2026-11-12T15:00"},
       "confirm": "Ska jag lägga in Tandläkaren torsdag den 12 november klockan 15:00 i kalendern?", "kind": "write"}
```
Därefter kommer `done` med `"tool_pending": true`. Före anropet kommer ingen text (prompten säger så). Om modellen ändå skriver något, är det en vanlig `delta`.

**3. Appen kör verktyget.**
- Är `confirm` inte null: säg frågan och vänta på ja eller nej, med rösten eller en knapp. Kör verktyget **bara efter ett ja**.
- Är `confirm` null (`calendar_list`, `timer_start`, `note_add`): kör direkt.
- Behörigheten (kalender, påminnelser, larm) frågas första gången ett verktyg behövs, inte när appen startar.

**4. Appen skickar resultatet** med samma anrop som förut (samma `fragment`, `mode`, `context`, `tools_available`) och dessutom:
```
"tool_round": {"call": {"id": "toolu_…", "name": "calendar_add", "input": {…samma som i tool_call…}},
               "status": "ok" | "declined" | "error", "result": {…valfritt, t.ex. händelserna för calendar_list…}}
```
Modellen svarar då med en kort mening ("Klart, tandläkaren ligger på torsdag klockan tre."). Den kommer som vanliga `delta` och `done`.

**Verktygen** (tider är lokal svensk tid i ISO-format utan zon, `2026-11-12T15:00`):
| `name` | Indata | Bekräftelse | Resultat tillbaka |
|---|---|---|---|
| `calendar_add` | `title`, `start`, `end?`, `all_day?`, `location?` | ja | `{event_id}` |
| `calendar_list` | `from`, `to` | nej | `{events: [{title, start, end, location?}]}` (högst cirka 20) |
| `reminder_add` | `title`, `due?` | ja | `{reminder_id}` |
| `timer_start` | `seconds` (1–86 400), `label?` | nej | `{ok: true}` |
| `alarm_set` | `time` ("HH:MM"), `label?` | ja | `{alarm_id}` |
| `note_add` | `text` | nej | `{ok: true}` |
| `call_contact` (K36) | `name?`, `number?` (minst ett) | **iOS frågar** (inte Lumen) | `{ok: true}` eller `{error: "no_contact"}` |
| `music_open` (K36) | `query` | nej | `{ok: true}` |

**Regler i koden:**
- Servern validerar varje indata. Ett okänt verktyg, ett fel format, ett datum som inte är ISO eller en timer på 0 s skickas aldrig till appen (`tool_call_dropped` i loggen).
- `tool_round` valideras på samma sätt (400 vid fel).
- Bara ett verktyg per tur.
- Inga verktyg i demon.

## K36: samtal och musik (Kevin, 2026-11-11)
Märkning: **möjligt**, **med begränsningar** och **inte möjligt**.

| Vad | Hur | Läge |
|---|---|---|
| **Ringa någon** ("ring mamma", "ring tandläkaren") | Telefonverktyget `call_contact`. Appen slår upp `name` i Kontakter, och läser dem bara med tillåtelse, som frågas första gången. Sedan öppnar appen `tel:`. | **Med begränsningar:** iOS visar själv en fråga ("Ring …?") som kräver **ett tryck på skärmen**. Någon app kan inte ringa utan den, enligt utvecklarforum och inte Apples dokumentation (ej verifierat på enhet). Lumen frågar därför inte själv, för då kommer två frågor. Med telefonen i fickan måste användaren alltså ta upp den. |
| Ringa ett nummer man säger ("ring 070 …") | `call_contact` med `number` | **Möjligt.** Servern tar bara ett nummer **vars siffror användaren själv sa** (B6). Ett påhittat nummer slås aldrig. |
| **Öppna musik** ("spela lugn pluggmusik") | Telefonverktyget `music_open`. Appen öppnar Spotify med en sökning (`spotify:search:…`). | **Möjligt för alla, utan koppling**, men användaren trycker själv på spela. Fungerar inte om Spotify-appen saknas; då kan appen öppna webben. |
| **Styra Spotify** (spela låt, spellista eller album, pausa, nästa, förra) | Serververktyg (`spotify_play`, `spotify_pause`, `spotify_next`, `spotify_previous`) via Spotify Web API med OAuth. Servern kör verktyget direkt i `/answer` och säger en mening ("Nu spelas spellistan Plugg."). Ingen rundtur via appen. | **Med stora begränsningar** (verifierat i Spotifys dokumentation 2026-11-11): uppspelning styrs **bara med Premium**. En app i Development Mode får **högst 5 användare**, som Aron lägger in, och appens ägare måste ha Premium. Extended quota ges bara till organisationer med cirka 250 000 användare. **Det är alltså en pilot för Aron och några testare, inte för alla elever.** För alla andra gäller `music_open`. |
| Styra Apple Music eller annan musik som redan spelar | – | **Inte möjligt** för en vanlig app (iOS har inget öppet API för att styra en annan apps uppspelning). |

**Spotify, protokollet (för Angela):**
1. **Koppla:** `POST /functions/v1/connect {"provider": "spotify"}` ger `{url}`. Öppna den i `ASWebAuthenticationSession` med callback-schemat `lumen`.
   - Spotify skickar tillbaka till `…/connect/callback`, och servern skickar vidare till `lumen://connect?provider=spotify&status=ok|premium_required|denied|error`.
   - Adressen går att byta med `CONNECT_RETURN_URL` om appens schema blir ett annat.
2. **Status:** `GET /connect` ger `{"connections": [{"provider": "spotify", "premium": true}], "available": {"spotify": true|false}}`. `available: false` betyder att servern saknar Spotify-nycklarna; visa då inte "Koppla Spotify".
3. **Använda:** skicka `"connections": ["spotify"]` i `/answer` när eleven har kopplat. Svaret är vanliga `delta` med en mening, och `done.server_tool` = `{name, status, playing?}`.
   - `status`: `ok`, `not_connected`, `premium_required`, `no_device`, `not_found` eller `error`.
   - Spotify måste ha varit öppet på telefonen någon gång, annars finns ingen enhet att spela på.
4. **Koppla bort:** `DELETE /connect?provider=spotify`. Raden raderas.

**Säkerhet:**
- Tokens krypteras med AES-GCM innan de sparas i `connections`, som bara tjänstenyckeln når.
- Nyckeln är `CONNECTIONS_KEY` om den sätts, annars härledd ur tjänstenyckeln. Byts tjänstenyckeln måste användarna koppla igen.
- OAuth-`state` är signerad med användarens id och går ut efter 10 minuter.
- Inget e-post, inget namn och inget Spotify-konto-id sparas, bara `premium` och tokens.

**Kvar för Aron (Spotify), cirka 10 min:**
1. developer.spotify.com › Dashboard › Create app. Namn "Earmind", Redirect URI `https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/connect/callback`, API: **Web API**. Kontot måste ha **Premium**.
2. Appen › Settings: kopiera **Client ID** och **Client secret**.
3. Supabase › projektet › Edge Functions › Secrets › lägg till `SPOTIFY_CLIENT_ID` och `SPOTIFY_CLIENT_SECRET`.
4. Spotify-appen › User Management: lägg till de (högst 5) Spotify-konton som ska få prova.

## Serververktyg och kopplingar (plan, inte byggt)
**Shopify-pilot: "Lumen, hur går det i butiken i dag?"**
1. **Koppla butiken (en gång):** appen öppnar `GET /connect-shopify?shop=<butik>.myshopify.com`, som går vidare till Shopifys OAuth med minsta behörighet (`read_orders`, `read_products`, `read_inventory`). Callbacken byter koden mot en åtkomsttoken.
2. **Lagring:** tabellen `connections`. Varje rad har användar-id, leverantör, butik och token. Bara tjänstenyckeln når tabellen, och RLS är på utan klienträttigheter. **Token krypteras med AES-GCM** med nyckeln `CONNECTIONS_KEY`, en Supabase-hemlighet. Den finns aldrig i appen eller repot. Användaren kan koppla bort, och då raderas raden.
3. **Verktyget `shop_status`** (serververktyg, körs i `/answer` utan rundtur till appen) har `{period: "today" | "week"}`. Det hämtar ordrar, försäljning och lager med lite kvar från Shopify Admin GraphQL, och svaret blir en kort statusrapport. Bara läsning: inget ändras i butiken.
4. **Bekräftelse:** för läsning behövs ingen. Ett framtida verktyg som ändrar något (till exempel att markera en order som skickad) ska använda samma `confirm`-steg som telefonverktygen.

**Kvar för Aron innan Shopify kan byggas och testas:**
- en Shopify Partner-app (gratis), där `SHOPIFY_CLIENT_ID` och `SHOPIFY_CLIENT_SECRET` blir Supabase-hemligheter;
- en testbutik (development store);
- ett beslut om anonyma konton: i dag hör en koppling till appens anonyma användare och försvinner om appen installeras om.

## Säkerhet och integritet
- Användaren bekräftar alltid innan något läggs in, ställs eller skickas (D122).
- Kalenderhändelser som läses (`calendar_list`) skickas till modellen för att svaret ska kunna formuleras. Allt annat stannar på telefonen. Ingenting sparas på servern utöver den vanliga användningsloggen, där verktygets namn loggas men aldrig dess innehåll. Med `qa_log: true` (K30) sparas frågan och svaret som vanligt.
- Inga verktyg som döljer att Lumen gör något, och inga verktyg som skickar meddelanden i användarens namn utan bekräftelse.
