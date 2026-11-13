# Repetitionsläget: design (Kelly, Ke49, D142–D146, 2026-11-13)

Underlag till Angela för A79 (material och frågelista), A80 (Starta prov, kontrollskärm och BETA) och A81 (Dela och
kontroller för alla AirPods). Specen och tekniken står i `repetitionslage.md` (Deangelo). Den här filen säger bara hur
det ska se ut och låta. Det som inte står här följer `SYSTEM.md`.

Alla texter: `repetition-texter.md` (Ke50). Skisser: `bilder/repetition/<id>.png`, ljust till vänster och mörkt till höger. Källan är `_src/repetition.html`, som
renderas med `node docs/design/_src/repetition-render.js` (en skärm: lägg till id:t som argument). **Det här är
skisser. Inget är byggt och inget är provat på telefon.** Exempelprovet (biologi åk 9) är påhittat och innehåller
ingen elevtext.

## 1. Vad gör de andra pluggapparna bra?
Jämförelsen bygger på vad jag vet om apparna. Den är **ej verifierad mot dagens versioner i App Store**, och inga bilder
därifrån ligger i repot.

| App | Det som fungerar | Vi tar |
|---|---|---|
| Quizlet | Man skapar ett set med några få tryck: titel, sedan termer i en lista. Ljudet i Lär-läget är fråga, paus och svar. Kortsidan är stor och lugn. | Frågelistan som en vanlig lista med fråga och kort svar. Uppspelningen visar en fråga åt gången, stort. |
| Anki | Repetition utan pynt. Varje kort har en tydlig fråga och svaret kommer först när man vill. Inställningar finns, men långt ner. | Svaret spelas bara när man trycker. Betänketid och svarslängd har bra standardvärden och ligger inte i vägen. |
| StudySmarter | "Ladda upp material, få kort" är huvudvägen. Under väntan visas steg och inte bara en snurra. Användaren godkänner och rättar de genererade korten. | Material som rutnät med fyra källor. Väntan med steg. Sammanfattningen och frågorna går att rätta innan något spelas. |
| Poddappar (Apple Podcasts, Pocket Casts) | Låsskärmen och lurarna styr allt. Paus fortsätter från samma ställe. Pocket Casts låter användaren ändra vad AirPods-trycken gör. | Now Playing med frågan som titel. Trycken förklaras en gång före start och sedan bara som en tyst rad. |

Gemensamt för de bästa: **en sak per skärm, och man förstår vad nästa tryck gör.** Repetitionsläget används mest med
telefonen i fickan, så skärmen ska gå att läsa på en sekund när man väl tittar.

## 2. Flödet
Hem → **Nytt prov** (material) → *läser materialet* → **Stämmer det här?** (sammanfattning) → **Frågelistan** →
**Starta prov** → **Styr med dina AirPods** (första gången, och när andra lurar kopplas in) → **uppspelning**.
Nästa gång: Hem → **Starta prov** direkt, det vill säga ett enda tryck.

