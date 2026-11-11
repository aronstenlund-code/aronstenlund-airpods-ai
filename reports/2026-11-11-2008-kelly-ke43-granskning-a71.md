# Kelly Ke43: granskning av A71, exakt appikon och röstning med sex (2026-11-11 20:08)

Underlag: CI "Simulator screenshots" 43079705733 på main e35e472 (A71 steg 2), iPhone 17 Pro, ljust och mörkt, och
filerna i appen. Mot `docs/design/logo/rostning/exakt/README.md` (Ke40, D139). Bilder:
`reports/2026-11-11-a71-granskning/` (v: röstningen, tack, Start; w: intro, Första frågan, Om appen).

## Omdöme: **godkänd**
| Kontroll | Resultat |
|---|---|
| AppIcon | `AppIcon.appiconset/AppIcon-1024.png` är **identisk** med `exakt/AppIcon-1024.png` (medelavvikelse 0,0). Den tillfälliga uppskalningen med svart kant är borta |
| Röstningens bilder | `LogoVoteA–F.png` (300 px) är de exakta A–F nedskalade (avvikelse 0,2–0,4) |
| Röstningen på bild | 2 × 3, 96 pt, iOS-maskens hörn, namn under varje, ordningen slumpad (E, B, D, A, F, C här), "Rösta" grå tills man valt, "Senare" |
| Tackskärmen | Sex rader med ikon, namn, procent och stapel |
| Märket i rubriken | `AppMark` (192 px av den exakta ikonen) på Start bredvid "Earmind" och i introt; följer textstorleken (Ke37 §10.6) |
| A73 (extra) | "Ljudet blir text och sparas inte av Earmind. Sömnläget sparar klippen bara på din telefon." syns i introt, på Första frågan och i Om appen |

## Inget nytt fynd
Kvar sedan tidigare: L1 (licensraden om ElevenLabs, Ke41) och Elias vita hörlur i introt (Ke28 F1).
Själva hemskärmsikonen syns inte i simulatorbilderna; den är kontrollerad som fil. **Ej verifierat på enhet.**
Kostnad: API 0 USD, ElevenLabs 0 tecken.
