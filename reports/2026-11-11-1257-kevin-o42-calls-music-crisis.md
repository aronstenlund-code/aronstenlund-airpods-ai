# Oscars O42: hjälplinjer, "spela musik", verktyg i Auto bara med "Lumen" (Kevin, 2026-11-11 12:57)

Fynd: Oscars O42 (`reports/qa/2026-11-11-1227-oscar-o42-omtest-k40-k17-o34-o39.md`): K40b-blockern godkänd, prio 2-fynd kvar.
Gjort 12:35–12:45, före Deangelos nya K40.

**Kostnad:** cirka 0,02 USD (Haiku live). ElevenLabs: 0.

## Gjort (`answer/phonetools.ts`, `answer/handler.ts`)
| Fynd (O42) | Före | Nu |
|---|---|---|
| "ring Bris" (tryck och prata) | tyst och inget verktyg, 3/3 | `call_contact {number: "116111"}` 3/3, direkt av koden utan modell (cirka 0,6 s). Samma för Självmordslinjen (90101), 1177 och 112: bara numren som är kontrollerade mot källan (`crisis.ts`, B6). iOS frågar före samtalet |
| "spela musik" utan artist | `music_open` 2/3 med tryck och prata, 1/3 i Auto, ibland "Jag öppnar …" utan att något öppnades | `music_open {query: "musik"}` direkt av koden: 3/3 med tryck och prata, 6/6 för "Lumen, spela musik" i Auto. Med artist ("Lumen, spela Veronica Maggio") väljer modellen som förut |
| Auto hör alla i rummet: "ring mamma" utan "Lumen" ringde | ringde | **I Auto får man verktyg bara med "Lumen"** (eller appens röstinstruktion), enligt Oscars rekommendation |

**Nytt fynd, och rättat:**
- "Lumen, spela musik" i Auto fick **krissvaret** i 1 fall av 6. Modellen skrev sin krismarkör (`[[KRIS]]`) på ett musikkommando.
- Det blev möjligt när Auto fick verktygsvägen i K40b.
- **Rättning:** en sen eller tidig krismarkör från modellen räknas inte när yttrandet är ett kort, riktat telefonkommando (högst 8 ord) och kodlagret (`crisis.ts`) hittar ingen krissignal alls, inte heller hos andra talare. Loggen får `crisis_marker_ignored`.
- **Ett riktigt krisord fångas fortfarande av kodlagret före modellen (B1 oförändrat).** Test: "Lumen, ring mamma, jag vill inte leva längre" ger krissvaret.
- Krisbankerna (O17) påverkas inte, eftersom de inte skickar `tools_available`.

**Tillägg (B1):**
- "ring Bris, jag vill inte leva" ger krissvaret **och** samtalet till Bris (`call_contact 116111`), om appen erbjuder samtal.
- Samtalet skickas en gång, inte igen i verktygsrundan.
- Live: "ring Bris, jag vill inte leva" och "Lumen, ring självmordslinjen jag orkar inte mer" gav krissvaret plus samtalet.
- "jag vill inte leva" ger bara krissvaret. Utan `tools_available` blir det inget samtal.

## Tester
`deno task test`: alla gröna (`answer/k41_test.ts` har nya fall för hjälplinjer, musik, Lumen-kravet, krismarkören och krissvar plus samtal).

## Till Oscar
Kör om `o41c_k36_repeat.py`. Observera att "ring mamma" utan "Lumen" i Auto nu medvetet inte ringer.
