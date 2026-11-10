# Annonser (Ryan håller filen, Aron sätter budgeten)

## Budget (bara Aron ändrar)
| Plattform | Per dag | Per månad | Senast ändrad |
|---|---|---|---|
| Meta (Instagram/Facebook) | – (Aron skriver) | – | |
| TikTok | – (Aron skriver) | – | |

Ryan får aldrig lägga mer än detta. Tom budget = inga annonser igång. Priser exklusive moms.

## Mål
Före App Store: **anmälningar till väntelistan** på demosidan (`/functions/v1/waitlist`). Efter TestFlight/App Store: installationer.
Mäts som: kostnad per anmälan (CPL), från plattformens händelse `Lead` och kontrollerat mot `source` i väntelisttabellen (utm_source=meta / tiktok).

## Konton (R1, Ryan 2026-11-10)
| Del | Meta | TikTok |
|---|---|---|
| Inloggning | Aron har konto | Saknas, Aron skapar (steg nedan) |
| Företag | Business Manager (Business Suite)? **ej kontrollerat** | Rothman Solutions AB |
| Annonskonto | **ej kontrollerat** | Skapas i steg 1 |
| Betalning | **ej kontrollerat** | Aron lägger in i steg 1 |
| Pixel/dataset | Saknas | Saknas |
| Domän | `aronstenlund-code.github.io` (GitHub Pages) | samma |

Ryan lägger aldrig in kortuppgifter eller skapar konton; det gör Aron. Resten (kampanjer, pixel-ID, målgrupper) gör Ryan i Arons inloggade webbläsare.

### Meta: vad Aron gör
1. Öppna den inbyggda webbläsaren i Claude-appen och logga in på business.facebook.com.
2. Säg till Ryan. Ryan kontrollerar själv företagskonto, annonskonto och betalning och säger exakt vad som saknas.
3. Saknas betalning: Inställningar (kugghjulet) → Fakturering och betalningar → Betalningsmetoder → Lägg till. Aron skriver in kortet själv.

### TikTok: vad Aron gör (källa: TikToks hjälpartikel "How to set up a TikTok Ads Manager account", verifierat i docs 2026-11-10)
1. Ha registreringsbeviset från Bolagsverket (PDF) redo. TikTok granskar företaget.
2. Gå till ads.tiktok.com → **Create an ad** / **Sign up**. Logga in med e-post, välj lösenord, klicka **Sign Up**, skriv in koden från mejlet.
3. Fyll i: **Country or region** Sverige · **Industry** appar/programvara (närmaste i listan) · **Legal business name** `Rothman Solutions AB` (exakt som hos Bolagsverket, annars dröjer godkännandet) · **Time zone** Stockholm (GMT+01:00) · **Phone number** 079-336 10 87 · **Currency** SEK. Tidszon och valuta går troligen inte att ändra senare (ej verifierat), så välj rätt nu. Klicka **Register**.
4. Fakturering: adress Ekbacksvägen 19, 182 38 Danderyd, momsnummer (SE + organisationsnummer + 01).
5. Betalningsmetod: välj kort eller förskott, skriv in kortet själv. Klicka **Go to Ads Manager**.
6. Säg till Ryan. Granskningen tar oftast under ett dygn; annonser kan inte gå förrän kontot är godkänt.

## Spårning (R1)
- **Ordning:** cookiebanner → pixlar laddas bara efter "Godkänn" → händelse `Lead` bara när `/waitlist` svarar 2xx. Inget laddas vid "Neka" eller utan val (GDPR/ePrivacy). Sidan använder i dag inga cookies (Ke5).
- **Meta:** dataset/pixel skapas av Ryan i Händelsehanteraren när Aron är inloggad. ID:t skickas till Kelly.
- **TikTok:** pixel skapas av Ryan i Assets → Events → Web events när kontot finns.
- **UTM:** varje annons länkar med `?utm_source=meta|tiktok&utm_campaign=<koncept>`; sidan sparar redan `source` (Ke5).
- **Domän:** github.io-adressen funkar för pixlar men inte för domänverifiering i Meta på samma sätt som en egen domän (ej verifierat). Rekommendation: egen domän när namnet är beslutat (D117).

### Till Kelly (Ryan får inte skriva i kelly.md, Deangelo flyttar punkten)
**Ke26 – Cookiebanner och annonspixlar** (effort: medium). En enkel banner (Godkänn / Neka lika stora, inga förkryssade val) som bara efter Godkänn laddar Meta-pixel och TikTok-pixel. ID:n som konstanter i `site/index.html`; tom konstant = pixeln laddas inte. Skicka `Lead` (Meta) och `SubmitForm`/`CompleteRegistration` (TikTok) bara när `joinList` får `r.ok`. Lägg till en rad i integritetstexten om annonsmätning. Höj `CONSENT_VERSION`. Lighthouse ≥ 95, site ≤ 2 MB.

