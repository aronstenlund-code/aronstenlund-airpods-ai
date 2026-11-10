# Kevin K29: T1, billigare Provläge (D115)

Datum 2026-11-10 19:55–20:12. Uppgift: `prompts/queue/kevin.md` K29. Commit `74b9b5f`. **Resultat: byggt men avstängt**, eftersom rullregeln inte håller.

## Vad som byggts
- `answer/length.ts` `isShortFactQuestion`: en försiktig klassare för korta faktafrågor i Provläge.
  - Den tar frågor som börjar med när + händelseverb, vem skrev/uppfann/upptäckte …, vilket år, vad heter/kallas, vad står X för, var ligger, hur många + räknebart substantiv, huvudstad, kemiskt tecken och SI-enhet.
  - Frågan ska ha 3–12 ord.
  - Den tar aldrig: förklaringar (STUDY_CUES), flera frågor ("… och vad handlar den om"), tal och enheter (uträkningar), regler ("när använder man some"), "vem var X" (biografi) eller "vad heter det när …" (begrepp).
- `handler.ts`: om `tutorFactRoute` är på går en sådan fråga till standardmodellen (Haiku) i stället för `tutorModel` (Sonnet). Brytaren är miljövariabeln `TUTOR_FACT_ROUTE=1`. Standard är **av**.
- `provlage-eval` slår alltid av routningen, så att en modelljämförelse kör den valda modellen på alla fall.
- Nya filer: `answer/k29_test.ts` (klassare och routning) och `scripts/k29-fact-bank.json` (20 korta faktafrågor i Provläge, sex ämnen).

## Mätning (verified live mot driftsatt kod före routningen, Sonnet bedömer, tvånivåsvar)
| | Sonnet | Haiku |
|---|---|---|
| Korrekt | **100 %** | **75 %** (5/20 fel) |
| Första svaret räcker | 60 % | 75 % |
| Första svaret + ett "ja" (D100:s huvudmått) | **90 %** | **60 %** |
| Naturligt språk | 100 % | 70 % |
| Kostnad per svar | 0,0145 USD | 0,0006 USD |
| Första text, server p50 | 1,25 s | 0,87 s |

**Haikus fel, ordagrant ur bedömningen:**
- Berlinmuren "föll 1991, byggd 1962" (rätt är 1989 och 1961).
- "Sverige blev demokrati 1919" (utan 1921).
- "det ena paret av varje par" om kromosomer.
- Fel titel för Stalin.
- **Krissvaret på "när skrevs Gösta Berlings saga"**: Haiku svarade `[[KRIS]]`. Det har nu rättats i promptregeln (K34).

**Andel av Provläge som skulle gå till Haiku:**
- D87-banken: **0/207**.
- Oscars verklighetsbank (O15, O15b, O15c, Provlägesfall): **1/130** ("när föll muren alltså den i Berlin").

Elever i Provläge ber nästan bara om förklaringar och begrepp. Hela besparingen med routningen på vore alltså under 1 % av Provlägets kostnad, mot fel årtal i provplugget.

## Beslut (Kevin, inom D115)
Routningen rullas inte ut. Regeln var "rulla bara ut om första svaret räcker inte sjunker mer än 1 procentenhet". På de frågor som ändringen gäller sjunker korrektheten 25 procentenheter och huvudmåttet 30.

Kostnad per svar före/efter: oförändrad. Provläge på Sonnet kostar i snitt 0,012–0,015 USD per svar med tvånivåsvar (regressionen 0,0122, faktabanken 0,0145).

## Vad som faktiskt skulle göra Provläge billigare (förslag, inte byggt)
1. **Den utvecklade delen kostar mest.** D100 skriver alltid det långa A-nivåsvaret efter det korta, även när eleven aldrig säger "ja". Om den delen skrevs först när eleven ber om den, eller av Haiku utifrån Sonnets korta svar, skulle cirka hälften till två tredjedelar av utdatatokens försvinna. Det gör dock att "ja" tar längre tid (cirka 1 s). Det behöver ett beslut från Architect/Aron.
2. Längre cachning av den statiska prompten finns redan (cache_read). Inget mer att hämta där.

## Kostnad
- Mätningen: 0,29 (Sonnet) + 0,012 (Haiku) + 0,26 (bedömning) = cirka 0,56 USD.
- CI-regressionen: cirka 0,32 USD.
