# Kevin – D62 serverdel för demosidan (klar i kod, ej driftsatt)

## Gjort (alla tester gröna: 186, `check` och `e2e` rena; allt pushat)
1. **Väntelista.** `POST /waitlist` (publik, `verify_jwt` av): e-postvalidering, `consent:true` krävs, honeypot-fält `website`, max 5/timme och 20/dag per nätverk (hashad IP), globalt 2000/dag, dubblett tas emot tyst (svaret avslöjar inte vilka som står på listan). Migration `20261106130000_waitlist.sql`: tabellen `waitlist` (email unik + gemener, created_at, source, consent_at, consent_version). RLS på **utan någon klientpolicy**: en direkt insert-policy hade kringgått validering, samtycke och gräns, så bara funktionen (service role) skriver och ingen kan läsa.
2. **Demoskydd.** `source:"demo"` i `/answer` och `/tts` (body) och `/stt-token?source=demo`: 5 frågor/besökare/dag, 2000 tecken röst, 8 STT-token; per nätverk 20 / 8000 / 30; globalt tak 600 / 60000 / 400 (justerbart via env). Besökare = sidans anonyma användare, nätverk = hash av IP, så att rensa webbläsaren nollställer inte. Demo = bara Haiku (standardmodellen), ingen webbsökning, inget Rizz/intervju/tutor/auto (`403 demo_unavailable`), minnen och kommandon ignoreras, svar kapas vid 400 tecken (160 tokens, ingen sammanfattningsrad), röst max 400 tecken per anrop och bara standardröst/-modell. Taket ger **429** `demo_limit_visitor|ip|global` med svenskt meddelande som sidan kan visa som det är, plus `Retry-After`. Limitern nere ger 503 (stänger).
3. **CORS.** Allow-list i stället för `*`: `https://aronstenlund-code.github.io`, `localhost`/`127.0.0.1` på valfri port, och ytterligare adresser via secret `CORS_ORIGINS`. Appen skickar ingen Origin och påverkas inte. Gäller alla funktioner.
4. **README** (Context för Pam): `backend/README.md` > *Public demo page: contract for the site*, med inloggning, alla anrop, fält, felkoder och tak. Beslut D60 (D62 är ägarens).

## Vad som återstår: driftsättning (blockerad)
`supabase-lumen` kan inte ansluta: miljöns nätverksfilter svarar "Proxy refused to open a tunnel" mot `mcp.supabase.com`. Jag har lagt till `mcp.supabase.com` bland miljöns tillåtna domäner (en ändring du fick godkänna), men den redan misslyckade anslutningen återupptas inte av sig själv. **Gör så här:** kör `/mcp`, välj `supabase-lumen` och *Reconnect* (om den ber om inloggning: *Authenticate*), eller starta om sessionen. När den är uppe gör jag, utan fler frågor:
1. Migrationerna `20261106120000_feedback_and_shared_history.sql` (D57) och `20261106130000_waitlist.sql` (D62).
2. Driftsätter `answer` (nu med demoläge, rapportkommando, formelrättning), `tts`, `stt-token`, `voices`, `usage-stats`, `feedback`, `shared-history`, `feedback-admin` (alla får CORS-omslaget) och `waitlist` (`verify_jwt:false`).
3. Verifierar live: anonym inloggning, 6 demo-frågor (den sjätte ger 429), ett TTS-anrop på 401 tecken (413), väntelista (giltig, dubblett, utan samtycke), CORS-preflight från GitHub Pages-adressen.
Tills dess kör **inte** demosidan mot backend: de gamla funktionerna saknar `source`-fältet (de ignorerar det, så det finns **inget tak** på dem).

## Risker
- Inget av detta är kört mot riktig drift ännu (**untested assumption** utöver enhetstesterna). Stämmer GitHub Pages-adressen inte (annan användare/anpassad domän) måste den läggas i `CORS_ORIGINS`.
- Dagsfönstren är UTC-dygn (nollställs 01:00/02:00 svensk tid).
- Kostnad i värsta fall per dygn: 600 Haiku-svar (<1 USD) + 60000 TTS-tecken + 400 STT-token.
