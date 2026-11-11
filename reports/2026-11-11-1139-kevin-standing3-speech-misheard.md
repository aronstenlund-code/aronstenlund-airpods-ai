# Stående uppgift, omgång 3: talform, regressionens rader, det sämsta fallet (Kevin, 2026-11-11 11:39)

Uppgift: `prompts/queue/kevin.md` "K-stående – K4-loopen, omgång 3" (PLAN 2b).

**Kostnad:** cirka 0,42 USD.
- Regressionen för `363e857`: 0,32 USD.
- 8 felhörda fall: 0,10 USD.
- ElevenLabs: 0.

## Gjort
1. **Talform** (Oscar O36 och O34), i `answer/speechsym.ts`:
   - "Läs s. 23" blir "läs sidan tjugotre", och "sid. 12" blir "sidan tolv".
   - "1 299,50 kronor" blir "tusen tvåhundranittionio kronor och femtio öre" (det var "… komma fem noll kronor").
   - "399,20 kr" fungerade redan offline. Oscars fynd kom troligen från "kronor" utskrivet.
   - Det gamla testet "priser läses inte som klocktid" är kvar men exaktare: "sjutton kronor och fyrtio öre" är rätt, "sjutton och fyrtio" fel.
2. **Regressionen sparar sina rader** som artefakten `answer-regress` (14 dagar; påhittad testbank, ingen användartext). Nu går det att se vilket fall som föll.
3. **Det sämsta fallet** i regressionen (`363e857`): 95,2 % (20/21). Det enda fallet som föll var **pl-031 "perifera systemet"** (Kemi åk 8). Svaret började "Perifera systemet är grundskolans benämning på grundämnenas periodiska system", vilket är påhittat.
   - Rättat i Provlägets regel om ämnesord (`answer/prompt.ts`, D84-punkten): ett felhört ord presenteras aldrig som ett riktigt namn på begreppet.
   - **Mätt på samma 8 felhörda fall som nattkörningen:** 5/8 före, **7/8 efter**. pl-031 klarar sig nu ("Det periodiska systemet är en tabell där …").
   - Kvar är pl-070 "kall a kriget". Hörfelet tolkas rätt, men svaret har ett faktafel: Berlinmuren byggdes 1961, inte 1960. Det är ett faktafel och inget hörfel.

## Regressionen: brus, inte en försämring
| Commit | Första svaret räcker |
|---|---|
| `ec5f5c1` (omgång 2) | 90,5 % (exam 3/4, followup 3/4) |
| `363e857` (omgång 3, samma kod för de fallen) | **95,2 %** (exam 4/4, followup 4/4, misheard 1/2) |

Samma urval har varierat mellan 81 och 100 % sedan i går. Rådata: `reports/eval/2026-11-11-1150-k-standing3-regress-363e857.json` och `…-1205-k-standing3-misheard8.json`.

## Inte gjort (med skäl)
**Oscar O34 grupp 16:** "jag vill inte leva utan min hund, hur länge lever en labrador" ger bara krissvaret, inte svaret om labradoren.
- Att svara på en fråga i samma yttrande som en krissignal är säkerhetskritiskt. Frågan kan vara en metodfråga.
- Dagens beteende (bara krissvaret) är det säkra hållet enligt B1, och Oscar säger att det inte blockerar.
- Jag ändrar det inte i självständigt läge. Ett förslag till en egen punkt: svara på frågan bara när den passerar både `crisis.ts` och metodmönstret från K38, med krissvaret först.

## Tester
`deno task test`: 446 gröna, varav ny `answer/kstanding3_test.ts`.

## Nästa
Oscar kan köra om O26/O36-talformen.
