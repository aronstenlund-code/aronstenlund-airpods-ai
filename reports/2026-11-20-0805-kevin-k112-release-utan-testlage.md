# K112 (D227, Deangelo 2026-11-20 07:58): servern i Release utan testläge

Kevin (moln), 2026-11-20. **0 ElevenLabs, 0 Claude.** Tester: **788/788**. Commit 40cdf2be, deploy-backend 351 grön. Parbeslutet (c) är noterat (D246): paren lämnas, och fallen ligger kvar som testfall.

## 1. Testkrokar som en granskare kan nå
- **Ingen.** Verifierat i koden.
- **Testläget slås på av servern bara i fyra fall** (`detectTest`). Inget av dem kan en granskare med Release-appen åstadkomma:
  - huvudet `x-earmind-test`, som Release-appen aldrig skickar (`TestTrafficHeader.value` är `nil` utan `DEBUG`);
  - ett konto märkt som test;
  - ett skript (python, curl och liknande) eller ett anrop utan user agent, medan appen skickar sin egen;
  - ett anrop från GitHub Actions IP-adresser.
- **Nytt test:** ett anrop med appens user agent och utan huvud är aldrig ett testanrop (`_shared/k112_release_test.ts`).
- **Testläget i appen (K43/A142)** och adressen `debug-audio` kompileras bara med `LUMEN_TESTMODE` (Debug och Beta). Release har det inte (`project.yml`).
  - Servern släpper bara in Aron och de testare han har slagit på. Alla andra får 403.
- **Övriga serverkrokar** gäller bara med testhuvudet:
  - modellvalet (K104 `model-haiku`/`model-sonnet`);
  - `slow`/`unavailable`;
  - att QA-mätningar får hoppa över kostnadsuppskattningen, vilket också kräver anrop från Actions.
- **Admin- och ägarfunktionerna** kräver ägarens e-postinloggning eller servicenyckeln: `real-users-admin`, `feedback-admin`, `voice-lab` och testläget i `debug-audio`.

## 2. Felmeddelanden som en granskare kan se, nu på svenska
- **Varför de syns:** appen visar serverns `message` för alla fel från `/drill` och för 4xx-fel från `/exam` (`DrillCloud.refusal`, `DrillServices.refusal`). Fyra texter var på engelska:

  | När | Förut | Nu |
  |---|---|---|
  | Oväntat fel (500) | "Internal error" | "Något gick fel hos EarMind. Försök igen om en stund." |
  | Utgången inloggning (401) | "Invalid or expired token" | "Inloggningen har gått ut. Försök igen." |
  | Ingen inloggning (401) | "Missing bearer token" | "Du behöver logga in igen." |
  | Word-fil över 10 MB (413) | "The document is larger than 10 MB" | "Word-filen är större än 10 MB. Spara den som PDF eller dela upp den." |
  | Ingen röst konfigurerad (503) | "No voice configured" | "Ljudet går inte att göra just nu. Försök igen om en stund." |

- **Kvar på engelska:** 400-fel som bara kommer när ett anrop har fel format, till exempel "items: at least one question". Release-appen skickar aldrig sådana anrop, så de når ingen granskare.
- **Team ID saknas:**
  - `welcome` svarar 503 "Välkomstkrediterna är inte på än." (`attest_unconfigured`).
  - `attest_challenge` svarar nu samma text i stället för "Inte tillgängligt än.".
  - Köp och prenumerationer behöver inte Team ID: kvittot kontrolleras mot bundle-id och Apples rötter.
  - I texterna förekommer inga ord som test, admin eller interna namn.
- **Verifierat live** (kevin-live 44691697742, efter deploy 351, 0 ElevenLabs och 0 Claude):

  | Fall | Svar |
  |---|---|
  | `/drill` utan inloggning | 401 "Du behöver logga in igen." |
  | `/drill` med en ogiltig inloggning | 401 "Inloggningen har gått ut. Försök igen." |
  | `/exam` utan inloggning | 401 "Du behöver logga in igen." |
  | `attest_challenge` | 503 "Välkomstkrediterna är inte på än." |
  | `welcome` | 503 "Välkomstkrediterna är inte på än." |

  Inga interna ord förekommer. Felet 500 och texten om Word-filen är verifierade i test.

## Till Angela Fable och Angela Schrute
Inget krävs. Koderna är oförändrade, och bara texterna är nya. Appen jämför inte mot de gamla engelska texterna (verifierat med grep).
