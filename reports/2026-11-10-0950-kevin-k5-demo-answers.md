# Kevin K5: Demons svar är första intrycket

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K5 · Underlag: `reports/qa/2026-11-08-1630-oscar-demosida.md` fynd 3 ("oprätt", "ett kapplöpning") · Driftsatt (Deploy backend 42784264864, commit b7b9561) · **Verified live** (`scripts/k5-demo-language.py`, 10 typiska demofrågor med `source: "demo"`, bedömda av Sonnet). **Inte testat i en webbläsare.**

## Resultat
| | Haiku (före) | Sonnet (nu) |
|---|---|---|
| Korrekta | 10/10 | 10/10 |
| Naturlig svenska enligt bedömaren | **9/10**. Anmärkningar: "grundade den vasatiden", "arvkungadöme", "dropens" (2 av 10 svar med språkfel) | **10/10**, 0 språkfel (en anmärkning: "gångra" är ovanligt) |
| Kända fel i kod (genus, påhittade ord) | 0 | 0 |
| Kostnad per demosvar | 0,00014 USD | 0,0028 USD |
| Första text p50 (klient) | 2,1 s | 2,3 s |

Filer: `reports/eval/k5-demo-haiku-2026-11-10.json` och `k5-demo-sonnet-2026-11-10.json`.

## Beslut (DECISIONS: se raden "K5")
- **Demon kör på Sonnet 5.5**, samma modell som Provläge (K2). `DEMO_MODEL` i Supabase-hemligheterna byter tillbaka utan kod (tomt värde = Haiku).
- **Inom demotaken:** högst 600 frågor per dag med 160 token var. Det ger högst cirka 1,7 USD per dag om taket nås (0,0028 × 600), och i praktiken mycket mindre.
- **Språkkontrollen** körs varje natt (steg "Demo language" i `nightly-eval.yml`). Den skriver `reports/eval/k5-demo-nightly-<datum>.json` med korrekthet, naturlighet och kända fel.

## Inte gjort
- **Oscars testrad `oscar-qa-site-160926@example.com` i väntelistan är inte raderad.** Att radera data kräver Aron enligt CLAUDE.md, även i självständigt läge. **Till Aron:** Supabase → Project Lumen → Table Editor → `waitlist` → sök på e-postadressen → markera raden → Delete. Eller ge klartecken, så tar jag bort den med ett anrop.

## Till Aron
- Godkänn Sonnet i demon (som mest cirka 1,7 USD per dag om taket nås), eller sätt `DEMO_MODEL` till tomt för att gå tillbaka till Haiku.
- Testraden i väntelistan (se ovan).

## Kostnad
Ungefär 0,1 USD (20 demosvar och bedömning).