## 3. Skärmarna
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Hem med prov | `hem.png` | Provkortet överst med **Starta prov** som den enda blå knappen (stor, 72 pt). Under den "Frågor och svar" och "Dela" som textknappar. "Nytt prov" är en sekundär knapp. Andra prov ligger i en lista med ▶. Ett prov vars ljud inte är klart har ett blekt ▶ och raden "Ljud: 31 av 60 klara". **Fler lägen** med BETA-märket ligger längst ner. Ingen mikrofon och inget "Starta Earmind" på hemskärmen. |
| Hem utan prov | `hem-tom.png` | Ett kort med rubriken "Plugga med AirPods", en mening och den blå knappen **Nytt prov**. Inget annat. |
| Nytt prov: material | `material.png` | Namnfältet överst. Lämnas det tomt, får provet sitt namn från sammanfattningen ("Biologiprovet"). Fyra rutor: **Fota sidor** (kameran stannar öppen för flera foton i följd), **Välj bilder** (PhotosPicker, flera), **Skriv text**, **Dokument** (PDF, Word, text). Det som är tillagt visas som miniatyrer med ×. **Antal frågor** visar värdet med − + (standard 20). **Långa svar** har tre steg: Kortare, Normal (cirka 90 ord) och Längre (D146). Fotnoten säger att foton och dokument inte sparas. Den blå knappen **Skapa frågor** är grå tills något är tillagt. |
| Läser materialet | `analys.png` | Fyra steg med bockar i stället för en snurra utan slut: Läser sidorna, Tar reda på ämne och årskurs, Gör frågor, Skriver svar. "Du kan lämna appen. Earmind säger till när det är klart." betyder en notis, men bara om användaren redan har tillåtit notiser. Fråga inte om det här. |
| Stämmer det här? | `sammanfattning.png` | Ett kort med Ämne, Årskurs och "Provet handlar om" som chips. Fältet "Något fel? Skriv det" tar en rad fri text. Den blå knappen **Ser rätt ut**. En rättelse gör om sammanfattningen och frågorna. |
| Frågelistan | `fragor.png` | Stor rubrik med provets namn. Under den "20 frågor · åk 9 · Sammanfattning" (länk). Raderna har nummer, frågan i 17 semibold och det korta svaret grått på en rad. Nederst finns ljudets förlopp, "Ljud: 36 av 40 klara · Görs i spelordning", som en tunn stapel, och **Starta prov**. Starta prov går att trycka direkt, eftersom ljudet görs i spelordning (R1: första ljudet inom 20 s). Saknas ljudet för nästa fråga när det är dags, väntar spelaren tyst på det och visar "Gör ljud …" i stället för betänketidsringen. |
| Frågelistan: Ändra | `fragor-andra.png` | Vanlig iOS-redigering: röd − för att ta bort, handtag för att flytta och **Lägg till fråga** sist. "Klar" uppe till höger. Raden "Ordningen är den du hör" förklarar varför ordningen spelar roll (D143: samma ordning varje varv). |
| Redigera en fråga | `redigera.png` | **Två fält, inte tre.** Fråga (räknar ord, varnar i grått över 5 ord, aldrig i rött) och Svar. Det korta svaret är **den markerade första meningen** i svaret (D145). Bakgrunden `soft` följer meningen medan man skriver, så att det korta och det långa svaret aldrig kan säga emot varandra. "Lyssna" spelar nuvarande ljud. "Nytt förslag" ber Earmind skriva om just den här frågan. Rutan nederst säger att bara den här frågan får nytt ljud. Spara uppe till höger. |
| Styr med dina AirPods | `kontroller.png` | Testet visar **en sak i taget**: en stor puls med prickarna för trycket som ska göras, "Tryck två gånger nu" och en rad under om hur ("på skaftet, som när du byter låt"). Listan har tre rader: rad som klarat testet får en grön bock, raden som testas är blå med "Väntar…" och de kommande står i grått med "Sen". Testet går vidare av sig självt när ett tryck kommer fram. **Hoppa över** uppe till höger är tyst. |
| … allt fungerar | `kontroller-klar.png` | Tre gröna bockar. Starta prov blir blå. Raden "Knapparna på låsskärmen gör samma sak" visas en gång, och under knappen står "Avsluta på telefonen. Annars börjar listan om." |
| … ett tryck kom inte fram | `kontroller-saknas.png` | Kommer inget tryck fram inom 8 s, får raden texten "Kom inte fram" och ett grått streck. Rött används inte, eftersom det är en inställning och inte ett fel. Rutan förklarar vad som ger alla tre på lurar med dubbeltryck per lur (vänster: Nästa spår, höger: Spela/pausa, specen §3) och var det ställs in. "Öppna Inställningar" och "Prova igen" finns där. Den blå knappen heter då **Starta ändå**. Ingen fråga om modell. |
| Uppspelning: betänketid | `spelar-tank.png` | "Fråga 7 av 20" och "Varv 2" överst, och en stapel med ett streck per fråga. Brickan visar provets namn. **Frågan stort** (34 bold, centrerad). En ring räknar ner betänketiden med siffran i mitten och "Tänk" under. Längst ner står de tre trycken som en tyst rad med prickar och ord. **Avsluta** är stor (64 pt) och neutral, aldrig röd, och det enda sättet att sluta. |
| Uppspelning: svar | `spelar-svar.png` | Brickan säger vad som spelas: "Långt svar" eller "Kort svar", med en liten ljudvåg. Svaret står som text: det som redan lästs upp är fullfärgat och resten grått, med ordtidsstämplarna från K46. Den korta meningen är halvfet. Raden längst ner lyser blått vid trycket som gjordes. Vid "Kort svar" visas bara första meningen. |
| Uppspelning: pausad | `spelar-paus.png` | Frågan grå, brickan "Pausad" (grå), en stor paussymbol, "Tryck på AirPods för att fortsätta" och "Fortsätter från samma ord". Den tredje prickgruppen heter nu "Fortsätt". Skärmen själv är också en knapp: ett tryck var som helst utom på Avsluta fortsätter. |
| Låsskärmen | `lasskarm.png` | Det appen sätter i `MPNowPlayingInfoCenter`: **titel = frågan**, artist = "Earmind · Biologiprovet · 7 av 20" och bild = appikonen (exakt D, D139). iOS ritar själva spelaren, så skissen visar bara innehållet. Uppdatera titeln vid varje ny fråga. |
| Fortsätt där du var? | `fortsatt.png` | Ett blad nerifrån, när appen öppnas efter att iOS stängt den eller efter Avsluta. Där står provet, "fråga 7 av 20" och frågan, och knapparna **Fortsätt** (blå) och "Börja från fråga 1". Avsluta frågar inte "Är du säker?", eftersom platsen alltid sparas. |
| Dela provet | `dela.png` | Listan visar vad som delas: Frågor och svar (20) och Ljud (36 av 40). Foton och dokument står gråade med "delas inte". Knappen är grå med förloppet ovanför och texten "Delas när ljudet är klart" tills ljudet är klart. Därefter blir den blå "Dela", som öppnar systemets delningsblad. |
| Fler lägen (BETA) | `fler-lagen.png` | Alla lyssnande lägen i en lista, med samma lilla BETA-märke. Ingressen säger en gång att lägena lyssnar och är i BETA. I Provläge heter det gamla röstförhöret **Förhör med rösten**, med BETA. Fotnoten: "Lyssnande lägen använder mikrofonen. Starta prov gör det aldrig." |

