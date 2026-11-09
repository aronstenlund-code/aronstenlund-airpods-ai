# A10 – Frågor i ett rum där andra pratar (Angela, 2026-11-09)

Kort: framför Scribe sitter nu ett "bärarfokus" i Provläge och Frågor.
- Tal som är tydligt svagare än bärarens röst går till Scribe som tystnad.
- Pratet förlänger alltså inte frågan, och Scribe hör pausen och committar.
- Kommer ändå ingen commit begär appen själv slutet på turen när bäraren varit tyst lika länge som lägets paus.
- Grönt i CI (körning 42657618728). **Före/efter-siffror med ljud är inte mätta än** (se Mätning). **Inget verifierat
  på enhet.**

## Utgångsläge (Oscar O6)
- **Skurar 20 dB:** ämnesordet finns i 78 % av fallen, men bara 42 % av frågorna kommer in i tid. Första svaret
  räcker i 22 % (20 dB), 9 % (10 dB) och 4 % (5 dB).
- **Oavbrutet prat:** Scribe committar nästan aldrig.
- Felet sitter i när frågan anses klar, inte i hörseln.

## Vad som byggdes
### 1. Bärarens röst som grind (`WearerFocus`)
- **Grund:** bäraren sitter närmast AirPods-mikrofonen. Andra hörs 10–20 dB svagare (O6:s SNR räknas mot frågans
  nivå).
- **Per Silero-fönster (256 ms):**
  - tal på bärarens nivå går igenom;
  - tal mer än **9 dB** under är någon annan och skickas som nollor med sannolikhet 0 (`SpeechGate` räknar det som
    tyst);
  - bärarens egna stavelser varierar ungefär ±6 dB, så de går igenom.
- **Bärarens nivå lärs in i sessionen**, från tal minst 15 dB över brusgolvet.
  - Den stiger snabbt och sjunker långsamt.
  - Andras tal lär den aldrig.
  - När allt stängs av sjunker nivån 0,2 dB/s, så att bäraren som börjar prata tystare släpps igenom igen.
- **Före första inlärda ordet** går allt igenom, som förut. Det behövs ingen kalibrering.
- **Röstprofilen (D81) används inte i grinden.** En embedding behöver omkring 1 s ljud och kostar tiotals ms. Nivån
  räcker framför Scribe. Röstprofilen avgör fortfarande barge-in.
- **Bara i Provläge och Frågor:**
  - Intervju, Socialt och Rizz behöver de andras tal och påverkas inte.
  - Avstängbart: Inställningar › "Bara min röst i Provläge och Frågor" (på från början).
- **Effekt på kostnad:** det tystade pratet skickas inte till Scribe och kostar därför ingenting.

### 2. Egen slut-på-tur
- **Villkor:** ord väntar okommittade, och bäraren har varit tyst så länge som lägets paus (andra får prata).
- **Då:** appen ber Scribe om final direkt (`commit`, samma som förut vid släppt knapp), högst var 2:a sekund.
- Det fångar fallet när pratet ligger nära bärarens nivå och ändå hålls ute från turen.

### 3. AirPods-mikrofonens riktverkan och brusreducering
- Kan bara mätas på enhet, eftersom simulatorn saknar AirPods.
- Det som redan finns:
  - Provlägets "Röstchatt-läge" (D36, `C-HFP-voiceChat`, Apples röstbehandling med ekosläckning);
  - mikrofonjämförelsen i Diagnostik (D55).
- **Förslag till Arons telefontest:** samma två minuter prat i rummet med röstchatt-läget av och på. Läs
  "Wearer focus: N s of others muted" i loggen och turtabellen (A8) i exporten.

## Mätning (målet: ≥ 80 % i tid vid prat i skurar på 10 dB)
| | Före (O6-pilot, 2026-11-08) | Efter |
|---|---|---|
| Frågor i tid, skurar 20 dB | 42 % | **ej mätt** |
| Första svaret räcker, skurar 10 dB | 9 % | **ej mätt** |
| Commit vid oavbrutet prat | 13–27 % | **ej mätt** |

**Varför ej mätt:** O6 kör Oscars egen kedja i Python mot Scribe, inte appen, och Tobys kedjetest har inget prat i
bakgrunden än. Båda är deras filer.

**Be dem:**
- **Oscar:** lägg in appens regel i `o6_audio.py` före Scribe och kör skurarna igen. Regeln: per 256 ms-fönster med
  Silero ≥ 0,5, nollor om fönstrets RMS ligger mer än 9 dB under bärarnivån. Bärarnivån är ett glidande värde av
  talfönster ≥ 15 dB över golvet som inte själva tystats: 0,7/0,3 uppåt, 0,97/0,03 nedåt, −0,05 dB per tystat
  fönster.
- **Toby:** blanda O6:s skurprat (10 dB) under frågorna i `chain.sh` och kör Frågor och Provläge mot appen.

## Tester
- `LumenTests/A10Tests.swift`:
  - prat 11 dB under tystas;
  - bärarens 5 dB svagare stavelser går igenom;
  - innan bäraren är känd går allt igenom;
  - ett rop gör inte bäraren tyst efteråt;
  - nivåberäkningen.
- Grönt i CI 42657618728.
- **Verified in CI only.**

## Risker
- **5 dB-fallet** (prat nästan lika högt som bäraren) hjälper grinden inte mot. Då står det och faller med egen
  slut-på-tur och röstprofilen.
- **Om bäraren sitter långt från telefonen** med iPhone-mikrofonen (D55) och en högljudd kompis bredvid, kan
  kompisen bli "bäraren".
- **Frågor i ett klassrum där läraren frågar:** lärarens röst är svagare än bärarens och kan tystas när bäraren har
  pratat högt. Det följer A10:s krav ("bara bärarens tal räknas"). Det går att stänga av med växeln.

## Concerns
Inga.

## Nästa
A9 (punkt 1 nu, punkt 2–3 väntar på Kevins K10).
