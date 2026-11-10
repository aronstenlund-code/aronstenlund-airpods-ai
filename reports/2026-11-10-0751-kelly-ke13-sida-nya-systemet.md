# Ke13b (stående uppgift): demosidan i det nya systemet (Kelly, 2026-11-10)

Kort: demosidan följer nu `docs/design/SYSTEM.md`, precis som appen ska göra efter A18.
- Ingen handstil och inget rutpapper.
- Kort med mjuk skugga och en accentfärg.
- Sekundära knappar på `surface`.

Kalam-typsnittet är borttaget, och `site/` gick från 1 731 till 1 699 kB. **Ej provat i Safari eller på iPhone.**

## Vad som ändrats (`site/index.html`)
- **Färger:** tokens enligt SYSTEM.md, med `surface`, `raised`, `soft` och `shadow`. Mörk bakgrund #0F1218, bläck #141A2E.
  `--paper`, `--grid` och `--sq` är borta.
- **Kort i stället för rutpapper:** `.paper` gäller demon, stegen, väntelistan och exemplen. Varje kort har hörn 20, en
  tunn kant och en mjuk skugga (i mörkt läge ingen kant och ingen skugga). Elias-kortet har inte längre rutpapper runt sig,
  och hörnen är 24.
- **Ingen handstil:**
  - Frågor, exempelfrågor och exemplet i steg 2 står i Familjen Grotesk halvfet.
  - När svaret visas står frågan liten och grå ovanför (15 px), och svaret bär kortet.
  - Kalam (fil, licens, preload och reservtypsnitt) är borttaget.
- **Knappar:** hörn 14. "Stoppa", "Ställ en ny fråga" och exemplens Lyssna/Stoppa är sekundära (`surface`, ingen kant).
- **Chips:** helt runda, `surface`, bläck-text.
- **Oförändrat:** loggan (radiovågorna) tills Aron valt A, B eller C, samtyckes- och integritetstexterna, och all JS-logik.

## Mätt (lokalt i Chrome)
| | Före | Efter |
|---|---|---|
| `site/` | 1 731 kB | 1 699 kB |
| Överföring vid laddning | 576 KiB | 554 KiB |
| Lighthouse mobil | 100/100/100/100 | 98/100/96/100, CLS 0 |
| Lighthouse dator | 100/100/100/100 | 100/100/96/100 |
| Överflöd i sidled vid 390 px | ingen | ingen |

**Best Practices 96** beror inte på ändringen. Felet är ett konsolfel från `auth/v1/signup` med svaret 429: sidan loggar
in anonymt när den laddas, och mina många Lighthouse-körningar slog i spärren för nya anonyma konton per nätverk. Jag
slutade köra Lighthouse för att inte skapa fler anonyma konton. Mobilens Performance 98 ligger inom mätbruset.

Svarsvyn är provad med text som lagts in med JS, inte med ett riktigt anrop. Frågan har typsnittet Familjen Grotesk,
konsolen visar inga JS-fel och sidan har inget överflöd.

## Bilder (`reports/2026-11-10-ke13-sida/`)
- `jamforelse-mobil-light.png`, `jamforelse-mobil-dark.png`: före och efter, de första 1 700 px.
- `efter-mobil-*` och `efter-dator-*`: helsidor.
- `efter-svar-light.png`, `efter-svar-dark.png`: svarsvyn.

## Kvar
- Skärmbilderna i de tre stegen visar fortfarande appens gamla stil (rutpapper och handstil) tills A18 är byggd och Toby
  tar nya.
- Loggan byts när Aron valt.
- Delningsbilden `og-elias.png` har fortfarande rutpapper. Den görs om tillsammans med loggan.

## Till Aron
Välj logga A, B eller C (`docs/design/bilder/system/logo.png`). Den byts då på sidan, i delningsbilden och i appen.

## Concerns
- Sidan skapar en anonym inloggning för varje **ny** besökare redan när sidan laddas (`getToken()` vid uppstart, rad
  ~1427), även om besökaren aldrig frågar. Token sparas i webbläsaren, så samma besökare skapar inte fler. Detta är
  **verifierat i koden**.
- Risk: många nya besökare från samma nätverk (en skolklass) kan slå i spärren för anonyma inloggningar per IP. Då får
  resten 429 när de frågar. Det är **ej verifierat** vilken gräns projektet har i Supabase.
- Alternativ: logga in först vid första frågan. Det kostar en rundresa till på första svaret, och svarstiden är Arons
  prioritet. Därför har jag inte ändrat något. Till Kevin och Deangelo.
