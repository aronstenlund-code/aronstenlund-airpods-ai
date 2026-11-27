# Kevin (moln) – O105: hjälpens kunskap och språk, formler i talet, röstvalets skäl

**Datum:** 2026-11-27 04:30. **Uppdrag:** Deangelo 02:58. Fynden är tagna i hans ordning.
**Regler:** inga riktiga modellanrop, 0 ElevenLabs. **Svit:** 918/918. **Driftsatt:** push till main.

## O105-1: hjälpens kunskap (docs/HJALP.md och shared/hjalp.ts)

HJALP.md är uppdaterad och `hjalp.ts` är synkad med `scripts/sync-hjalp.py`. Testet `hjalp_test` stoppar driftsättningen om de två skiljer sig.

Varje påstående har en källa i ett beslut eller i appens egen text (`Localizable.xcstrings`), med Kellys ord ur `docs/design/ordlista-app.md`:

| Nytt i hjälpen | Källa |
|---|---|
| **Säg i AirPods**: text, **Spela i**, kostnaden ("Kostar 764 krediter. Upprepningar kostar inget."), Tempo | D203, D213, appens text |
| **Komprimera**: minst 160 tecken, texten kan ändras, Ångra, spelar inget, kostar inget | D262, K120 |
| **Hur ska det låta?** och **Skriv i takt** (paus efter varje fras); orden ändras aldrig | D220, K95 |
| **Välj röst** och **Provlyssna**: en lista med svenska och engelska röster. Ersätter "tre röster". | D252, K124, appens text |
| **Krediter**: 1 kredit = 1 tecken nytt ljud, 1 500 i månaden, vad som är gratis, **Fyll på** och **Veckokort**, lanseringsrabatten 65 % "så länge veckan pågår". Ersätter "15 frågor" och "det går inte att köpa". | D213, D224, D259, D261 |
| **Aktiveringsordet**: "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI." | D259 (A162) |
| **Spela in själv – helt gratis**: egna frågor och svar med egen röst, ljudet stannar på telefonen, telefonens röst läser det som inte är inspelat | D263, D264 |
| **När servern inte kan**: telefonens röst ("Telefonens röst läser just nu."), telefonens modell för Komprimera och rättning ("Telefonens modell:"), svar i lyssnandet, "Kan inte skapa prov just nu" | D260, D262, D267, Ke90 |
| **Låst skärm**: Starta prov styrs med låsskärmens knappar. Om inget spelas: lås upp och tryck spela igen. | befintlig text. Kelly: att Säg spelar vidare med låst skärm är inte provat (D209), så hjälpen lovar det inte. |

Övrigt:
- Knapparnas engelska namn står inom parentes, till exempel **Säg i AirPods** (Say in AirPods). Hjälpen använder dem när den svarar på engelska.
- Välkomstkrediterna (5 000) nämns inte. De lovas inte förrän välkomsten är påslagen (D239 punkt 4).
- Promptens rad om priser ("coming later, no prices yet") är ersatt med "say what <hjalp> says under Krediter".

## O105-2: hjälpen på användarens språk

- `helpLang` väljer språk i den här ordningen:
  1. appens val (`lang`, `language` eller `x-earmind-lang`);
  2. svenska ord i frågan;
  3. annars engelska (appen startar på engelska, D253).
- Modellen får `<language>en</language>` eller `<language>sv</language>`.
- Prompten säger att svaret ska vara på det språket och använda de engelska knappnamnen.
- De fasta texterna finns nu på engelska: utanför ämnet, ledtråden, "I don't know that …", trycken ordagrant och korta och långa svaret.
- Svenska fungerar som förut.
- Test: `help/o105_help_test.ts`.

## O105-3: formler i talet

- **Talreglerna version 5:** står ämnets namn redan i samma mening ("H2O är vatten") läses formeln som den skrivs: "H två O", "C O två", "C sex H tolv O sex".
- Står formeln ensam blir den namnet som förut ("tar upp CO2" blir "koldioxid").
- På engelska: "H two O".
- Prov som gjordes med version 4 eller tidigare behåller sin text, så deras ljudhashar håller och inget nytt ljud görs.
- Test: `drill/o105_formula_test.ts`. Två äldre tester som låste "senaste version = 4" säger nu 5.

## O105-4: röstvalets skäl

- Prompten säger "a text" i stället för "a Swedish text". Skälet skrivs på `<language>` och är svenska när taggen saknas.
- Drillen skickar `<language>en</language>` bara när appen uttryckligen ber om engelska. En äldre app utan språk får svenska som förut.
- Test: `drill/o105_voice_test.ts`.

## Omkörning enligt `scripts/qa/OMKORNING.md` (verifierat i återspelning)

- **TT1–TT5 med version 5:** TT3 blir "pH sju är neutralt, **H två O är vatten och C O två koldioxid**". TT1, TT2 och TT5 är oförändrade. TT4 blir "for example" i stället för "e.g.", eftersom den engelska vägen nu körs med språket "English".
- **Oscars harness `style_voice.ts`:** den kör version 4 (`rules4`) och röstvalet utan språk, så där är TT3 och VO5 som förut. Det är med avsikt för gamla prov. Den behöver version 5 och `lang` för att visa ändringen.
- **HL1–HL5 (hjälpen):** varje prompt bär nu de nya fakta, och HL2 får `<language>en</language>`. Oscars sparade svar är skrivna mot den gamla prompten, så svaren är oförändrade. Han behöver spela modellen igen mot de nya promptarna.
- **CO2 (Komprimera):** oförändrat.

## Inte gjort

O105-5 (låg): den engelska Säg-texten normaliseras inte ("$5", "2.30 pm"). Hur ElevenLabs läser det är en untested assumption och får provas först när Aron själv provar på telefonen (D180).

## Nästa

- **Oscar:** omtest. Spela HL1–HL5 mot de nya promptarna, kör TT3 med version 5 och VO5 med `lang: "en"`. Raden ligger i hans kö.
- **Kelly eller Angela:** läs HJALP.md. Texten bygger på besluten och appens ord, men ingen har provat varje rad på telefon.
