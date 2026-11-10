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

## Kampanjer
| Kampanj | Plattform | Koncept (Ke22) | Status | Spenderat | Resultat |
|---|---|---|---|---|---|

## Logg
- 2026-11-10: R1 påbörjad. Inga annonser igång (budget tom). Väntar på: budget, Arons inloggning på Meta, TikTok-konto, Ke22, Ke26.
