# Plan: struktur för arbetet (Deangelo, 2026-11-09)

Planen är regler, inte en lista med punkter. **Ordningen finns bara i köerna** (`prompts/queue/`), målen i faserna nedan. Inget i planen får stoppa arbetet: en session som inte kan ta en punkt tar nästa.

## 1. Prioritet när något nytt kommer in
1. **Blockerare från test** (Toby, Oscar eller Aron på telefon): läggs överst i rätt sessions kö.
2. **Ägarbeslut märkta brådskande.**
3. **Godkända punkter** i köns ordning.
4. **Backlog** (`BACKLOG.md`): flyttas till en kö när Aron godkänner eller när en fas behöver den.

## 2. Flödet
- Byggare (Angela, Kevin, Kelly) gör punkter → testare (Oscar, Toby) får en testpunkt per klar punkt → fynd blir nya punkter hos byggaren (prio 1).
- Beror en punkt på något som inte är klart: hoppa över, ingen väntar.
- Deangelo håller varje kö minst 2 punkter lång utifrån fasens mål, och säger till Aron när en session står still.

## 2b. Ingen står still (Aron 2026-11-09 22:39)
Så många sessioner som möjligt jobbar samtidigt. Är kön tom tar sessionen sin **stående uppgift** och skriver den som en egen punkt i sin kö:
| Session | Stående uppgift |
|---|---|
| Angela | Gör appen enklare: kortare väg från start till första svar, färre knappar per skärm, avancerat bakom Inställningar. |
| Kevin | K4-loopen: kör eval, rätta det sämsta fallet, mät igen. |
| Kelly | Demosidan och appen ska se ut som samma produkt: förbättra sidan, och skriv designunderlag för appen i `docs/design/` som Angela bygger. |
| Oscar | Oberoende test av den senaste klara K-punkten som saknar O-punkt. |
| Toby | Omtest av den senaste klara A-punkten, annars förstagångsanvändaren i simulatorn. |
Fokus för allt som syns: **lätt att förstå, lätt att komma igång, aldrig överväldigande, en tydlig väg framåt.**

## 3. Verifiering på telefon
- Allt märks verifierat på enhet / i CI / i simulator / ej verifierat.
- Aron kör `docs/DEVICE-TEST-QUICK.md` när han kan. Fynden blir prio 1. Bygget fortsätter under tiden.

## 4. Faser (mål, inte punkter)
| Fas | Mål | Klart när |
|---|---|---|
| 1 | Provläge stabilt på telefon | 20 min Provläge på iPhone + AirPods utan döv mikrofon, "första svaret räcker" enligt Aron |
| 2 | Pluggfunktionerna (övningsprov, repetition, plan, uttal, länkar) | Alla godkända K/A-punkter för det klara och testade av Oscar/Toby |
| 3 | Inför beta | Developer-konto, TestFlight, integritetspolicy, kostnad per timme mätt, namn beslutat |
| 4 | Beta | 10–20 elever på TestFlight, användning och kostnad mätt |

Faserna överlappar: punkter för nästa fas tas när köns tidigare punkter väntar på något.

## 5. Kontext och sessioner
Varje session byts efter 5 punkter eller en komprimering (`prompts/queue/README.md` punkt 7).

## 6. Datum som inte får missas
| Datum | Vad | Vem |
|---|---|---|
| senast fre 13 nov | Installera om appen, den gamla går ut lör 14 nov | Aron |
| före 3 dec | Anthropic-nyckeln från 3 nov går ut (ej verifierat för nyckeln i Max-kontot) | Deangelo kollar, Aron byter |
| ca 7 dec | `SUPABASE_ACCESS_TOKEN` går ut | Aron förnyar |
