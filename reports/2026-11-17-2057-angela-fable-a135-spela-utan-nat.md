# A135 (D219): Spela ska inte vänta på nätet när ljudet finns (Angela Fable, moln)

Klart 2026-11-17 20:57. **Verifierat i CI (enhetstester med en server som inte går att nå), inget på enhet och inget
med riktigt dåligt nät.** 0 ElevenLabs (D180).

## Vad Aron såg 20:24
Texten "Hej" i Säg i AirPods, snurran på "Spela i 10 min" i över en minut, på 5G utan wifi.
Skärmbild: `reports/apptest/aron-2026-11-17-2024-spela-laddar-5g.png`.

## Vad som hände (Kevins tidslinje ur serverloggen, appbygget 44151043267)
- 19:23:27–28 UTC: appen öppnas och gör sina vanliga anrop, alla svarar inom 2,6 s.
- **19:23:28 → 19:25:33: inget enda anrop från telefonen når servern, i över två minuter.**
- 19:25:33–40: sparning (1,8 s), start (1,2 s), ljudfilen hämtad. Cirka 7,5 s från första anropet till nedladdat ljud.
Servern var alltså inte långsam, och inget anrop misslyckades. Trycket på Spela nådde inte servern förrän 19:25:33.
**Inte belagt** om det var telefonens nät eller något i appen före sparningen; det finns ingen logg från telefonen.
I skärmbilden ligger "Hej" redan under Senaste och kostnaden är "3 krediter", så en äldre, ostartad "Hej" fanns på
telefonen: Spela behövde servern, och appen hade inget tak för hur länge den väntade.

## Vad som är byggt (D219 punkt för punkt)
1. **Ljud som finns på telefonen spelas därifrån.** Det gällde redan startade prov och texter. Nytt: en ny text vars
   rader redan har ljud i en annan text på telefonen (samma röst) får de filerna direkt
   (`RepetitionModel.withSoundAlreadyHere`).
2. **Spela väntar inte på nätet när ljudet finns.** Ett prov eller en text som inte är startad på servern men har allt
   sitt ljud på telefonen spelas direkt; servern får sparningen och starten i bakgrunden (den har ljudet, så inget
   räknas).
3. **Snurran högst 10 sekunder.** Sedan står "Ljudet kunde inte hämtas. Kontrollera nätet och försök igen." under
   fältet och knappen heter "Försök igen". Ljudet fortsätter att göras och hämtas i bakgrunden, men inget börjar
   spela av sig självt senare.
4. **Senaste visar varje text en gång** (`recentSaid`). Arons två "HISTORIA"-kapslar blir en.
5. **Tak för ljudet på telefonen: 500 MB.** Över det tas filerna som hämtades för längst sedan bort, aldrig det som
   spelas. Det som tas bort finns kvar på servern och hämtas igen när det behövs. Körs när Start läses om.
- **Tider i appens logg:** hur länge servern tog på sig vid Starta/Spela, och när ljudet spelades från telefonen.

## Avvikelser
- Punkt 5 säger "äldsta ospelade först". Appen för ingen bok över vad som har spelats, så ordningen är efter när
  filen hämtades.
- Orden "Ljudet kunde inte hämtas. Kontrollera nätet och försök igen." och "Försök igen" är mina; Kelly har inte
  sett dem.

## Tester
- **iOS build 44160372719 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- Nya tester i `LumenTests/A122LockedPhoneTests.swift`: en text vars ljud finns på telefonen spelas direkt mot en
  server som inte går att nå (inget sparas eller startas där); bara raden som finns får ljudet; Senaste visar varje
  text en gång; taket tar de äldsta filerna först och aldrig det som spelas; tålamodet är 10 s.

## Otestat (antaganden)
- Riktigt dåligt nät (ett anrop som hänger): testet låter servern svara "ingen kontakt" direkt, inte hänga.
- Att 10-sekundersraden visas och att inget börjar spela efteråt är inte sett på bild eller enhet.
- Inget på enhet.

## Prova på telefonen (Aron, med nästa app)
1. Spela en text. Slå sedan på flygplansläge och tryck Spela på samma text (eller välj den under Senaste): den ska
   höras direkt.
2. Skriv en ny text i flygplansläge och tryck Spela: efter 10 sekunder ska raden om nätet stå där och knappen heta
   "Försök igen". Slå av flygplansläget och tryck: den ska spelas.
3. Under Senaste ska varje text stå en gång.

## Nästa session
- Arons svar. Händer det igen med 10-sekundersgränsen på plats, behövs loggen från telefonen (Inställningar,
  Diagnostik) för att se vilket anrop som hängde.
