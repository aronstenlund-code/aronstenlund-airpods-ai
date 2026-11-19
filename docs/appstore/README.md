# App Store-produktsidan (Kelly (moln), Ke80, D232, 2026-11-18)

**Klar att lägga in, men inget är uppladdat eller inskickat.** Det görs bara efter Arons ja (TILL-ARON #27).
Integritetsuppgifter, granskningsanteckningar och engelsk text: `granskning.md`. Kontrollen av vad texten lovar: §5.

## 1. Bilder (6,9 tum, 1320 × 2868)
Rubrik ovanför en oförändrad skärmbild ur appen (Apple-stil, D160): grå bakgrund, mörk ram, ingen skugga.
Skärmbilderna är tagna i **full storlek** på iPhone 17 Pro Max med Kellys bildflöde `kelly-appstore-shots.yml`
(inga nedskalningar; appen startas med `say.hasPlayed`, så raden om låst skärm syns inte). Rådata: grenen
`kelly/appstore-shots-ke80`. Rubrikerna är satta i Inter Display (molnet); byt till SF Pro Display på en Mac om Aron vill
(kommandot sist).

| # | Fil | Rubrik | Rad under | Scen |
|---|---|---|---|---|
| 1 | `69-1.jpg` | Skriv. Lyssna. | Det du skriver läses upp i dina hörlurar. | `repSayCredits` |
| 2 | `69-2.jpg` | Om och om igen. | Från 10 minuter upp till en timme. | `repSayOnCard` |
| 3 | `69-3.jpg` | Hur ska det låta? | Skriv det, så väljer EarMind en röst. | `repSayPicked` |
| 4 | `69-4.jpg` | Välj en röst. | Lyssna först. Det kostar inget. | `repSayVoicesUser` (körning 44374827725, utan röster under granskning) |
| 5 | `69-5.jpg` | Spela igen. | Det senaste ligger kvar under fältet. | `repHomeSaidMarks` |
| 6 | `69-6.jpg` | Fota boken. | Frågor med svar, eller hela texten uppläst. | `repTextNew` |
| 7 | `69-7.jpg` | Tryck för svaret. | 1 gång för långt svar, 2 för kort, 3 för paus. | `repPlayAnswer` |
| 8 | `69-8.jpg` | Börja gratis. | 1 500 krediter ingår varje månad. | `repShop` |

Bild 1–3 syns i sökresultatet och berättar idén: skriv, lyssna, välj hur det låter. Inget om låst skärm (D209 inte
provat på telefon) och inget som antyder dold användning: varje bild visar appen öppen och synlig.

## 2. Texter (tecken räknade med Python)
| Fält | Gräns | Text | Tecken |
|---|---|---|---|
| Namn | 30 | EarMind | 7 |
| Undertitel | 30 | Lyssna och plugga i hörlurarna | 30 |
| Reklamtext | 170 | Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar, om och om igen, eller gör provfrågor med svar. | 127 |
| Nyckelord | 100 | `plugga,prov,förhör,glosor,uppläsning,läxor,repetition,instudering,provfrågor,skola,gymnasiet,röster` | 99 |
| Support-URL | – | https://earmind.vercel.app | – |
| Marknadsförings-URL | – | https://earmind.vercel.app | – |
| Integritets-URL | – | https://earmind.vercel.app/integritet (**Ke78, inte publicerad**: Arons ja först) | – |
| Villkor (EULA) | – | Apples standard-EULA, och länken https://earmind.vercel.app/villkor i beskrivningen (krav för prenumeration, 3.1.2; **inte publicerad**) | – |
| Kategori | – | Utbildning (primär), Produktivitet (sekundär) | – |
| Åldersgräns | – | **13+** (förslag, se §4) | – |

"AirPods" står inte i namnet, undertiteln eller nyckelorden (D122, Apples varumärkesregler), bara i beskrivningen.

**Beskrivning** (1862 av 4 000 tecken):

> Skriv det du vill höra, eller fota boken. EarMind läser upp det i dina hörlurar, om och om igen.
>
> SÄG I AIRPODS
> • Skriv eller klistra in en text och tryck Spela. Den läses upp om och om igen, från 10 minuter upp till en timme.
> • Skriv hur det ska låta, till exempel "lugnt, som en lärare", så väljer EarMind en röst som passar. Eller välj själv och lyssna först.
> • Skriv i takt läser långsamt med pauser, så att du hinner skriva.
> • Du ser hela tiden att det spelas och hur länge det är kvar, och du stoppar när du vill.
>
> FOTA BOKEN
> • Fota sidor, välj bilder, lägg till en PDF eller Word-fil eller klistra in en länk.
> • Få provfrågor med ett kort och ett långt svar, eller hela texten uppläst.
> • Ändra, ta bort eller lägg till egna frågor och svar.
>
> STARTA PROV
> • Frågorna läses upp i dina hörlurar. Tryck 1 gång för det långa svaret, 2 gånger för det korta och 3 gånger för paus.
> • Starta prov och Säg i AirPods använder aldrig mikrofonen.
>
> DELA MED KLASSEN
> • Dela ett prov med en länk eller publicera det för din skola. Foton och dokument delas aldrig.
>
> KREDITER
> • 1 500 krediter ingår varje månad.
> • 1 kredit är 1 tecken nytt ljud. Ljud som redan finns och upprepningar kostar inget.
> • Bjud in en kompis och få 2 000 krediter när kompisen har spelat sin första text.
> • Köp fler krediter eller ett veckokort i appen. Veckokortet förnyas varje vecka tills du säger upp det.
>
> FLER LÄGEN (BETA)
> EarMind har också lägen som lyssnar på vad du säger och svarar i örat, till exempel förhör med rösten. De frågar om lov och om mikrofonen innan de startar, och visar hela tiden att de lyssnar.
>
> Fungerar med AirPods. EarMind är inte gjord av eller kopplad till Apple. Svar från AI kan vara fel, så kontrollera mot din kursbok.
>
> Villkor: https://earmind.vercel.app/villkor
> Integritet: https://earmind.vercel.app/integritet

## 3. Måste vara sant när den skickas in
1. **Ke78 publicerad** (integritet och villkor), annars fungerar inte länkarna. Arons ja (TILL-ARON #30).
2. **Produkterna** (tre paket och veckokortet) finns i App Store Connect och skickas med bygget; annars ser granskaren
   bara "Paketen kunde inte hämtas …". (TILL-ARON #27)
3. **Byggnummer** på bilderna: tagna från main `97a0286` (körning 44309786844) (se `kelly/appstore-shots-ke80`/RUN.txt). Ändras en skärm
   före inskickning: kör flödet igen och `appstore.py`.

## 4. Åldersgräns (förslag 13+)
Apples frågeformulär (2025: 4+, 9+, 13+, 16+, 18+). Svar som Kelly föreslår, **Aron svarar ärligt i formuläret**:
- Mogna eller suggestiva teman: **sällsynt/milt** (Rizzläget i Fler lägen ger flirtförslag, D112, inget sexuellt).
- Innehåll som AI skapar: ja (svar, frågor, röstval). Användare kan publicera prov för sin skola (rapporteras och döljs).
- Inget våld, inga droger, inget spel om pengar, ingen obegränsad webb.
Det ger troligen **13+**, vilket stämmer med integritetssidan ("från 13 år"). **untested assumption**: Apples svar
avgör.

## 5. Kontroll: lovar texten mer än appen gör?
Mot `granskning.md` §1 och dagens main. [V] i koden eller beslut, [S] sett i Simulatorn, [L] provat live mot servern
(Oscar), **[O]** inte provat på telefon.
| Påstående | Status |
|---|---|
| Upprepas 10 min till 1 timme (D210) | [S] A124/A132 |
| "Skriv hur det ska låta … väljer EarMind en röst", "välj själv och lyssna först" | [S] A136/A140, [L] O81 (14 röster, AI-val med motivering) |
| Skriv i takt med pauser | [S] A136; pausernas längd **[O]** |
| "Du ser att det spelas och hur länge det är kvar" | [S] A132 |
| Länk, PDF, Word som material | [S] A116; hämtningen K81 **[O]** live |
| 1, 2, 3 tryck | [V]; **[O]** alla AirPods-modeller |
| Starta prov och Säg använder aldrig mikrofonen | [V]; **[O]** orange prick på telefon (R9) |
| Dela med länk, publicera för skolan | [S] A81/A83; att länken öppnar appen **[O]** |
| 1 500 i månaden, inbjudan 2 000 | [V] D213/D224, [L] O82. **Välkomsten (5 000) nämns inte** förrän den är på (Team ID, TILL-ARON #31, D239); läggs då till i beskrivningen och bild 8 |
| Köp och veckokort | [S] A134 med låtsasbutik; **[O]** StoreKit-filen (T48) och produkterna i App Store Connect |
| Fler lägen frågar om lov och visar att de lyssnar | [V] D21, `ListeningModel` |
| **Står inte i texten:** låst skärm (D209), "andra hörlurar", att ljudet fungerar utan nät | medvetet utelämnat |

## Göra om bilderna
```
gh workflow run kelly-appstore-shots.yml --ref main -f branch=kelly/appstore-shots-ke80 -f screens="repSayCredits repSayOnCard repSayPicked repSayVoicesUser repHomeSaidMarks repTextNew repPlayAnswer repShop"
python3 -I docs/appstore/_src/appstore.py <mapp med bilderna> [<fet font> <vanlig font>]
```
Utan fontargument används Inter Display (finns i molnet). Äldre underlag (Ke56/Ke62/Ke74) finns i git-historiken.