## 4. Regler som gäller hela läget
1. **Ett tryck betyder alltid samma sak** (specen §3). Skärmen visar trycken i samma ordning överallt: 1 = långt svar,
   2 = kort svar, 3 = paus (Fortsätt när det är pausat). Prickarna ●, ●● och ●●● är symbolen för trycken i appen,
   på kontrollskärmen och i hjälpen. Använd inte AirPods-bilder eller hörlursikoner (granskningsrisk 5.2.5, Ke12).
2. **Inga knappar för svaren på skärmen** under uppspelningen. Man styr med AirPods, och telefonen är för att avsluta.
   Undantaget är paus: där fortsätter ett tryck på skärmen, eftersom användaren då ändå tittar.
3. **Avsluta är aldrig röd** (SYSTEM §3) och frågar aldrig "Är du säker?". Positionen sparas, och nästa start erbjuder
   "Fortsätt där du var?".
4. **BETA-märket:** grå kontur, 11 pt bold med versaler och hörn 6. Det är märkning, inte en varning, så det har varken
   färg eller ikon. Det står på varje lyssnande läge och på "Fler lägen".
5. **Grönt bara för en bock som är klar** (kontrollskärmen). Lägg till tokens i `LumenColor`: `ok` #1F7A4D / #5FD39A och
   `okSoft` #E5F4EC / #15301F. Inget annat blir grönt.