## Regler och risker (läs före R2)
- **Fantasy (b), sexualiserad version:** Meta förbjuder vuxet/sexuellt innehåll i annonser utan undantag för 18+-riktning; åldersgränsen gör den inte tillåten. Fokus på kroppsdelar (urringning, sixpack) brukar avslås (Metas regel, sidan gick inte att läsa idag: ej verifierat i källa). Upprepade avslag kan stänga annonskontot. **Rekommenderar:** kör inte (b), eller tona ned till (a)-nivå. Beslut: Aron.
- **"Få A-svar till provet":** Meta har en egen regel om fusk och bedrägliga metoder (Cheating and deceitful practices). En annons som antyder fusk på prov riskerar avslag (ej verifierat vad regeln exakt säger). **Rekommenderar:** annonser visar plugg/förhör, inte svar under prov.
- **Minderåriga (EU, DSA art. 28):** annonser får inte riktas till under 18 utifrån profilering; 13–17 nås bara på ålder och plats. Riktning till elever blir därför bred (ej kontrollerat mot plattformarnas nuvarande inställningar).
- **Apple:** ingen Apple-lik hörlur, "fungerar med AirPods" (Ke22).

## Checklista för varje annons (Ryan, Aron 2026-11-10)
Gås igenom för varje koncept innan det läggs upp, och igen när resultaten läses. Märkning: (källa) = verifierat i docs 2026-11-10, (ej verifierat) = egen bedömning eller regel som inte lästs i dag.

### 1. Inspiration först (alltid)
1. Före varje nytt koncept eller ny testomgång: sök riktiga annonser på nätet. Aldrig från minnet.
2. TikTok Creative Center → Top Ads: filtrera på Sverige/Norden, branschen Appar/Utbildning, senaste 7 och 30 dagarna.
3. Metas annonsbibliotek (facebook.com/ads/library): sök på pluggappar och AI-appar (t.ex. Quizlet, Photomath, Gauth, Speak, Duolingo, ChatGPT) och på det de gör just nu.
4. Vanlig TikTok-sökning efter organiska videor som går bra: "studytok", "plugga", "AI", "AirPods", "POV".
5. Spara 5–10 referenser i `reports/ads/inspiration-ÅÅÅÅ-MM-DD.md`: länk, hook (första 2 s), format, varför den funkar, vad vi tar.
6. Ta strukturen (hook, tempo, format), aldrig själva videon, musiken, karaktärer eller repliker.

### 2. Hooken (0–2 sekunder)
7. Tittaren bestämmer sig under de första sekunderna (källa: Meta, TikTok). Hooken ska bära annonsen ensam.
8. En av tre hooktyper (källa: Meta): ett löfte om nytta, ett "nu ska du få se", eller en fråga som väcker nyfikenhet.
9. Rörelse eller ljud i första bildrutan. Ingen logga, ingen svart ruta, ingen långsam inzoomning.
10. Hooken säger något om tittaren, inte om appen ("du som har prov på fredag" slår "Lumen är en AI-app").
11. Text på skärmen i första bildrutan som säger samma sak som rösten, för den som skrollar utan ljud.
12. Gör 2–3 hookar per koncept och testa dem mot varandra med resten likadant (källa: TikTok, en ändring i taget).

### 3. Budskapet ska gå fram direkt
13. En idé per annons. Klarar jag inte att säga den i en mening är annonsen för rörig.
14. Visa produkten i bruk inom 3 sekunder: rösten i örat som säger något användbart.
15. Superkraften ska kännas, inte förklaras. Visa resultatet, inte funktionslistan.
16. Fungera både med och utan ljud: undertexter på allt tal.
17. Varje annons visar att Lumen funkar till mycket (plugg, intervju, socialt, vardag) men har ett eget tema (D119). Max en sekund per extra användning, annars blir det otydligt.
18. Samma ord som appen och sidan (Provläge, Standardläge, Förhör mig). Inget tittaren måste tolka.
19. Sista bilden: vad det är + vad man gör nu ("Gratis väntelista").

### 4. Ska inte se ut som reklam (D118)
20. 9:16, helskärm, filmat som med en telefon. Inga studiofilmer, inga reklamfonter.
21. Svenska röster, vardagligt språk, riktiga miljöer (skolkorridor, buss, kök, gym).
22. Följ formen för det som går organiskt just nu: POV, "storytime", reaktion, före/efter, "en dag med".
23. Text och viktiga saker inom säkra ytan: inget längst ner eller längs högerkanten där plattformens knappar ligger (ej verifierat exakta mått, kolla plattformens mall).
24. Musik bara från plattformens kommersiella bibliotek (Commercial Music Library på TikTok, Sound Collection på Meta). Kända låtar får inte användas i annonser (ej verifierat i dag).
25. Röst eller musik i alla annonser: Reels med ljud ger fler konverteringar enligt Meta (källa).

