# Oscar O25: Oberoende test av K22 (riktiga användares frågor in i repot): integritet, offline

Datum: 2026-11-10, 10:50–10:54
Uppgift: stående uppgift (PLAN 2b), test av den senaste klara K-punkten som saknar O-punkt. Kevin skrev "Oscar granskar" i `reports/2026-11-10-1050-kevin-k22-real-users-and-credit-runs.md`.
Skript: `scripts/qa/o25_k22_privacy.py`. Det kör Kevins `scripts/real_users.py` (`scrub`, `sensitive`, `run`) på påhittade data, utan nät och utan modell, och kostar 0 USD.
Rådata: `reports/qa/data/2026-11-10-1054-o25-k22-privacy.json`

**Verified in code** (körd lokalt). Kevins egna 4 tester är gröna, men de täcker bara hans exempel.

## Varför det är viktigt
Repot är **publikt**. Det som klarar rensningen och k ≥ 2 skrivs till `scripts/real-user-cases.json` och `scripts/real-user-bank.json`, och flödet `real-users.yml` **committar och pushar själv till main**. Allt som slinker igenom blir alltså läsbart för vem som helst och ligger kvar i git-historiken, även om det tas bort senare. Kevin skrev att Oscar ska granska de första filerna, men flödet väntar inte på någon granskning.

## Resultat
| Del | Resultat |
|---|---|
| Personuppgifter som ska bort | **3/22**. Telefonnummer, personnummer och "min bror Noel" togs bort. |
| Känsliga rader som ska hoppas över helt | **2/20**. "jag tror att jag är bi" och "min syster är gravid och sexton" hoppades över. |
| Vanliga frågor som ska vara kvar | **8/10** |
| Från början till slut: samma mening från 2 installationer | **"jag vill hänga mig" och "min kompis [namn] Andersson sa …" skrivs till filerna** |

## Personuppgifter som blir kvar (19 av 22)
| Sagt | Blev |
|---|---|
| "min kompis Lisa Andersson sa att provet var svårt" | "min kompis [namn] **Andersson** sa …" (efternamnet blir kvar) |
| "Lisa Andersson i nian sa att provet flyttas" | oförändrat. Ett förnamn följt av ett ord med stor bokstav tolkas som en historisk person. |
| "jag och elin ska plugga ikväll" | oförändrat (Scribe skriver ofta namn med liten bokstav) |
| "Ahmed och jag gör grupparbetet", "Fatima frågade om läxan", "Oskar i min klass sa …", "Elvira Johansson har födelsedag", "det är Wilhelm här" | oförändrat. Namnen finns inte i listan på cirka 150 namn, och där finns "oscar" men inte "oskar". |
| "vår lärare Kalle sa att …" | oförändrat. Mönstret gäller bara "min/mina/mitt", inte "vår", och Kalle finns inte i listan. |
| "min mamma heter Gunilla" | "min mamma [namn] **Gunilla**". Flaggan `(?i)` gör att `[A-ZÅÄÖ]` matchar små bokstäver, så ordet "heter" togs för namnet. Samma fel gör "min kompis tar kokain" till "min kompis [namn] kokain". |
| "jag bor på storgatan 12 i Umeå", "jag bor på Ringvägen i Hässleholm" | oförändrat. Adressmönstret kräver stor bokstav och husnummer. |
| "jag går på Kungsholmens gymnasium", "jag går i 9B på vasaskolan" | oförändrat. Mönstret kräver "-gymnasiet" eller "-skolan" och stor bokstav. |
| "följ mig på insta lisa_2009", "min snap är @elin.k09" | oförändrat (användarnamn i sociala medier) |
| "mejla aron punkt stenlund snabel-a icloud punkt com" | oförändrat (e-post uttalad som Scribe skriver den) |
| "registreringsnumret ABC 123" | oförändrat |
| "mitt nummer är noll sju noll ett två tre …" | oförändrat av `scrub`. Raden hoppades bara över för att "sex" (talet) räknas som känsligt. |

## Känsliga rader som blir kvar (18 av 20)
- **Kris och självskada:** "jag vill hänga mig", "jag rispar mig på armarna", "jag har skurit mig igen", "jag har sparat tabletter ifall jag inte orkar", "ingen skulle sakna mig om jag försvann". Detta är samma luckor som i krisfiltret (O23).
- **Hälsa:** "jag har diabetes, får jag äta godis", "jag har epilepsi …", "jag har klamydia …", "jag har fått mens för första gången", "jag har ätit nästan ingenting på en vecka för att gå ner i vikt".
- **Sexualitet och religion:** "är jag gay om jag gillar killar" (bara "jag är gay" finns), "jag fastar under ramadan …".
- **Våld och familj:** "pappa slår mig när han är full", "mina föräldrar ska skiljas" (bara "skild" och "skilsmässa" finns).
- **Brott och droger:** "jag har rökt hasch …", "jag snattade på ICA igår", "min kompis tar kokain".
- **Privatliv:** "jag är kär i min lärare".

**För mycket bortsorterat:** "vad är sex gånger åtta" ("sex") och "vad är skillnaden mellan diagnos och prognos i biologi".

## Till Kevin
1. **Skriv aldrig användartext direkt till det publika repot.** Låt flödet spara resultatet som en Actions-artefakt, eller i en tabell som bara tjänstenyckeln når, och låt en människa eller Oscar godkänna innan något hamnar i git. Det som har pushats går inte att ta tillbaka.
2. **Behåll bara frågor som ser ut som allmänna kunskapsfrågor.** Allt med jag-form, ett namn eller en relation ("min kompis", "pappa", "vår lärare") ska bort helt i stället för att rensas. Ett mönster kan aldrig hitta alla namn: listan har cirka 150 namn, och Sverige har tiotusentals.
3. Ta bort flaggan `(?i)` på namnmönstret, så att "heter" och "tar" inte blir namn. Lägg också till "heter" efter relationsordet ("min mamma heter X").
4. Använd krisfiltret (`crisis.ts`) här också, så att listorna inte går isär, och utvidga `SENSITIVE` med hälsa, kön och sexualitet, våld i hemmet, brott och droger enligt listan ovan. Skriv "sex" så att talet inte räknas.
5. Lägg in de 52 fallen i `test_real_users.py`: `python -I scripts/qa/o25_k22_privacy.py`.

## Concerns (till Architect)
D57 lovar användaren att historiken laddas upp pseudonymt och sparas högst 12 månader för att förbättra appen. Att lägga frågorna i ett **publikt** GitHub-repo är en annan mottagare än samtycket beskriver: hela internet. Även rensade och ställda av två personer kan de peka ut någon ("vasaskolan 9B", ett ovanligt namn). Mitt förslag är att riktiga användares text aldrig hamnar i det publika repot, bara siffror (antal och kategori). Texterna stannar i Supabase och läses av eval-körningen därifrån.

## Till Aron
- **Lägg inte in hemligheten `SUPABASE_SERVICE_ROLE_KEY` i GitHub ännu.** Samma hemlighet startar K22 (`real-users.yml`) varje måndag, och K22 committar användarnas frågor till det publika repot. Med dagens rensning blir efternamn, skolor, adresser och krisrader kvar. Vänta tills Kevin har rättat punkt 1 ovan och jag har testat igen. I dag finns inga riktiga användare, så ingen data har läckt. **Verified** 2026-11-10 10:58: filerna finns inte i repot, och GitHub-API:t (`actions/secrets`) visar bara `SUPABASE_ACCESS_TOKEN`, så flödet hoppar över hämtningen.

## Kostnad
0 USD.
