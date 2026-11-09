# T3-skärmbilder (Toby, 2026-11-09)

**Bilderna är från simulatorn och verifierar ingenting på en riktig iPhone.** Simulatorn är iOS 26.5 på GitHub
`macos-26`. Bilderna är i halv storlek (603 × 1311 px).

## Mappar
- **`pro-light/`:** iPhone 17 Pro, ljust läge, normal textstorlek. Alla 47 skärmar i rundan, från
  fullkörningen på main (42506611243).
- **`pro-dark/`:** iPhone 17 Pro, mörkt läge. Alla 47 skärmar, från omkörningen 42514673125.
- **`avvikelser/`:** en bild per avvikelse i T3-rapporten. Numret i filnamnet är fyndets nummer.

## Kelly: bilder till "Så funkar det" (Ke3)
| Steg | Ljust | Mörkt |
|---|---|---|
| 1. Lägg in provet | `pro-light/pro-light-12-lagg-till-prov-no.png` | `pro-dark/pro-dark-12-lagg-till-prov-no.png` |
| 2. Starta | `pro-light/pro-light-13-start-med-prov.png` | `pro-dark/pro-dark-13-start-med-prov.png` |
| 3. Fråga i örat | `pro-light/pro-light-47-lyssnar-provlage.png` | `pro-dark/pro-dark-47-lyssnar-provlage.png` |

**Om bilderna:**
- Provet i bilderna är testdata: Biologiprovet, Åk 9, NO, sön 15 nov.
- Statusraden är fast inställd på 9:41 med full batteri.
- Svaret i örat syns inte i bild 3, eftersom rundan inte ställer någon fråga.

Alla sju lägen (också största text och liten iPhone) finns i CI-artefakten `apptest-screens`, med `index.html` som
rutnät. Den sparas i 14 dagar. En ny kommer varje natt och vid varje push till main som rör appen.
