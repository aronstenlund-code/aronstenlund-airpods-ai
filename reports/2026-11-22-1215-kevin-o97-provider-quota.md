# O97: /exam och /drill ger 503 provider_quota som /answer, med en text för användaren

Kevin (moln), 2026-11-22.

- **0 ElevenLabs.** Ingen riktig modell i testerna, eftersom Anthropic-krediterna fortfarande är slut.
- **Tester:** **848/848**.
- **Commit:** 12b45f9b, deployad av deploy-backend 370.

## Var felet tappades
- **`/answer`** har en egen mappning (`providerErrorToHttp`): modellens kreditfel (`LLMProviderError`, `kind: "quota"`) blir 503 `provider_quota`.
- **`/exam` och `/drill`** skickar alla fel genom den gemensamma `toHttpError` (`_shared/errors.ts`). Den kände inte till modellens fel och gjorde dem till **500 `internal`**.
- Testet med en låtsasmodell som kastar "credits exhausted" (som Anthropic-providern gör vid "credit balance too low") var rött: 500 `internal`.

## Rättning
- **En mappning för alla tre:** `providerHttpError` i `_shared/errors.ts` används nu av `toHttpError` (/exam, /drill) och av `providerErrorToHttp` (/answer).

  | Modellens fel | Svar |
  |---|---|
  | Krediterna slut | 503 `provider_quota` |
  | Hastighetsgräns | 503 `provider_busy` (retry-after 5 s) |
  | Saknar inställning | 503 `provider_unconfigured` |
  | Nyckeln nekas | 503 `provider_misconfigured` |
  | Annat | 502 |

  Alla har `fallback: true`. Andra fel ger 500 som förut.
- **Texten är för användaren.** Koden säger fortfarande vad som hänt, för Diagnostik och evals.
  - Krediterna slut, eller tjänsten nere: "EarMind är nere en stund. Försök igen senare."
  - På engelska, med `x-earmind-lang: en` eller en engelsk Accept-Language: "EarMind is down for a moment. Try again later."
  - Hastighetsgräns: "EarMind har mycket att göra just nu. Försök igen om en stund." / "EarMind is busy right now. Try again in a moment."
  - Förut stod det "LLM credits exhausted", och det visade webbetan som det var.
- **Verifierat i test** (`exam/o97_quota_test.ts`: /exam ger 503 provider_quota, mappningen för alla fyra slag, texten på sv och en).
- **Verifierat live** (kevin-live 45016442186 efter deploy 370, krediterna fortfarande slut), 4 av 4:

  | Anrop | Språk | Svar |
  |---|---|---|
  | `/exam` drill | en | 503 `provider_quota`, "EarMind is down for a moment. Try again later.", `fallback: true` |
  | `/exam` drill | sv | 503 `provider_quota`, "EarMind är nere en stund. Försök igen senare.", `fallback: true` |
  | `/answer` | en | 503 `provider_quota`, den engelska texten, `fallback: true` |
  | `/answer` | sv | 503 `provider_quota`, den svenska texten, `fallback: true` |

  Anropen slutar före något modellarbete, så de kostade inget.

## Appen och webbetan (rad till Angela Schrute)
- **Webbetan** visar serverns `message` som den är, så den blir begriplig nu. Mitt förslag är ändå en egen text för alla `provider_*`-koder.
- **iOS-appen:**
  - Svaren går på koden, och appen säger "Jag kan inte svara just nu, försök igen om en stund."
  - Ett nekat prov visar serverns `message`. Appen bör skicka `x-earmind-lang` så att texten följer valet och inte telefonens språk.

## Kvar
- Krediterna själva är Arons: console.anthropic.com › Settings › Billing, och Settings › Limits.
- När de finns igen kör jag `k118-live.py` (svaret på testfrågan) och `o97-live.py`. Det senare säger 200 när allt fungerar.
