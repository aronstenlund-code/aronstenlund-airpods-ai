# Oscar O20: Vilka frågor söker på webben, och var (K16), offline

Datum: 2026-11-10 08:44–08:50
Uppgift: stående uppgift (PLAN 2b), uppföljning av O13 del 1
Skript: `scripts/qa/o20_web_routing.mjs` (driftsatt `answer/web.ts` i Node 24, gratis)
Rådata: `reports/qa/data/2026-11-10-0845-o20-web-routing.json`

Det här är **verified in code**. Det förklarar två fynd från O13 del 1:
- SVT-rådet om Hitta min iPhone;
- att vissa recept inte söker.

## Resultat: 15/20 dirigeras som de bör
| Fråga | Bör | `lookupKind` / `needsWeb` |
|---|---|---|
| "hur stänger man av hitta min iphone" | instruktion | **ingen** |
| "hur sätter man på mörkt läge på en iphone" | instruktion | **ingen** |
| "hur tar man en skärmdump på en mac" | instruktion | **ingen** |
| "hur laddar man ner spotify på datorn" | instruktion | **ingen** |
| "får man cykla på trottoaren" | regel | **ingen** |
| "hur byter man lösenord på instagram" | instruktion | instruktion ✓ |
| recept: pasta, ris, potatis, pizzadeg, chokladbollar, sockerkaka | recept | recept ✓ (6/6) |
| "är det lagligt att köra moped utan hjälm", "vilken åldersgräns gäller för solarium" | regel | regel ✓ |
| invånare i Kiruna, rektor i Uppsala, pris på SL-kort | fakta/pris | sök ✓ |
| fotosyntes, Gustav Vasa, 15 procent av 80 | ingen sökning | ingen ✓ |

## Fynd
1. **Fel ordföljd för partikelverb i `HOWTO_Q` (`web.ts` rad 108).**
   - Mönstret är `hur (?:… stänger av | sätter på | laddar ner | tar bort | ställer in | startar om) (?:man|jag|du)`. Det matchar "hur stänger av man".
   - På svenska säger man "hur stänger **man** av", "hur laddar **man** ner", "hur tar **man** bort" och "hur startar **man** om".
   - Därför matchar inga partikelverb i naturlig svenska. "Hitta min iPhone" gick i stället genom modellens egen `[[SÖK]]` till de vanliga domänerna. Där fanns svt.se, och svaret blev "bör man stänga av den".
   - Rättning: `hur (?:stänger|sätter|laddar|tar|ställer|startar) (?:man|jag|du) (?:av|på|ner|bort|in|om)`. Dessutom saknas "hur tar man (en skärmdump|en bild)".
2. **Domänerna för instruktioner och recept begränsar inte.**
   - `webTools` ger `allowed_domains` = alla pålitliga domäner (svt.se, gp.se, cnn.com, bloomberg.com …) **plus** recept- eller supportdomänerna.
   - En recept- eller instruktionsfråga kan alltså fortfarande få svaret från en nyhetssajt.
   - Kevins K16-rapport säger "söker på ica.se, arla.se …" och "tillverkarnas supportsidor". Det gäller bara som tillägg, inte som gräns.
   - Förslag: när `lookup` är `recipe` eller `howto`, använd **bara** de domänerna (eventuellt plus 1177.se och livsmedelsverket.se för recept).
3. **"får man …" är inte en regelfråga.** `RULE_Q` godtar bara "får man lagligt" och "får man enligt lag". Vanligt talspråk är "får man cykla på trottoaren", "får man ha moped vid 15" och "får man filma på skolan".
4. **Pasta live mot offline:**
   - Offline ger "hur kokar man pasta" `recipe`, men live i O13 sökte frågan inte (`source: null`, 0 sökningar).
   - Samma användare hade gjort 4–5 sökningar på cirka 2 minuter. Webbtaket är 3 per minut (`webLimits.perMinute = 3`). Jag gissar att taket slog till och att svaret då gavs utan sökning (**untested assumption**).
   - Det tomma svaret i pizzakedjan (O13 fynd 2) kan ha samma orsak: en sökning som nekas mitt i en följdfråga.
   - **Följd för appen:** en elev som lagar mat och ställer fyra frågor i rad hamnar utanför sökningen redan vid fjärde frågan.

## Till Kevin
- Fynd 1: ordföljden i `HOWTO_Q`. Det är ett tydligt fel och lätt att rätta. Testfall: de fyra frågorna i tabellen.
- Fynd 2: gör `recipe` och `howto` till begränsande domänlistor.
- Fynd 3: lägg till "får man/jag + verb" i `RULE_Q`. Kontrollera falska träffar: "får man en kram", "får jag fråga en sak".
- Fynd 4:
  - Gör webbtaket per minut till 5, eller låt följdfrågor i samma källa räknas som en sökning.
  - Svara aldrig tomt när sökningen nekas. Svara då ur förra svaret.
  - Kontrollera i loggen (`llm_fallback` och webbtaket) för O13-användaren.

## Kostnad
0 USD.
