# Granskning av A18 mot SYSTEM.md (Kelly, Ke17, PLAN 2c), del 1: koden

**Läge: inte godkänd än.** A18 byggdes på Ke9/Ke10 (`enkel-start.md`), innan `docs/design/SYSTEM.md` fanns (Ke12). Det
mesta i Ke9 är byggt: en blå knapp per skärm, Elias i introt, Lumen hör dig inte och Kommandon-bladet. Det som
återstår är systemets nya delar. Del 2, skärmbilderna i ljust, mörkt och SE, kommer när Angelas bilder finns i `reports/`.

Underlag: `git grep` på `origin/main` 2026-11-10 ca 08:10 (**kod**). Angelas oincheckade ändringar i samma mapp är inte
granskade.

## Rättelser till Angela (i GRANSKNING.md-ordning)
| # | Vad | Var (origin/main) | Ska bli (SYSTEM.md) |
|---|---|---|---|
| 1 | Röd handstilsring "5 dagar kvar" | `HomeView.swift:62`, `:66` (`RedPenRing`) | Bricka: `soft`-yta, blå text, helt rund (§3). |
| 2 | Rutpapper på kort | `HomeView.swift:100`, `:173`, `FirstStartView.swift:228` (`.gridPaper()`) | Kort: `raised`, hörn 20, mjuk skugga, inget rutnät (§2–3). |
| 3 | Handstil på som standard | `Theme.swift:80` (`handwriting … ?? true`), `questionFont` i Lyssnar, Första frågan, Lägg till prov och Start | Ingen handstil: frågan i 15 semibold `muted`. Inställningen kan tas bort. |
| 4 | Frågan i blått | `ListeningScreen.swift:150`, `FirstStartView.swift:217`, `:222` | `muted`. Blått är bara för handlingar. |
| 5 | Rött i lyssnarraden när den är aktiv | `ListeningIndicatorBar.swift:40`, `:57` | Blå/bläck. Rött bara vid fel (§2). |
| 6 | "1.00×" i Inställningar | `SettingsView.swift:418` (`"%.2f×"`) | Talhastighet Lugn / Normal / Snabb på Röst-sidan (`bilder/system/rost.png`). |

## Godkänt i koden
- **"Avsluta" behålls** (Angelas skäl: rösternas ord, och "klar" betyder redan något i D72). SYSTEM.md och skissen är
  ändrade efter det: Avsluta är en neutral sekundär knapp.
- "Inget prov just nu" som brytare är borta. Den heter nu "Jag har ett prov" (`SettingsView.swift:171`).
- ErrorCard använder rött, vilket är rätt eftersom det är ett fel.

## Kvar till del 2 (bilder)
Punkterna 1, 7, 8 och 9 i `GRANSKNING.md` (huvudknapp, mörkt läge, iPhone SE och skydden) kräver skärmbilder.
