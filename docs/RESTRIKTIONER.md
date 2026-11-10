# Restriktioner i Lumen: inventering och beslut (Deangelo, 2026-11-10)

Aron (D113): så få egna restriktioner som möjligt, eftersom modellen (Anthropic) redan har sina spärrar. Utgångsläge: blank sida, och sedan läggs bara det tillbaka som behövs.

## A. Tas bort nu (innehållsspärrar som modellen redan klarar)
| # | Var | Vad | Ersätts av |
|---|---|---|---|
| A1 | `answer/rizz.ts` `SEXUAL`, `PRESSURE` (K8, K26) | Kodfilter som stryker förslag med vissa ord | Modellens egna spärrar + rollbeskrivningen i prompten |
| A2 | `answer/rizz.ts` `isDecline`/`detectDecline` | Kod som tvingar fram ett avsked när någon säger nej | Rollbeskrivningen i prompten ("respektera ett nej") |
| A3 | `answer/prompt.ts` rad 88 | "Never say that you are an AI" | Inget. Raden är **oärlig** (gav "Nej, jag är inte en robot") och tas bort oavsett |
| A4 | Appen | 18+-spärren före Rizzläget (D112, A32) | Inget |
| A5 | Appen och servern | Kodstopp för "känsliga minnen" som inte är farliga (religion, intressen, mående i allmänhet) | Inget. Se B5 för det som är kvar tills Aron bestämt |

## B. De enda restriktionerna i appen (Aron 2026-11-10: "det är de enda som ska finnas")
| # | Vad | Varför den finns | Om den tas bort | Rekommendation |
|---|---|---|---|---|
| B1 | **Krissvar** (`crisis.ts`, K21/K23) | I Frågor var modellen **tyst** på "jag orkar inte leva" eftersom det inte var en fråga. Det är ett svar som läggs till, inget som tas bort | Tystnad mot en elev som mår dåligt | **Behåll** |
| B2 | **Samtycke + synlig lyssningsindikator** (CLAUDE.md) | Appen lyssnar på andra människor. Krävs av Apple och GDPR | App Store-avslag, juridisk risk | **Behåll** |
| B3 | **Hastighetsgräns** (`_shared/ratelimit.ts`) | Skyddar API-krediten mot missbruk | En person kan tömma månadens kredit | **Behåll** |
| B4 | **Elevtext aldrig till det publika repot** (K24) | Integritet | Elevers meningar på GitHub | **Behåll** |
| B5 | **Hälsa, kris och personnummer sparas inte som minne** (servern + appen) | GDPR: känsliga personuppgifter kräver uttryckligt samtycke | Juridisk risk | Behåll bara hälsa, kris och ID-nummer (resten tas bort i A5) |
| B6 | **Telefonnummer från modellen läses inte upp** (`speech.ts`) | Modellen hittar på nummer; verifierade (112, 1177, stödlinjer) läses upp | Påhittade nummer i örat | Behåll (det är en faktakontroll, ingen spärr) |
| B7 | **Bara säkra länkar** (`web.ts`, K19) | Stoppar länkar som ser ut som riktiga sidor men är falska | Nätfiske-länkar | Behåll |
| B8 | **Allergi-regeln** (`prompt.ts` `<safety>`) | Användaren har själv sagt att den är allergisk; modellen föreslår annars "lösgodis" | Fel råd om mat | Behåll |

## C. Lista att eventuellt lägga till senare (inte infört)
1. **Åldersgräns i App Store** sätts efter vad appen faktiskt innehåller (troligen 12+ eller 13+ utan sexuellt innehåll). Ej verifierat.
2. **Rapportknapp** på varje svar (finns delvis: tumme ned). Gör den synlig i alla lägen, så att vi lär oss vad som går fel i stället för att gissa restriktioner i förväg.
3. **Mätning i stället för spärrar:** Oscar mäter varje vecka en uppsättning svåra fall (press, sexuellt, kris, fusk). Bara om modellen faktiskt gör fel läggs en spärr till, och då för just det felet.
