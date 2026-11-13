# Hjälp-AI:n: utseende, texter och ton (Kelly, Ke57, D166, 2026-11-13)

Till Angela Fable (A92, vyn) och Kevin (K57, svaren). Bilder: `bilder/apple/hjalp-*.png`, ljust och mörkt (källa
`_src/apple.html`). Reglerna i `SYSTEM.md` §0 gäller. **Det här är skisser. Inget är byggt.**

## Utseende
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Tom | `hjalp-tom.png` | Ett blad med rubriken **Fråga om Earmind** och **Klar** uppe till höger. En mening överst ("Fråga hur något i Earmind fungerar. Svaren handlar bara om appen."). FÖRSLAG: tre rader i accentfärgen, där ett tryck skickar frågan. PROVA: raden **Prova på en kort text** med symbol och undertext. Inmatningsfältet nederst. |
| Ett svar | `hjalp-svar.png` | Bubblor som i Meddelanden: din fråga till höger (accentfärg) och svaret till vänster (`fill`). Steg som en numrerad lista. En plats i appen som en tryckbar länk i bubblan ("Öppna Styr med dina AirPods"). |
| Utanför appen | `hjalp-annat.png` | Samma korta svar varje gång (D166), följt av ett exempel på vad den kan. |
| Prova på en kort text | `hjalp-prova.png` | `Form`: en textruta, en rad om kvoten, och därefter de tre frågorna med kort svar som rader. **Spara som prov** fast nederst och **Gör om** som textknapp. |

**Inget av det här:** maskot, avatar, glittrande "AI"-symbol, gradient, skrivanimation med tre prickar som studsar
länge (en enkel `ProgressView` räcker), kort runt bubblorna, emoji, tumme upp/ned efter varje svar. Svaret kommer i
sin helhet, så att VoiceOver läser en sak åt gången.

**Var den öppnas (A92):** raden **Fråga om Earmind** under Inställningar, och en `questionmark.circle` i
verktygsraden i Nytt prov och på kontrollskärmen. Från kontrollskärmen och Nytt prov öppnas den med en färdig fråga
som förslag överst ("Hur fungerar trycken?" eller "Vad kan jag fota?").

## Texter (kopiera rakt in)
| Ställe | Text |
|---|---|
| Rubrik | Fråga om Earmind |
| Knapp | Klar |
| Rad i tomt läge | Fråga hur något i Earmind fungerar. Svaren handlar bara om appen. |
| Sektioner | FÖRSLAG · PROVA |
| Förslag | Hur fungerar trycken? · Hur delar jag ett prov? · Varför blev det färre frågor? |
| Prova-raden | **Prova på en kort text** · Earmind gör 3 frågor med svar. Räknas mot dina frågor. |
| Inmatningsfält | Fråga om Earmind |
| Medan svaret kommer | *(`ProgressView` i en grå bubbla, ingen text)* |
| Fel | Det gick inte att svara just nu. Försök igen. |
| Inget nät | Ingen internetanslutning. |
| Prova: fotnot | Klistra in eller skriv några meningar. Räknas som 3 av dina frågor. |
| Prova: knapp innan | Gör frågor |
| Prova: knappar efter | Spara som prov · Gör om |
| Prova: kvoten slut | Du har inga frågor kvar den här månaden. *(texten för D155/D165-gränsen följer Kevins kontrakt)* |
| Inställningar, rad | Fråga om Earmind |
| VoiceOver på ?-knappen | Fråga om Earmind |

## Ton i svaren (till Kevin, K57, och `docs/HJALP.md`)
1. **Du-form, korta meningar, inget krångel.** Högst 4 meningar eller 5 numrerade steg. Börja med svaret, inte med
   "Bra fråga" eller "Självklart".
2. **Samma ord som i appen**, och knapparna skrivs exakt som de står: Nytt prov, Fota sidor, Skapa frågor, Ser rätt ut,
   Starta prov, Avsluta, Fler lägen, Dela, Publicera prov. Aldrig "övningsprov" (D149), "A+-svar", "drill", "TTS",
   modell- eller leverantörsnamn.
3. **Trycken förklaras alltid med Arons text (A90), ordagrant:** "Medan frågan spelas: tryck 1 gång för frågans
   A-svar. Tryck 2 gånger för ett kort A-svar på en till två meningar. Tryck 3 gånger för att pausa. Tryck igen för att
   fortsätta."
4. **Utanför appen, exakt:** "Det kan jag inte svara på." och en mening om vad den kan ("Jag svarar bara på hur Earmind
   fungerar, till exempel hur du gör ett nytt prov."). Inga ursäkter och inget "Som en AI …".
5. **Lova bara det som finns.** Det som är "Kommer snart" i `Shared/capabilities.json` heter "kommer snart". Lägen i
   beta sägs vara i beta. Inga sekunder, och inget om ljud som aldrig lämnar telefonen.
6. **Pekar svaret på en plats i appen,** avsluta med en länk dit (A92 visar den som en tryckbar rad i bubblan).
7. **Vet den inte:** "Det vet jag inte. Skriv till oss under Inställningar › Om Earmind." Den gissar aldrig.
8. **Barn och tonåringar använder appen:** en vänlig, saklig ton och ingen slang. Den frågar aldrig om personuppgifter.

## Granskning av `docs/HJALP.md`
Filen finns inte på main (2026-11-13 23:50). Jag granskar språket och tonen mot reglerna ovan när Kevin pushar den
(K57).
