# A131 (D213): krediter per tecken i appen (Angela Fable, moln)

Klart 2026-11-17 15:03. **Verifierat i CI och på simulatorbild, inget på enhet.** Inget riktigt svar från den nya
servern (K90) har gått genom appen; avkodningen är testad mot Kevins beskrivning. 0 ElevenLabs (D180).

## Vad appen visar nu (Kellys ord, Ke71; talen från servern)
| Var | Text | Talet kommer från |
|---|---|---|
| Kapseln på Start | "1 236 krediter kvar" | `/drill quota`: `remaining` |
| Säg i AirPods, under fältet | "Kostar 764 krediter. Upprepningar kostar inget." / "Kostar inget. Ljudet finns redan." | provets `audio.cost` när servern har sett texten; medan man skriver, se avvikelsen nedan |
| Räcker inte (halvfet, Spela grå) | "Det här kostar 764 krediter. Du har 312 kvar. Nya krediter den 1 december." | `cost`, `remaining`, `resets_day` (eller dagen ur `resets`) |
| Provkortet på Start och provets skärm | "Kostar 2 340 krediter" | `audio.cost` (annars `cost`) i svaret på save, start, get och status |
| Text i Nytt prov, före sparning | samma rader som i Säg | `/exam read`: `cost` |
| Nekat av servern (402) | serverns `error.message` som den är | servern |
| Bladet "Krediter" | stort tal, "krediter kvar den här månaden", "Så räknas det" (4 rader), fotnoten med månadens gräns | `remaining`, `limit`, `resets_day` |

- En server som fortfarande räknar frågor (inget `unit: "chars"`) ger de gamla texterna.
- Ett **nytt** Säg-prov som servern nekar redan vid sparningen (inget sparas där) behålls inte på telefonen heller:
  inget kort på Start. Texten står kvar i fältet med raden om varför.
- Prislistan i kvotsvaret har bytt form; går den inte att läsa hoppas den över utan att kapseln försvinner.
- Byggt ovanpå A130 (nekat Spela är aldrig tyst; samma text blir inte ett nytt prov per tryck).

## Varför servern sa 402 i går (Kevin, K89)
Servern räknade på texten som rösten läser, där årtal skrivs ut som ord: 948 tecken = 2 frågor. Appen räknade de
764 visade tecknen = 1 fråga. Med krediterna räknar servern visade tecken, så de räknar lika.

## Avvikelse från "inga egna uträkningar"
Medan man skriver i Säg-fältet finns inget anrop till servern. Raden visar då antalet tecken, räknat med serverns
regel (rad för rad, flera blanktecken i rad blir ett, raden trimmas, radbrytningar räknas inte). Talet kan bara bli
för högt, aldrig för lågt: en del som redan har ljud kostar 0 hos servern (Arons text: 764 i appen, 744 hos servern).
Efter Spela gäller serverns tal. **Deangelo/Kevin:** vill ni ha exakt tal redan före Spela behövs ett anrop som
svarar med kostnaden utan att spara.

## Inte gjort i krediter
- Förslaget "Antal frågor" och frågeprovets rad i Nytt prov före sparning (kostnaden för ett frågeprov finns först
  när servern har sparat det; kortet visar den sedan).
- Kreditbladets fotnot klipps på sista raden i halv höjd på 17 Pro. Rättat i nästa push (bladet 72 % högt).

## Tester
- **iOS build 44095501624 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- **A130 på main: iOS build 44092861200 grön.**
- Nya tester i `LumenTests/A122LockedPhoneTests.swift`: månaden i krediter läses ur serverns svar (och dagen ur
  datumet när `resets_day` saknas; en oläslig prislista tar inte talet med sig; en äldre server ger frågor); Kellys
  ord med serverns tal; provet behåller serverns kostnad; ett nytt prov som krediterna inte räcker till lämnar inget
  kvar och säger serverns rad; tecknen räknas som servern räknar dem.
- **Bilder** i `reports/2026-11-17-a131-bilder/` (gren `fable/screens-a131-17pro-2`): Start med "1 236 krediter
  kvar" och "Kostar 120 krediter. Upprepningar kostar inget."; "Det här kostar 120 krediter. Du har 88 kvar. Nya
  krediter den 1 december." med grå Spela; bladet "Krediter". SE med största text: körningen var inte klar när detta
  skrevs.

## Otestat (antaganden)
- Fältnamnen är Kevins från meddelandet 14:38 (`unit`, `remaining`, `resets_day`, `cost`, `audio.cost`,
  `refunded_credits`); inget riktigt svar har avkodats av appen.
- Provkortets rad "Kostar N krediter" finns inte på bild.
- Inget på enhet.

## Prova på telefonen (Aron, med nästa app)
1. Kapseln uppe till vänster ska säga "N krediter kvar". Tryck på den: bladet "Krediter".
2. Skriv en text i Säg i AirPods: under fältet "Kostar N krediter. Upprepningar kostar inget." Tryck Spela: det ska
   höras, och kapseln ska ha minskat med ungefär textens tecken när spelaren stängs.
3. Tryck Spela på samma text igen: "Kostar inget. Ljudet finns redan.", och kapseln ändras inte.
4. Skriv en text som är längre än krediterna du har kvar: raden ska säga vad den kostar och vad du har, och Spela är grå.

## Nästa session
- SE-bilderna, Kellys granskning (Ke71), Tobys T44, Oscars O76.
- Svar på frågan om exakt tal före Spela.
