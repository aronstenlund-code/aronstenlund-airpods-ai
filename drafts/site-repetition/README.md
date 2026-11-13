# Utkast: demosidan för repetitionsläget (Kelly, Ke51)

**Publiceras inte.** Mappen ligger utanför `site/` (Pages publicerar bara `site/**`), och sidan har
`noindex, nofollow`. Den läggs in i `site/` först när Tobys T18 är godkänt och Aron har sagt ja.

## Vad som ändras mot `site/index.html`
| Del | Utkastet |
|---|---|
| Hero | "Plugga med AirPods utan att röra mobilen." + "Fota ditt material. Earmind gör provfrågor med svar och läser upp dem i örat." + "Du styr med tryck på AirPods. Telefonen kan ligga i fickan." |
| Demorutan | En repetitionsdemo utan server: tre påhittade frågor (biologi åk 9). 1 tryck visar det långa svaret, 2 tryck det korta (första meningen, D145) och 3 tryck pausar. Under paus fortsätter vilket tryck som helst (D143/D147). "Nästa fråga" börjar om efter fråga 3. Livedemon finns kvar men är dold (`hidden`), eftersom sidans skript letar efter dess element. |
| Så kommer du igång | Fota ditt material → Kolla frågorna → Tryck Starta prov. Inga skärmbilder förrän appen är provad på telefon (Ke3: aldrig påhittade skärmar). |
| Vad kan Earmind? | Heter "Mer i Earmind" med märket Beta och raden "Lägen som lyssnar … Starta prov använder aldrig mikrofonen." (D142). |
| Resten | Oförändrat (väntelistan, integritet, FAQ). |

## Filer
- `hero.html`, `steps.html`, `draft.css` och `draft.js` är delarna. `build.py` sätter ihop dem med dagens `site/index.html` till
  `index.html`: `python -I drafts/site-repetition/build.py`. Bygg om när `site/index.html` ändras.
- `shots.js` tar skärmbilder till `bilder/`, mobil 390 och dator 1280, ljust och mörkt, samt långt svar, paus och stegen.
  Det kräver en http-server från repots rot, eftersom typsnittet blockeras under `file://`:
  `python -m http.server 8765` och `BASE=http://127.0.0.1:8765 node drafts/site-repetition/shots.js`.

## Innan det publiceras
1. T18 godkänt och Arons ja.
2. Ljudet i demon: riktiga uppläsningar av de tre frågorna och svaren, med samma röst som i appen (efter K48:s val),
   som statiska filer. Inga anrop från sidan.
3. Skärmbilder i stegen från Angelas A82 (CI), WebP 300 px bred.
4. FAQ och JSON-LD: en fråga om repetitionsläget ("Måste jag prata med Earmind?" → "Nej. Starta prov läser upp frågorna
   och du styr med tryck.").
5. Ny delningsbild med budskapet. `site/` högst 2 MB och Lighthouse minst 95.
