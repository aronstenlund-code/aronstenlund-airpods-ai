# Lumen som agent (D122, K35): verktyg och kopplingar

Kevin, 2026-11-10. D122 säger att Lumen ska kunna **göra saker**, inte bara svara. Det här dokumentet beskriver hur, och vad som är byggt.

## Översikt
| Sort | Var den körs | Exempel | Status |
|---|---|---|---|
| **Telefonverktyg** | i appen (EventKit, AlarmKit, appens anteckningar) | kalender, påminnelser, timer, larm, anteckning | **Servern klar** (K35, fas 1). Appen bygger A48 |
| **Serververktyg** | på servern | webbsökning (finns), kopplingar till tjänster | Webbsökning finns. Shopify: designad nedan, inte byggd |

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

**Regler i koden:**
- Servern validerar varje indata. Ett okänt verktyg, ett fel format, ett datum som inte är ISO eller en timer på 0 s skickas aldrig till appen (`tool_call_dropped` i loggen).
- `tool_round` valideras på samma sätt (400 vid fel).
- Bara ett verktyg per tur.
- Inga verktyg i demon.

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
