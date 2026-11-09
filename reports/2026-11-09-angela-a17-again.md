# A17 – "Igen" upprepar exakt, med tidsregler (Angela, 2026-11-09)

Kort: "igen" ger nu **exakt samma svar**. Det är samma ljud ur minnet, utan nytt anrop, men bara när "igen" syftar på
Lumen enligt ägarens tidsregler. Grönt i CI (körning 42698361876). **Ej verifierat på enhet.**

## Regler (`AgainRule`, före allt annat i turen)
1. **Bara bärarens röst.**
   - Säger röstprofilen (D81) att någon annan talade händer inget.
   - Utan profil räknas rösten som bärarens, eftersom det inte går att avgöra.
2. **Som hela yttrandet**, med eller utan "Lumen": "igen", "en gång till", "säg det igen", "va?", "hörde inte",
   "jag hörde inte", "again", "pardon" … Upprepar om Lumen svarade för **högst 15 min** sedan.
3. **Sist i ett yttrande med brus eller andra ord** (fyllnadsord efter räknas inte): upprepar bara om Lumen svarade
   för **högst 45 s** sedan.
   - "Gör det igen sen" träffar inte, eftersom "igen" inte är sista ordet.
4. **Ljudet** spelas ur minnet (A7) om svaret är högst **120 s** gammalt. Är det äldre läses **samma text** upp igen
   via TTS. Inget nytt svar görs.
   - Samma regel gäller nu "Lumen, upprepa" och "upprepa".
5. Ett "igen" som inte gäller Lumen loggas ("'Igen' not for Lumen"). Resten av yttrandet hanteras som vanligt.
6. Raden finns i `docs/COMMANDS.md`.

## Tester (`LumenTests/A17Tests.swift`, gröna)
- Hela yttrandet inom 15 min, men inte efter 16 min och inte utan svar.
- Brus + "igen" efter 20 s träffar, men inte efter 50 s.
- "gör det igen sen" ger ingen träff, varken efter 2 min eller efter 10 s.
- Ett "igen" från en annan röst ger ingen träff. Utan profil räknas rösten som bärarens.
- "igenom skogen", "Lumen." och vanliga frågor är ingen träff.

## Risker
- **"Va?" ensamt räknas.** "Vad?" ensamt räknas också, som att man inte hörde. En lärare som säger "Vad?" till klassen
  utan röstprofil kan alltså få Lumen att upprepa, om Lumen svarade för mindre än 15 min sedan.
- **Utan röstprofil kan inte regel 1 hållas.** Röstprofilen gör den hård.

## Till Toby
- Lägg in i T6: "igen" efter ett svar (träff), "gör det igen sen" efter 2 min (ingen träff), och brus + "igen" efter
  20 s (träff).
