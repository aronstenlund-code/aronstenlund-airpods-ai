# A71 steg 2 – Kellys exakta ikoner (Ke40, D139) och sex val i röstningen

Angela, 2026-11-11. Underlag: `reports/2026-11-11-1859-kelly-ke40-exakta-ikoner.md` och
`docs/design/logo/rostning/exakt/README.md`.

## Vad som är gjort
- **AppIcon** är Kellys `exakt/AppIcon-1024.png`, alltså D glasklotet, beskuret för iOS-masken och utan
  genomskinlighet. Det ersätter steg 1:s uppskalade original.
- **Rubriken på Start och introt** visar appikonen i liten storlek med iOS-maskens hörn (`AppMark`), i stället för de
  gamla radiovågorna. Det är Kellys förslag. På Start följer den textstorleken.
- **Röstningen** har sex val, A–F, i ett rutnät med tre per rad och två per rad vid de största textstorlekarna.
  - Bilderna är Kellys exakta filer, nedskalade till 300 px.
  - Namnen är Klotet, Den gröna formen, Den orange ringen, Glasklotet, Glasringen och Glasvågen.
  - Ordningen slumpas om för den som hade de tre gamla. K41 tar emot A–F.
- Skärmbildsscenerna `logoVote` och `logoVoteDone` visar sex val. Siffrorna är påhittade.

## Testresultat
- **Enhetstester:** `A54Tests` är uppdaterat för sex namn och en ordning med sex.
- **iOS-bygge och enhetstester:** CI 43079695710 (e35e472) är **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Ej verifierat på enhet.** Kelly granskar bilderna.

## Till Aron
- Ikonen är glasklotet, exakt som ChatGPT gjorde den, men uppskalad och därför något mjuk i stor storlek (Kelly). Mörk
  och tonad variant tar iOS fram själv.
