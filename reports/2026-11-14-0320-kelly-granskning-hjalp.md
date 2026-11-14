# Kelly: granskning av docs/HJALP.md (Ke57, K57)

Datum: 2026-11-14 03:20. Underlag: `docs/design/hjalp.md` (tonreglerna), appens knappar på main (A87, A83, A92) och
`Shared/capabilities.json`. Filen är Kevins. Jag har inte ändrat den.

## Bedömning
**Godkänd med fem små rättelser.** Tonen följer reglerna: du-form, korta meningar, steg som en lista, inga leverantörs-
eller modellnamn, aldrig "övningsprov", och "Det kan jag inte …" hör till K57:s prompt. Arons trycktext (A90) står
ordagrant. Det som sägs om lägena stämmer med `capabilities.json` (allt "finns" utom Spotify-styrning, som står som
"kommer snart"). Gränsen (15 frågor per månad, D155), rösten (D151), tempot (D152), delningen och publiceringen stämmer
med besluten.

## Rättelser (knapparnas namn ska vara exakt som i appen)
| # | Står i HJALP.md | Ska stå | Varför |
|---|---|---|---|
| H-1 | "**Dokument**: PDF, Word eller text." | "**Lägg till dokument**: PDF, Word eller text." | Raden heter så i Nytt prov (A87). |
| H-2 | "Tryck **Dela** på provet" | "Tryck på **Dela** (symbolen med pilen uppåt) uppe till höger i provet" | Dela syns bara som en symbol i verktygsraden (A87). Ordet hörs bara i VoiceOver. |
| H-3 | "rapporterar du det med **Rapportera provet**" | "trycker du **Rapportera** längst ner i provet" | Knappen heter Rapportera, och bladet heter Rapportera provet (A83). |
| H-4 | "**Förhör med rösten:** Earmind förhör dig …" | "**Provläge (förhör med rösten):** Earmind förhör dig …" | I Välj läge heter raden Provläge, och "Förhör med rösten" är undertexten. |
| H-5 | "Ditt användarnamn visas bara om du själv fyller i det." | "Ditt användarnamn visas bara om du slår på **Visa ett användarnamn**. Skriv inte ditt riktiga namn." | Brytaren heter så (A83, D150), och raden om riktiga namn finns i appen. |

## Att kontrollera på telefon (ingen ändring nu)
- Vägen "Inställningar › Bluetooth › ⓘ vid dina AirPods" för AirPods med dubbeltryck per lur är **ej verifierad i
  iOS 26** (samma punkt som i Ke49 och Ke50).
- "Den första frågan går att spela efter några sekunder": sant enligt R1 i specen, men inte mätt på telefon.

## Till Kevin
H-1 till H-5 i `docs/HJALP.md` och kopian i `_shared/hjalp.ts` (testet stoppar annars driftsättningen).
