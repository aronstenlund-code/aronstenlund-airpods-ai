# Tobys fynd utan nät: trycket nådde aldrig Spela (Angela Fable (moln), 2026-11-19 00:15)

Fyndet (Toby 2026-11-18 18:00, T36 44312213280): med nätet av gav en ny Säg-text ingen rad alls på 25 s, och knappen
hette kvar "Spela i 10 min". Före K100 (44235040986) kom "Ingen internetanslutning …" efter 1,9 s.

## Vad jag kom fram till

**Trycket på Spela startade ingenting i appen. Det var inte ett svar som blev tyst.** Jag har jämfört testloggen från
den körning som fungerade (44235040986) med den som föll (44312213280, omkörningen 17:37 UTC). **Verifierat i CI-loggen
(Simulator), inte på enhet.**

| Efter trycket på Spela (ny text, nätet av) | 44235040986 (fungerade) | 44312213280 (föll) |
|---|---|---|
| Tangentbordet | borta | **kvar uppe** |
| Senaste | ny kapsel "Ny text utan nät 75666.…" | **ingen ny kapsel** |
| Rad på kortet | "Ingen internetanslutning …" efter 1,9 s | ingen |

Spela fäller alltid ner tangentbordet och sparar texten på telefonen innan något skickas. Inget av det hände. Alltså
kördes Spela inte: knappen gick inte att trycka på just då, eller så träffade trycket inte.

Det betyder också att min rättning 19:55 (Spela är aldrig tyst, och loggar sina steg) **inte hade ändrat den här
körningen**. Den gäller ett svar som kommer utan rad, och hit kom inget svar eftersom ingenting startade.

**Varför knappen inte svarade är inte belagt.** Knappen stängs av i tre lägen: tomt fält, ett tidigare tryck som
fortfarande väntar, eller en text som kostar mer än det som finns kvar. Fältet var inte tomt (röstkapseln "Adam" syns
bara med text i fältet). Av koden hittar jag ingen väg där ett tidigare tryck blir kvar som väntande, och inget som gör
kostnaden för hög utan nät. Skärmbilden `t36-11-utan-nat-ny` skulle visa om knappen hade snurran (väntar) eller var
nedtonad; jag kommer inte åt körningens bilder härifrån (bilagorna går inte att hämta i min miljö).

## Vad jag har ändrat (Lumen/Features/Repetition/SayViews.swift)

1. **Ett tryck som väntar kan inte lämna Spela avstängd.** När texten hörs, när spelaren visas och när kortet slutar
   spela släpps "väntar" alltid, oavsett om anropet som startade det har kommit tillbaka. Förut släpptes det bara av
   svaret eller av att appen gav upp.
2. **Loggen säger varför Spela inte går att trycka på.** En rad varje gång läget ändras:
   `Say: Spela cannot be pressed (an earlier press is still waiting)`, `… (the text costs more than is left)` eller
   `Say: Spela can be pressed`. Tillsammans med `Say: Spela pressed …` från 19:55 visar nästa körning vilket det var.

Ingen ändring i vad användaren ser. Inga nya tester: det här är vyns eget tillstånd, som enhetstesterna inte når.

## Testresultat

- **iOS build 44418601653 på main är grön** (bygget för enhet, alla enhetstester, Release-bygget). **Verifierat i CI.**
- Ändring 1 är **inte sedd** i Simulator eller på enhet. Den rättar ett läge som jag inte har kunnat återskapa.
- 0 ElevenLabs.

## Kända fel och risker

- Orsaken till fyndet är inte funnen. Om knappen var avstängd av något annat än de två lägena ovan, eller om trycket
  missade, säger loggen "can be pressed" och ingen "Spela pressed". Då ligger felet i hur trycket landar, inte i
  kortets tillstånd.
- Tobys skript skriver i dag bara ut appens rader från det sista fönstret utan nät (Radera konto), inte från T49.

## Kvar

- Toby: skriv ut raderna `Say: ` ur appens logg för T49-fönstret, logga om Spela är `isEnabled` före trycket, och
  titta på bilden `t36-11-utan-nat-ny` från 44312213280. Skickat till honom 00:20.
- Nattflödet 44411718185 (T36 på main, före den här ändringen) står i kön. Går T49 grön där var det en engångssak
  eller rättad av 19:55-ändringarna; faller den igen behövs loggraderna.

## Nästa session

Läs Tobys svar. Säger loggen "an earlier press is still waiting": hitta vilket anrop som inte kom tillbaka (raden
före är `Say: Spela pressed (attempt N …)` utan `Say: answered`). Säger den "can be pressed" utan "Spela pressed":
felet är trycket, och då är det Tobys test eller knappens träffyta.

## Tillägg 00:55: Tobys svar

Toby tror att felet låg i testet: det trycker mitt på en knapp som XCTest kallar otryckbar, och med tangentbordet
uppe hamnade trycket då på tangentbordet. **Inte bekräftat** (loggen från körningen har ingen rad om att knappen var
otryckbar). Han har ändrat testet: tangentbordet döljs före Spela utan nät, knappens `isEnabled` och `isHittable`
loggas före trycket, och alla `Say:`-rader skrivs ut ur appens logg. Omkörningen gör han efter T54 7c. Raden i kön
står öppen tills den körningen är läst.
