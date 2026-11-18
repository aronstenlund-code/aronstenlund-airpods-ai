# Tobys T50: "Kolla nätet" när nätet var uppe, och Försök igen som inte spelade (Angela Fable, moln)

Klart 2026-11-18 07:35. **Verifierat i CI: iOS build 44250491637 grön på min gren (enhetsbygge, varningar som fel,
LumenTests). Inte provat i Simulatorn mot servern och inte på enhet.** 0 ElevenLabs.

## Vad Toby såg
I tre av fyra körningar sedan A135 kom "Ljudet kunde inte hämtas. Kolla nätet." med nätet uppe, och efter Försök
igen "Det gick inte att spela just nu. Försök igen om en stund." Första Spela på ett nytt konto startade ljudet
först efter cirka två minuter och tre tryck (`reports/apptest/2026-11-18-0625-toby-moln-t50-stil-takt.md`).

## Orsak och rättning
1. **Fel i appen:** ett andra tryck på Spela gick vidare medan det första tryckets sparning ännu inte hade svarat.
   Texten har inga meningar att läsa förrän servern svarat, så inget spelade och raden "Det gick inte att spela
   just nu" visades. Nu väntar det andra trycket på det första tryckets svar och spelar när det kommit
   (`CloudDrillAudio.startAudio`). Texten sparas och startas fortfarande bara en gång.
2. **Fel ord:** efter 10 sekunder utan svar skyllde raden på nätet. Med nätet uppe står det nu "Det tar längre tid
   än vanligt. Försök igen om en stund." (mina ord, skickade till Kelly). "Ljudet kunde inte hämtas. Kolla nätet."
   visas bara utan nät.

## Inte löst
**Varför servern ibland tar över 10 sekunder på sig är inte fastställt.** Jag har frågat Kevin (kallstart, eller
taggarna som läggs vid sparning med stil). Det här kan vara samma sak som Arons fynd 20:24 i går. Tills det är
utrett kan första Spela på en ny text fortfarande ge raden efter 10 sekunder; skillnaden är att Försök igen nu
spelar när servern har svarat.

## Tester
`LumenTests/A136StyleVoicePaceTests.swift`: med en sparning som tar tid väntar det andra trycket på svaret, provet
sparas och startas en gång; orden för långsam server och för inget nät.

## Nästa
Toby kör om T36 när detta är på main. Kelly granskar orden. Kevins svar avgör om 10 sekunder ska ändras (D219.3 är
Deangelos beslut).