6. **Ord:** "Starta prov" (Arons namn, D142), "Nytt prov", "Långt svar", "Kort svar", "Paus", "Fortsätt", "Avsluta",
   "Tänk", "Varv" och "Ljud: X av Y klara". Skriv inte "A+-svar" i gränssnittet; det är ett internt kvalitetskrav.
   Användaren ser "Långt svar".
7. **Ljudets förlopp räknas i filer** (en fil per fråga och en per svar). Med D145 är det **2 × antal frågor**, inte
   3 × N som står i specen (R5b, §3 "54 av 90"). Se avsnitt 6.
8. **Största text** (SYSTEM §10): den stora frågan på uppspelningsskärmen får brytas över fler rader, men brytningen
   sker aldrig mitt i ett ord. Raden med trycken staplas lodrätt vid `.accessibility1` och uppåt.
9. **Mörkt läge:** uppspelningsskärmen används ofta i mörker, så i mörkt läge är bakgrunden `background` (#0F1218)
   utan ljusa ytor utom Avsluta (`surface`).

## 5. Demosidan
Ke49 säger "sedan demosidan: Plugga med AirPods utan att röra mobilen". Specen §7 säger att Kelly uppdaterar sidan
**efter A81**, och sajtens regel sedan Ke1 är att inget ska påstås om en funktion som inte är provad på telefon.
Repetitionsläget är inte byggt än (A78–A81 är öppna). **Beslut (Kelly):** sidan ändras inte nu. Texten nedan är
färdig och läggs in när A80 är provad på telefon (Toby T18). Den som läggs in innan dess får märket "Kommer snart".

> **Plugga med AirPods utan att röra mobilen.** Fota ditt material. Earmind gör korta provfrågor och svar och läser upp
> dem i örat. Tryck en gång för hela svaret, två gånger för det korta och tre för paus.

Det kommer att stå i heron och som första steg i "Så kommer du igång". Den nuvarande demorutan (Förhör mig / Få A-svar)
byts mot en ljudspelare med tre exempelfrågor från exempelprovet. Den inspelade rösten görs av Kevin vid blindtestet
(K48) eller läggs in efter T18. Inga nya ElevenLabs-anrop från sidan.

## 6. Till Deangelo och Angela
- **Antal ljudfiler (spec R5b, §3 och A79):** efter D145 spelas det korta svaret från det långa svarets fil, så ett
  prov har 2 × N filer (fråga + långt svar), inte 3 × N. Skisserna visar "36 av 40" för 20 frågor. Specens "54 av 90"
  och R5b:s "alla 3 × N filer" bör ändras till 2 × N.
- **Inställningsvägen för AirPods 1/2** ("Inställningar › Bluetooth › ⓘ vid dina AirPods › Dubbeltryck") är **ej
  verifierad** i iOS 26. Där kan AirPods ha en egen rad högst upp i Inställningar. Toby eller Angela kontrollerar
  den på telefon innan texten byggs in.
- **"Kom inte fram" efter 8 s** är mitt förslag. Ändra det om iOS behöver längre tid för att skilja trycken åt.
- **Hur det ser ut på låsskärmen** är **ej verifierat**. iOS ritar spelaren själv, och vilka knappar som syns beror på
  vilka kommandon som är på. Med `nextTrack`/`previousTrack` på och skip/seek av bör ⏮ ▶ ⏭ synas.

## 7. Granskning
Jag granskar A79–A81 mot den här filen och `GRANSKNING.md` när Angelas skärmbilder finns (CI "Simulator screenshots").
Skärmbildsscener som behövs: `repHome`, `repHomeEmpty`, `repMaterial`, `repSummary`, `repList`, `repEdit`,
`repControls` (väntar, klar och saknas), `repPlayThink`, `repPlayAnswer`, `repPaused`, `repResume`, `repShare`
(av och på) och `moreModes`.
