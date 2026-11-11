# Oscar O40: Oberoende test av K39 (logga-röstningen), utan att rösta

Datum: 2026-11-11, 10:51–10:53 (svensk tid)
Uppgift: stående uppgift (PLAN 2b). K39 är den senaste klara K-punkten utan O-punkt (`reports/2026-11-11-1050-kevin-k39-logo-vote.md`).
**Skript:** `scripts/qa/o40_k39_live.py`
**Rådata:** `reports/qa/data/2026-11-11-1052-o40-k39.json`
**Kostnad:** 0 USD (inga modellanrop).

**Upplägg:** jag lade **ingen giltig röst**, eftersom en teströst räknas i Arons riktiga omröstning. Därför prövades bara behörighet, ogiltiga val och direktåtkomst. Att en giltig röst sparas och går att ändra kontrollerades bara i koden (`cast_logo_vote` gör `on conflict (user_id) do update`).

## Resultat: **22/22**. K39 GODKÄND
| Kontroll | Resultat | Märkning |
|---|---|---|
| Utan token: GET och POST | 401 | verified live |
| Ny anonym användare, GET | `{"choice": null}`, inga resultat | verified live |
| Ogiltiga val: "D", "", "AB", "A;drop", 1, null, ["A"], "Ä" | 400 alla 8, och ingen röst sparades efteråt | verified live |
| Kropp över 1 KB | 413 | verified live |
| Ägarvyn (`?view=owner`) som anonym användare | 403 | verified live |
| Tabellen `logo_votes`: REST select och insert med publik nyckel och som inloggad | 401 och 403 (`42501`) | verified live |
| `cast_logo_vote` för **ett annat** användar-id och `logo_vote_counts` via RPC | 401 och 403. Ingen kan rösta åt någon annan eller läsa totalen | verified live |
| RLS, policyer och rättigheter | RLS på, 0 policyer, inga klienträttigheter på tabell eller funktioner | verified live (SQL via MCP, bara läsfrågor) |
| Bara anonymt användar-id, val och tid sparas | Ja (migreringen) | verified in code |
| Procent visas först efter egen röst och vid ≥ 20 röster | Ja (`forUser`, `RESULTS_MIN`) | verified in code |

## Fynd
1. **En röst ligger redan i tabellen** (C, 1 av 1 kl. 10:51). Det är Kevins teströst (`4531f793-…`). Han skriver i sin rapport att raderingen väntar på en bekräftelse. Den räknas i Arons resultat tills den är borta. Jag rör den inte.
2. **En person kan rösta många gånger:** en röst per *anonym användare*, och en ny anonym användare skapas vid ominstallation eller med ett skript (Supabase begränsar anonyma registreringar per nät, cirka en timme, se `docs/HANDOVER-OSCAR.md`). Med 20–50 röster kan en enda person avgöra omröstningen. Det är okej för en snabb fingervisning, men det är ingen säker röstning. **Till Aron:** se resultatet som en indikation. Vill du ha en säkrare omröstning: räkna bara röster från användare som använt appen minst en dag. Det kan Kevin göra med `answer_usage`.

## Nästa
Appens del (A54) testar Toby med skärmbilder.
