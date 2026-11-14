# Gör med ChatGPT: plats, steg och texter (Kelly, Ke58, D169, 2026-11-14)

Till Angela Fable (A93, vyn). Bilder: `bilder/apple/gpt-*.png`, ljust till vänster och mörkt till höger (källa
`_src/apple.html`). SYSTEM.md §0 gäller. **Det här är skisser. Inget är byggt.**

## Plats
Sist i sektionen **Material** i Nytt prov, som en egen rad med en neutral symbol (`doc.on.clipboard`, lila ruta som de
andra raderna) och undertext. Raden öppnar ett blad. Det finns ingen ChatGPT-logotyp och ingen gnista, och raden står
efter appens egna sätt, eftersom det är ett alternativ och inte huvudvägen.

## Bladet (`gpt-steg.png`)
Ett blad med **Avbryt** uppe till vänster och rubriken **Gör med ChatGPT**. En mening överst, och därefter tre
numrerade steg i en lista, var och ett med en knapp. Ett steg som är gjort får en grön bock.
- Steg 1: **Kopiera prompten** (fylld knapp). Prompten kommer från K58 och tar med provets frågor om de finns och en
  lista över vilka filer man ska bifoga. Efter tryck: bock, och knappen säger "Kopierad".
- Steg 2: **Öppna ChatGPT** (`.bordered`). Öppnar ChatGPT-appen om den finns, annars chatgpt.com i Safari.
- Steg 3: **Klistra in** som systemets `PasteButton`. Då frågar iOS inte om lov att läsa urklipp.

## Efter inklistringen
- **Känns igen** (`gpt-klart.png`): rad med bock, "Hittade {20} frågor med svar", de fyra första frågorna med kort svar,
  "och {16} frågor till", och **Spara frågorna** fast nederst. Ett tryck sparar och öppnar frågelistan, och ljudet
  görs som vanligt.
- **Känns inte igen** (`gpt-fel.png`): en ruta med förklaring och **Klistra in igen**. Inget rött.

## Texter (kopiera rakt in)
| Ställe | Text |
|---|---|
| Rad i Nytt prov | Gör med ChatGPT |
| Undertext | Låt ChatGPT göra frågorna av dina filer |
| Bladets rubrik | Gör med ChatGPT |
| Mening överst | ChatGPT gör frågor och svar av dina filer. Sedan läser Earmind upp dem. |
| Steg 1 | **Kopiera prompten** · Den säger åt ChatGPT exakt vad som ska göras. · knapp: Kopiera prompten · efter tryck: Kopierad |
| Steg 2 | **Klistra in i ChatGPT** · Bifoga dina filer, till exempel foton av sidorna eller en PDF, och skicka. · knapp: Öppna ChatGPT |
| Steg 3 | **Klistra in svaret här** · Kopiera hela svaret från ChatGPT. · knapp: Klistra in |
| Fotnot | Det du bifogar i ChatGPT hanteras av ChatGPT, inte av Earmind. ChatGPT är en tjänst från OpenAI. |
| Känns igen | **Hittade {n} frågor med svar** · Det korta svaret är första meningen i varje svar. |
| … efter fyra frågor | och {n − 4} frågor till |
| Knapp | Spara frågorna |
| Rad under knappen | Ljudet görs som vanligt när frågorna är sparade. |
| Känns inte igen | **Svaret har inte rätt form** · Kopiera hela svaret från ChatGPT, från första ”Fråga:” till sista svaret, och försök igen. · knapp: Klistra in igen |
| Fotnot vid fel | Du kan också klistra in texten under Skriv text i Nytt prov. |
| Tomt urklipp | Det finns ingen text att klistra in. Kopiera svaret i ChatGPT först. |
| Gränsen nådd (D155) | *(samma text som när frågorna är slut i Nytt prov)* |
| VoiceOver, steg med bock | Steg 1, klart. Kopiera prompten. |

## Att tänka på
- **Namnet ChatGPT** används för att beskriva en tjänst användaren själv använder. Det är okej i appen, men inte i
  appens namn, underrubrik eller nyckelord i App Store (samma regel som för AirPods, D122).
- **Integritet:** filerna går aldrig via Earmind i det här flödet. Det står i fotnoten och bör stå i Läs mer
  (`forsta-starten.md`): "Använder du Gör med ChatGPT skickar du filerna till ChatGPT själv."
- **Kvoten:** frågor som klistras in får ljud och räknas därför mot gränsen (D155). Det är **ej verifierat** mot K58.
  Kevin bekräftar.
- **Hjälpen** (`docs/HJALP.md`, Kevin): lägg till ett avsnitt "Gör med ChatGPT" med de tre stegen ovan.
