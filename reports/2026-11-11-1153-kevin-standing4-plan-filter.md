# Stående uppgift, omgång 4: K17-planen (O13 del 2) och K38-filtret (O38) (Kevin, 2026-11-11 11:53)

Oscars fynd till Kevin:
- `reports/qa/2026-11-11-1047-oscar-o13-del2-k17.md` (prio 2);
- `reports/qa/2026-11-11-1033-oscar-o38-k38-godkand.md` (prio 3; **K38 godkänd**).

**Kostnad:** 0 USD (offline). ElevenLabs: 0.

## K17: planen fram till provet (`study-plan/handler.ts` `planDays`)
- **Bugg 1 rättad:** räknaren nollställs per dag. Förut fick de sista dagarna bara ett begrepp, även "dagen före provet".
- **Bugg 2 rättad:** "Blandat förhör … dagen före provet" används bara på den riktiga dagen före. Med ett prov om mer än 14 dagar planeras de 14 närmaste dagarna, utan den texten.
- **Fynd 3:** varje dag tar först de begrepp vars repetition infaller den dagen ("Repetition av det som ska tillbaka i dag."), och fyller sedan på med de svagaste.
- **Fynd 4:** `whenSaid` säger "Förra veckan" (7–13 dagar), "För två veckor sedan" och sedan datumet ("Den 21 oktober").
- **Resultat:** Oscars `o13_del2_k17_offline.mjs` ger **19/19** (var 16/19). Nytt test i `study-plan/handler_test.ts`.

## K38-filtret (`scripts/real_users.py`)
**Metodfrågor som slank igenom (2/26):**
- `METHOD` tar nu sammansatta ord ("sömntabletter") och vanliga läkemedelsnamn (Alvedon, Panodil, Ipren, Sobril, Propavan, Imovane och några till).

**Onödiga strykningar:**
- Kamprad, Caesar och fler kända personer räknas inte som privata namn.
- "Big Bang" är inget namn.
- Tankeskolor ("Atens skola", "frankfurtskolan") räknas inte som skolor.
- "Den genetiska koden" och "ett säkert lösenord" stryks inte längre. Det gör bara en kod eller ett lösenord *till* något ("portkoden", "lösenordet till wifi").

**Resultat:**
| Fall | Före | Efter |
|---|---|---|
| Oscars O38, privata rader som stoppas | 24/26 | **26/26** |
| Oscars O38, allmänna frågor som behålls | 10/20 | **17/20** |
| O25b | 22/22 och 12/12 | 22/22 och 12/12 |
| Mina hållout-fall | 19/19 och 19/19 | 19/19 och 19/19 |

- De tre som stryks, "vad är en överdos", "Alvedon-förpackning" och "Sankt Petersburg 1917", stryks med avsikt: metodord och tal stryks hellre än släpps.
- `test_real_users.py` ger 9 OK.

## Till Aron
- **K38 är godkänd av Oscar (O38).** Lägg in `SUPABASE_SERVICE_ROLE_KEY`: GitHub › repot › Settings › Secrets and variables › Actions › New repository secret.
- Name: `SUPABASE_SERVICE_ROLE_KEY`.
- Värdet: Supabase › projektet › Project Settings › API Keys › service_role › Reveal.
- Det låser upp K6 (röstproven) och K22 (veckans kandidater till din sida).