### 5. Unga användare
26. Prata som de pratar, inte som en vuxen som försöker. Ingen "hej alla elever", inga gamla memes.
27. Situationer de känner igen: prov i morgon, glömt läxan, muntlig redovisning, jobbintervju, att inte veta vad man ska säga.
28. Snabbt tempo, klipp var 1–2 sekund, 15–30 s totalt. Hellre 15.
29. Humor och självdistans funkar bättre än att visa upp något perfekt (ej verifierat för just vår målgrupp, mäts).
30. Under 18 i EU: inga intressen eller beteenden i målgruppen, bara ålder och plats (DSA, ej kontrollerat mot plattformarnas inställningar i dag). Kreativet måste därför själv hitta rätt personer.
31. Marknadsföring som når barn och unga får inte utnyttja oerfarenhet eller pressa (marknadsföringslagen/KO, ej verifierat i detalj). Ingen "alla andra har den redan", inga falska tidsgränser.

### 6. Sant och tillåtet
32. Inga löften om betyg ("få A"). Säg vad appen gör, inte vilket betyg man får.
33. Inget som visar eller antyder fusk under prov (Metas fuskregel, se risker ovan). Plugg, förhör och förberedelse går bra.
34. Inga påhittade omdömen eller "riktiga användare" som säger att det funkade. En skådespelare får spela en scen, men inte låtsas vara en verklig kund med ett verkligt resultat.
35. Appen i bild ska se ut som appen gör nu. Inga skärmar som inte finns.
36. Ingen Apple-lik hörlur, ingen Apple-logga, texten "fungerar med AirPods" (Ke22).
37. Inget sexuellt eller kroppsfokuserat på Meta (se fantasy (b) ovan).
38. AI-genererade realistiska personer eller röster: märk dem enligt plattformens regel (TikTok och Meta har båda AI-märkning, ej verifierat exakt krav i dag).
39. Creators/Spark Ads: tydligt märkt som reklam.
40. Plattformen märker betalda annonser som sponsrade. "Inte se ut som reklam" handlar om stil, aldrig om att dölja att det är reklam.

### 7. Uppmaning och landningssida
41. Uppmaningen tidigt (källa: TikTok) och igen i slutet. En enda: väntelistan.
42. Sidan ska säga samma sak som annonsen i första skärmen. Kommer man från rizz-annonsen och möts av provplugg tappar vi dem.
43. Varje annons har egen länk med `utm_source` och `utm_campaign=<koncept>`.
44. Före första kronan: gör en riktig anmälan från mobilen och kontrollera att den syns i väntelistan med rätt källa.
45. Sidan ska ladda snabbt på mobil (Lighthouse ≥ 95, redan krav för Kelly).

### 8. Testupplägg och beslut
46. 2–3 annonser per annonsgrupp åt gången (källa: TikTok). Många olika kreativ i Meta Advantage+ (källa: Meta, kreativ mångfald).
47. Låt plattformen fördela visningarna. Bedöm efter 3–5 dagar, inte efter några timmar (källa: zeely).
48. Bedöm på kostnad per anmälan, inte på visningar eller gillanden.
49. Läs också: hook rate (3-sekundersvisningar / visningar), hur många som tittar klart, klickfrekvens.
50. Stäng av: när annonsen har kostat cirka dubbelt så mycket som målpriset per anmälan utan en enda anmälan (målpriset sätts i R2).
51. Skala upp: högst +20 % budget per dag så att inlärningen inte startar om (ej verifierat, vanlig praxis), och alltid inom budgeten.
52. Byt kreativ när klickfrekvensen har sjunkit 20–30 % eller när samma person sett annonsen mer än cirka 3 gånger (källa: zeely), eller var 1–2 vecka (källa: TikTok).
53. Det som funkar blir en serie: samma format, ny situation.

### 9. Budget och säkerhet
54. Aldrig mer än budgeten i denna fil. Sätt kontots utgiftsgräns i både Meta och TikTok lika med månadsbudgeten.
55. Inga automatiska regler som höjer budgeten.
56. Läs utgifterna varje dag (R3) och skriv en rad i loggen.
57. Om budgeten töms eller tas bort: pausa allt samma dag.

### 10. Produktion
58. Läs varje manus noga (naturlig svenska, logik, längd) innan något genereras i ElevenLabs eller liknande, för att spara krediter.
59. Rösten i örat ska låta som ljud i en hörlur (lite tunnare, närmare) så att tittaren förstår vad som händer.
60. Exportera 9:16 (1080×1920) till TikTok och Reels, och 4:5 till Metas flöde om samma video används där.
61. Spara manus, hook-varianter och resultat per annons i `reports/ads/` så att vi vet vad som funkade och varför.

## Kampanjer
| Kampanj | Plattform | Koncept (Ke22) | Status | Spenderat | Resultat |
|---|---|---|---|---|---|

## Logg
- 2026-11-10 14:00: manus till 7 koncept klara (`reports/ads/2026-11-10-1400-manus-7-koncept.md`), Aron genererar i Gemini. Fantasy (b) inte skriven, väntar på beslut.
- 2026-11-10 13:30: checklista för annonser tillagd (Aron). Inspiration söks alltid på nätet före nytt koncept.
- 2026-11-10: R1 påbörjad. Inga annonser igång (budget tom). Väntar på: budget, Arons inloggning på Meta, TikTok-konto, Ke22, Ke26.
