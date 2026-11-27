# O105: Säg i AirPods och Spela in själv på servern, och hjälpen, Oscar (moln)

> Modellsvaren är mina: jag spelar Haiku, och det är **inte modellen i drift**. Det som prövas är serverns kontroller efter modellen och promptarnas innehåll.

**Omfattning:** **21 fall.**
- **Stilen**, "Hur ska det låta?" (ST1–ST5).
- **Röstvalet** (VO1–VO5).
- **Säg-textens talformat** (TT1–TT5, ingen modell).
- **Hjälpen** (HL1–HL5).
- **Komprimera**, kort text (CO2).

Om verktyget och reglerna:
- Stilen och röstvalet finns inte i K122, så de körs med `scripts/qa/o105/style_voice.ts`. Det är serverns egna `haikuStyler`, `haikuVoicePicker` och `voiceText`, med en låtsasleverantör som ger mina svar.
- Hjälpen och Komprimera körs genom K122 (`scripts/qa/o105/run.py`).
- 0 ElevenLabs, 0 Claude, inga nätanrop.

**Spela in själv har ingen serverdel** (**verifierat i kod**). `Lumen/Core/OwnDeck/` (OwnDeck, OwnRecorder, OwnDeckStore, OwnDeckModel) har inga nätanrop, och ljudet stannar på telefonen enligt D263. Det enda servern ser är hjälpen, om man frågar den.

**Facit för omkörning:** `scripts/qa/OMKORNING.md` säger vilka fall som körs om efter en ändring, område för område.

## Utfall (**verifierat i återspelning/harness**)
| Fall | Vad | Utfall |
|---|---|---|
| ST1 | "lugnt och tydligt, som en lärare" | taggarna godtas: "[calm] … [pause] …" |
| ST2 | "glatt", men modellen bytte ett ord (bladen → löven) | **avvisat** (`style_words_changed`). Koden ger "[cheerful]" på den oförändrade texten. Bra |
| ST3 | engelska, "slow, with pauses so I can write" | "[slowly] … [long pause] …" godtas |
| ST4 | "viska lite", modellen vägrar | koden ger "[whispers]" (K106) |
| ST5 | glosor, "med pauser så jag hinner skriva" | pauser mellan glosorna godtas |
| VO1/VO3 | "lugnt" och "på skånska" | Jonas, och Bertil (skånska), med skälet |
| VO2 | "med kinesisk brytning" (finns inte) | Jonas och "Ingen röst med kinesisk brytning finns ännu …", ärligt |
| VO4 | modellen svarar ett id som inte finns | `null`, alltså standardrösten. Bra |
| VO5 | "on English, friendly" | Alyssa, men **skälet är svenskt** (se O105-4) |
| TT1 | "kl. 14.30 den 3 maj, t.ex. i sal 2B … ca 50 kr" | "klockan fjorton och trettio den tredje maj, till exempel i sal två B … cirka femtio kronor" |
| TT2 | "100 °C … 1 250 elever, 12 % fler än 2019" | "hundra grader celsius … tolvhundrafemtio elever, tolv procent fler än tvåtusen nitton" |
| TT3 | "s. 45–47 och kap. 3. pH 7 är neutralt, **H2O är vatten och CO2 koldioxid**" | "sidan fyrtiofem till fyrtiosju och kapitel tre. pH sju …", men **"vatten är vatten och koldioxid koldioxid"** (O105-3) |
| TT4 | engelska "2.30 pm on 3 May, e.g. … $5" | oförändrat. Den engelska rösten får tolka själv (**untested assumption** om hur ElevenLabs läser det) |
| TT5 | "112 … 1177 … Karl XII dog 1718, och Gustav II Adolf 1632" | "ett ett två … elva sjuttiosju (D46) … Karl den tolfte … Gustav den andre Adolf …" |
| HL1 | "hur byter jag röst" | hjälptexten säger "**du väljer bland tre röster** innan ljudet görs" (O105-1) |
| HL2 | "how do I share a quiz with my class" (en) | svaret blir **svenskt**: prompten kräver "Swedish du-form" och får inget språk (O105-2) |
| HL3 | "vad är huvudstaden i frankrike" | `in_scope: false`, och servern säger "Det kan jag inte svara på." med ledtråd |
| HL4 | "kostar det krediter att spela in själv" | "**Det vet jag inte.** Skriv till oss …", för funktionen finns inte i hjälptexten (O105-1) |
| HL5 | "varför spelas inget när skärmen är låst" | "Det vet jag inte …" (O105-1) |
| CO2 | Komprimera, 3 meningar | en mening, alla fakta kvar |

## Fynd
- **O105-1 (medel–hög, till Kevin och Deangelo): hjälpens kunskap är gammal.**
  - Hjälptexten som modellen får (`docs/HJALP.md` / `shared/hjalp.ts`, 12 300 tecken) nämner **inte** Säg i AirPods (första skärmen), Komprimera, "Hur ska det låta?", krediter, aktiveringsordet, Spela in själv eller låst skärm.
  - Om röster står det "tre röster" (katalogen har 19, D252).
  - Hjälpen svarar därför "Det vet jag inte" på frågor om appens viktigaste delar, eller ger fel svar om rösterna (**verifierat i prompten**). En granskare som provar hjälpen ser det.
  - Förslag: uppdatera HJALP.md efter D203, D213, D252, D259, D262 och D263. Kelly eller Angela kan skriva texten, och Kevin synkar `hjalp.ts`.
- **O105-2 (medel, till Kevin): hjälpen är bara svensk.**
  - Prompten säger "Swedish du-form", och `lang` och `x-earmind-lang` når inte modellen. Det gäller också fasta texter som "Det vet jag inte …".
  - Appen startar på engelska (D253), så en engelsk användare får svar på svenska (HL2).
- **O105-3 (medel, till Kevin): talformatet byter kemiska formler mot namn.** "H2O är vatten och CO2 koldioxid" blir "vatten är vatten och koldioxid koldioxid", så det eleven vill lära sig försvinner. Förslag: läs formeln som den skrivs ("H två O", "C O två"), eller låt bli formler i `voiceText`.
- **O105-4 (låg–medel, till Kevin): röstvalets skäl är alltid svenskt.** Prompten säger "a Swedish text" och "one short Swedish sentence" också när texten och appen är engelska (VO5). Om skälet visas i appen blir det svenska i en engelsk app.
- **O105-5 (låg):** engelsk Säg-text normaliseras inte ("$5", "e.g.", "2.30 pm"). Den svenska vägen gör "t.ex." till "till exempel". Det är **untested assumption** om ElevenLabs läser det rätt. Bör provas när det är tillåtet (D180: bara Aron på telefonen).

## Omtest av Kevins O104-rättningar
Väntar på hans rad i min kö. Fallen står i `scripts/qa/OMKORNING.md` (rättningen G1–G7, drill PX1–PX6, PF1, PF2).
