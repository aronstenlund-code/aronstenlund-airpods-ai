# K51: aldrig fler frågor än materialet räcker till, och Arons misslyckade anrop 22:13 (Kevin, 2026-11-13 22:33)

## Arons anrop 22:12–22:13 (verifierat i Supabase-loggen)
Båda anropen kom fram till servern. Det var alltså inget nätverksfel, och "Ingen internetanslutning" var appens tolkning.

| Tid | Storlek | Svar | Tid i funktionen | Orsak |
|---|---|---|---|---|
| 22:12:31 | 2,5 MB (2 bilder) | 502 | 4,1 s | Modellen hittade inga frågor i bilderna (skärmfoton), och servern svarade `drill_unreadable` som ett serverfel. Ingen krasch loggades. |
| 22:13:31 | **13,9 MB** | 413 | 0,6 s | Appens nya försök skickade bilderna okomprimerade. Vår egen gräns är högst 3 MB per bild. Supabase släppte igenom 13,9 MB, så gränsen är vår och inte deras. |

- **Bildformat:** appen märker alla bilder `image/jpeg`. Är en bild egentligen HEIC skulle Claude neka den.
- **Till Angela:** allt står under A85 i `prompts/queue/angela.md`.

## Ändringar (driftsatta)
- **D159:** `drill` frågar modellen hur många frågor materialet bär (`questions_possible`) och gör aldrig fler. Svaret får `questions_asked`, `questions_possible` och `note` ("Materialet räckte till 4 frågor."). Svar görs bara för de frågor som blir, så inga extra Claude- eller ElevenLabs-anrop.
- **Oläsbart material:** ger nu **422** `drill_unreadable` med en svensk orsak från modellen, till exempel "Texten på bilderna går inte att läsa. Fotografera rakt ovanifrån i bra ljus, eller klistra in texten." Tidigare blev det 502.
  - Loggen får antal bilder, tecken, svarslängd och modellens orsak, aldrig materialet.
- **Bildformat:** det riktiga formatet läses ur bildens första byte. En felmärkt PNG eller WebP rättas, och HEIC, GIF och PDF ger **415** `unsupported_image`.
- **413-meddelandet** är på svenska.

## Tester
- `deno task test`: 539 gröna och `check` ren. Tre nya tester täcker D159 (bara 3 svar när materialet bär 3), 422 och bildformaten.
- Livetestet `scripts/k51-live.py` och `reports/eval/k51-live-2026-11-13.json` (**verifierat live**):

| Fall | Resultat |
|---|---|
| Kort text (3 meningar), 20 frågor begärda | **4 frågor**, "Materialet räckte till 4 frågor." |
| Fullt historieprov | 20 frågor, ingen not |
| HEIC märkt som JPEG | 415 med svensk förklaring |

## Kostnad
- **Claude:** cirka 0,005 USD (två Haiku-anrop utan svar).
- **ElevenLabs:** 0.

## Kvar
Angela A85: komprimera bilderna, visa serverns `error.message` och visa "Ingen internetanslutning" bara när nätet verkligen saknas.
