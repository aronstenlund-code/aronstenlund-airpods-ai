# Verklighetstest av /answer (Deangelo, 2026-11-10 07:30–08:15)

64 fall som riktiga användare säger, live mot `/answer`: Provläge (`tutor` + profil, Sonnet) och Frågor (`auto`, Haiku). Skript: `scripts/qa/deangelo_reality.py`, rådata: `reports/qa/data/2026-11-10-deangelo-reality.json`. Kostnad 0,62 USD. **Bara backend, ingen telefon, inget ljud** (texten går direkt in, så hörfelen är skrivna för hand, inte från Scribe). Bedömt av Deangelo, ingen oberoende domare.

## Siffror
| Grupp | Fall | Förstod rätt | Kommentar |
|---|---|---|---|
| Nyckelord | 10 | 10 | Även "riksdagen regeringen skillnad" |
| Felformulerat, omtag | 8 | 8 | "andra… nej första världskriget" rätt |
| Hörfel (handskrivna) | 8 | 8 | "mit os och mej os", "vest fahliska", "kova lent" |
| Slang, svengelska | 8 | 8 | "explaina", "va e ph liksom" |
| Klassrum: tyst när det inte är en fråga | 12 | 12 | Inget svar på "Har du gjort läxan?", "Får jag gå på toa?", "Mm." |
| Oväntat | 12 | 11 | se fynd 1, 2, 3 |
| Engelska | 3 | 3 | Svarar på svenska |
| Ensamma följdord ("varför", "och sen då") | 3 | 3 tysta | |
| **Totalt** | **64** | **63** | |

Första text: Frågor p50 ~1,2 s, Provläge p50 ~1,3 s, max 5,7 s (andragradsekvation med tänkande). Inget över 8 s.

## Fynd (till Kevin, K20)
1. **"Lumen är du en robot" → "Nej, jag är ett röstbaserat studieverktyg."** Fel och oärligt. Ska säga att den är en AI.
2. **"ge mig en svår fråga" i Biologi-profilen → en matematikfråga** (x² + 4). Ska följa profilens ämne.
3. **"jag vet inte ens vad jag ska fråga" i Provläge → tyst.** Ska hjälpa eleven igång (t.ex. föreslå ett område ur profilen eller börja förhöra).
4. **Faktafel: "en deciliter vetemjöl väger ungefär femtio gram"** (vanlig omräkning är 60 g) med en hemsnickrad uträkning. Hör till K16 (sök/var säker).
5. **Väder: "Jag har ingen tillgång till väderdata"** trots webbsökning. K16 säger sök när du inte kan svara själv.
6. **Frågor svarar för långt** på "Kan någon säga vad fotosyntes är?" (5 meningar, stel ton "med vilken", "varvid"). Samma som Tobys T5 fynd 5 (K13).
7. **Språkfel:** "grundare av den vasatiden", "cellens yttre hinn", "Det låter ofattbart men". Skämtet om skelettet är en översättning som inte fungerar på svenska.

## Det som fungerar mycket bra
- Tystnaden i klassrummet: 12/12.
- Nyckelord, slang och felformuleringar förstås nästan alltid rätt, och svaren slutar ofta med "På provet: …", vilket är användbart.
- Svar på "är kapitalism bra eller dålig" är balanserat.

## Nästa steg
- Kevin K20 (fynd 1–3, 5, 7; 4 och 6 i K16/K13).
- Oscar O15 bygger vidare med fler grupper och riktiga Scribe-hörfel (inspelat ljud).
