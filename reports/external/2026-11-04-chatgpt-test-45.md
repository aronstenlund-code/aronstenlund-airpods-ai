# Lumen – test- och kvalitetsrapport till Creed

**Datum:** 4 november 2026  
**Omfattning:** 45 manuellt återgivna testsvar  
**Produkt:** Svensk hands-free-assistent för AirPods

## Sammanfattning

Lumen fungerar bra på flera korta faktainputs, ämnesord och vissa praktiska frågor. Den största svagheten är inte grundläggande språkförståelse, utan ojämn avsiktstolkning och kontextkontroll: ibland svarar den på fel ämne, återanvänder föregående svar eller ställer följdfrågor trots att produkten ska ge ett direkt svar.

Den måste också bli mer tillförlitlig på enkla beräkningar, årtal och talanpassat språk. Svarens längd varierar: vissa svar är onödigt långa, medan exempelvis en receptfråga inte får tillräckliga instruktioner.

### Övergripande bedömningsmedel

Poängen är manuella, kvalitativa granskningar av de 45 svaren på en skala från ett till fem. De är inte automatiska mätvärden.

| Kriterium | Medelpoäng |
|---|---:|
| Korrekthet | 4.13/5 |
| Förstod avsikten | 4.29/5 |
| Rätt längd | 3.98/5 |
| Ingen utfyllnad / inga onödiga frågor | 3.91/5 |
| Uppläsbarhet | 4.69/5 |

**Minne:** följdfrågor testades i några sekvenser, men det finns inte en separat poäng för alla 45 inputs.  
**Svarstid och tid till första ljud:** ej testat. Inga millisekundvärden har lämnats.  
**Taligenkänning och mikrofon:** ej testat med dessa textinputs.  
**Faktisk ljudstart:** ej akustiskt mätt.

## Viktigaste fynden

### 1. Kontexten hoppar till fel ämne

Vid testsekvensen med `hungrig, ägg, pasta` följdes den av `varför då?`. Enligt testaren svarade Lumen då om tredje ståndet och den franska revolutionen, alltså ett äldre ämne i stället för den närmaste relevanta kontexten.

Detta är särskilt allvarligt i hands-free-format där användaren ofta säger korta fragment som ”varför?”, ”mer”, ”kortare” eller ”hur mycket?”.

**Krav:** koppla korta följdinputs till den senaste relevanta turen. Byt inte tillbaka till äldre ämnen utan en tydlig signal från användaren.

### 2. Svar återanvänds trots att frågan byter ämne

På `mitt bankkort borta` gav Lumen exakt samma svar som på föregående fråga om skillnaden mellan garanti och reklamationsrätt. Det är ett kritiskt relevansfel.

**Krav:** kontrollera att varje genererat svar faktiskt besvarar den aktuella inputen. Ett tidigare svar får inte återanvändas enbart för att det finns i konversationshistoriken.

### 3. Enkla beräkningar blir fel

På `17 gånger 24` svarade Lumen ”Sjutton gånger tjugofyra är fyrahundra och åttio.” Rätt svar är **fyrahundraåtta**.

Ett annat procenttest, `12 procent av 250`, besvarades korrekt med trettio.

**Krav:** räkna om och kontrollera aritmetiska resultat innan de läses upp. Enkel huvudräkning ska vara pålitlig.

### 4. Årtal och talformulering behöver kvalitetssäkras

På `Napoleon` angav Lumen att han styrde Frankrike från ”nittonhundrafemton till nittonhundrafemton”, vilket är fel. I ett annat svar om franska revolutionen började modellen med ”nittonhundra... nej” innan den kom fram till rätt årtal.

**Krav:** verifiera årtal och historiska tidsperioder. Säg årtal direkt med naturligt svenskt uttal. Undvik självkorrigeringar och stakningar i det färdiga upplästa svaret.

### 5. Följdfrågor trots direktiv om att inte ställa följdfrågor

På `vad svarar jag?`, efter kontexten `hon svarade bara vi får se`, avslutade Lumen med: ”Vill du att jag formulerar ett konkret svar åt dig?”

På andra frågor har den också bett användaren berätta mer eller förtydliga.

**Krav:** ställ inga följdfrågor. Välj den mest sannolika tolkningen och ge ett användbart svar direkt. Vid osäkerhet ska modellen kort markera sin tolkning eller ge ett säkert standardråd, inte fråga tillbaka.

### 6. Sociala repliker får ett alltför bokstavligt svar

På `Varför står du bara där?` förklarade Lumen att den inte kan stå eller röra sig och att frågan inte var en kunskapsfråga. På `Vilka fina ögon du har` svarade den med en lång förklaring om att den saknar ögon.

**Krav:** förstå social funktion och ton. Svara kort, naturligt och utan att överförklara att den är en AI, när det inte behövs.

### 7. Kort input leder ibland till fel sorts hjälp

På `Hungrig, ägg, pasta` frågade Lumen vad användaren hade i tankarna och gav näringsinformation i stället för ett enkelt receptförslag.

På `havregrynsgröt två personer` gav den ingrediensmängder men ingen tillagningsmetod.

**Krav:** dra slutsats av vanlig avsikt. När användaren nämner hunger och ingredienser är ett enkelt recept det mest sannolika. Praktiska instruktioner ska innehålla de steg som behövs för att faktiskt genomföra uppgiften.

### 8. Onaturliga översättningar och uttryck

På `low-key` översatte Lumen det bokstavligt till ”låg nyckel” och ”hög nyckel”. Förklaringen låg nära betydelsen, men uttrycket på svenska blev onaturligt.

**Krav:** översätt betydelse och användning, inte ord för ord. Använd naturliga svenska motsvarigheter som ”lågmäld”, ”diskret” eller ”inte så uppseendeväckande”, beroende på sammanhang.

### 9. Sammanfattningar lägger till slutsatser som saknar stöd

I sammanfattningen av mötesplanen lade Lumen till: ”Det är allt som behöver ordnas, så ingen ytterligare planering verkar krävas.” Det fanns inget stöd för den slutsatsen i användarens text.

**Krav:** sammanfatta endast information som faktiskt lämnats. Lägg inte till antaganden om att något är färdigt eller att inga fler uppgifter finns.

### 10. Svarslängden behöver styras av uppgiftstyp

Vissa enkla svar är bra och korta. Andra svar har onödiga inledningar och upprepningar. Samtidigt fick vissa ämnesord för korta förklaringar och praktiska instruktioner saknade nödvändiga steg.

**Krav:** välj längd efter syftet:
- Enkel fakta, översättning och huvudräkning: oftast en till två meningar.
- Ensamt ämnesord eller uttryck: kort introduktion och några relevanta förklarande meningar; normalt fem till åtta meningar när ämnet kräver det.
- Social replik: oftast en naturlig mening eller två.
- Praktisk instruktion: kort men komplett, med nödvändiga steg.
- Sammanfattning: endast de viktiga punkterna, utan inledning eller slutsats som inte efterfrågats.

## Positiva resultat

- `grek flosof` tolkades som grekiska filosofer och gav relevanta exempel.
- `Fe` gav järn, ferrum och atomnummer tjugosex.
- `fotosyntes` fick en korrekt grundförklaring.
- `2,5 liter i ml` besvarades direkt och korrekt.
- `12 procent av 250` besvarades korrekt.
- `till engelska: jag blir sen` gav en fungerande översättning.
- `kortare` fungerade väl som följdinput och förkortade föregående svar utan ämnesbyte.
- `riksdagens uppgift` gav en tydlig och i huvudsak korrekt förklaring.
- Mötesinformationen om fredag och ansvarsfördelningen återgavs korrekt, även om svaret innehöll extra text.

## Test 36–45: senaste omgången

Teckenlängd inkluderar mellanslag och skiljetecken. Svarstider saknas.

| ID | Input | Svarslängd | Bedömning |
|---|---|---:|---|
| M36 | `12 procent av 250` | 43 tecken | Rätt och direkt. |
| M37 | `low-key` | 214 tecken | Betydelsen fångas ungefär, men den bokstavliga översättningen ”låg nyckel” är onaturlig. |
| M38 | `tappat plånboken` | 215 tecken | Bra praktiskt råd om att leta och spärra kort; kunde nämna legitimation. |
| M39 | `till engelska: jag blir sen` | 62 tecken | Korrekt översättning. |
| M40 | `riksdag regering skillnad` | 297 tecken | I huvudsak korrekt; ”regeringen för landet vidare” är otydligt. |
| M41 | `hon svarade bara vi får se` | 102 tecken | Tolkar svaret som tråkigt besked utan stöd; ger ingen konkret replik. |
| M42 | `vad svarar jag?` | 195 tecken | Håller kvar social kontext men ger inget tydligt färdigt svar och ställer en följdfråga. |
| M43 | `Jag har tjugo minuter och måste äta, packa och gå. Vad gör jag först?` | 176 tecken | Rimlig ordning, men saknar tidsfördelning för 20 minuter. |
| M44 | `kortare` | 73 tecken | Bra kontextminne och korrekt förkortning. |
| M45 | `riksdagens uppgift` | 178 tecken | Korrekt och lätt att förstå. |

## Rekommenderad prioriteringsordning för åtgärder

**P0 – kritiskt**
1. Säkra ämneskoppling så att aktuellt svar inte blir en kopia av föregående svar.
2. Förbättra närminnet så att ”varför då?” och ”kortare” kopplas till rätt tur.
3. Stoppa följdfrågor och ersätt dem med sannolik tolkning och direkt svar.
4. Lägg till faktakontroll för enkla beräkningar och viktiga årtal.

**P1 – hög prioritet**
5. Förbättra tolkning av fragment, stavfel, ämnesord och sociala repliker.
6. Anpassa svarslängd efter intent.
7. Förbättra naturlig svensk uppläsning, inklusive årtal, enheter och översättningar.
8. Säkerställ att sammanfattningar inte hittar på slutsatser.

**P2 – produktkvalitet och verifiering**
9. Testa på verkligt tal via mikrofon och AirPods, inklusive felaktig taligenkänning.
10. Mät från användarens släpp-/skickahändelse till första ljud. Målet som angetts för produkten är under tre sekunder, och svarstiden måste vara under fem sekunder.
11. Testa kontinuerlig kontext i längre samtal och hur appen hanterar avbrutna eller ofullständiga inputs.

## Integritet och användning i samtal

Lumen ska kunna användas hands-free och diskret för användaren, men ska inte utformas för dold inspelning eller hemlig transkribering av personer i närheten. Konversationsfunktioner ska aktiveras på ett tydligt och samtyckesbaserat sätt, med kontroller för att starta och stoppa lyssning. Spara eller dela inte omgivningens tal i hemlighet.

## Rekommenderat nästa steg

Be Creed granska den befintliga implementationen, identifiera var kontext, prompt, svarsgenerering, TTS och eventuellt taligenkänning styrs. Implementera generella lösningar – inte specialfall hårdkodade för testfrågorna. Kör sedan om de 45 testerna och jämför resultaten med denna baslinje.
