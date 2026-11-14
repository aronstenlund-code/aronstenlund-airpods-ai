# Överlämning: Deangelo (projektledare), 2026-11-14 13:40

Läs först: `CLAUDE.md`, `docs/STATUS.md`, `prompts/queue/BOARD.md`, köfilerna i `prompts/queue/`, `docs/design/repetitionslage.md` och de senaste besluten i `docs/DECISIONS.md` (D142–D173).

## Läget
- **Earmind** (förr Lumen). Huvudprodukten är **repetitionsläget** (D142–D146): man fotar eller klistrar in material, får korta frågor med kort svar och långt A+-svar, trycker på Starta prov och lyssnar i AirPods. 1 tryck = långt svar, 2 = kort, 3 = paus, och valfritt tryck fortsätter från början av meningen (D164, D165). Ingen musik.
- **Lyssnande lägen är BETA.** Väckningsord: Lumen och Earmind, med felhörningar (D172, A97).
- **Klart och grönt:**
  - Apple-design (A87)
  - Publicera prov och sök på skola (A83)
  - Röstval A/B/C, tempo och kvot på 15 frågor per månad (A84, D155)
  - Årskurs (A88)
  - Första starten (A94)
  - "Gör med ChatGPT" och import (A93, K58)
  - Hjälp-AI (A92, K57)
  - Spela in eget svar i två steg (A98)
- Senaste ipa: iOS build 43582585113. Nyare kommer när A95, A96 och A98 är byggda.
- **Priser** (byggs inför App Store, inte nu): D157 tokens, D158 belöningshjul (aldrig köpbart), premium 65 kr/mån.
- **Supabase Free:** lagring tar slut först (cirka 10 MB per prov, 1 GB). Kevin rapporterar varje morgon (K59).
- **Arons Claude-gräns:** cirka 33 % använt lördag 14 nov, nollställs fredag kl. 16.

## Sessionerna
| Session | Modell/effort | Gör |
|---|---|---|
| Angela Schrute | Opus 5.5, high | Appens logik |
| Angela Fable | Fable 5.2, high | Bara vyer i repetitionsflödet och Apple-design |
| Kevin Malone | Opus 5.5, medium | `backend/` |
| Oscar Martinez | Opus 5.5, medium | Testar backend |
| Kelly | Opus 5.5, medium/high | Design, demosidan (utkast, inget publicerat) |
| Toby – BETA (Toby 1) | Opus 5.5, medium | Testar lyssnande lägen |
| Toby – Repetition (Toby 2) | Opus 5.5, medium | Testar repetitionsläget |
| Ryan | | Annonser, väntar på Arons budget |

Alla bevakar sina köer var 20:e minut. Tavlan har en rad per session.

## Hur Aron vill ha det
- Svara på **svenska**, kort. Detaljerna skrivs i repot.
- Märk tekniska påståenden: möjligt, möjligt med begränsningar, inte möjligt med nuvarande teknik eller ej verifierat.
- Prompter till sessioner:
  - Börja aldrig med "Du är …" till en session som redan kör.
  - Ange alltid effort.
  - Skriv ut hela prompten.
  - Säg alltid **vilken Angela** (Schrute eller Fable).
- **Öppna sidor åt Aron** i webbläsaren när han behöver göra något själv.
- **Skicka prompter själv** via claude.ai/code i webbläsaren när Aron ber om det ("kolla och prompta"):
  1. Öppna sessionen i listan till vänster.
  2. Kontrollera att modell och effort (nere till höger) är det du rekommenderar.
  3. Klicka i rutan "Type / for commands", skriv, kontrollera med `document.activeElement` att texten hamnade rätt, och tryck Enter.
  4. Börja meddelandet med "(Från Deangelo, skickat på Arons uppdrag.)".
  5. Om webbläsaren loggas ut: skriv aldrig i inloggningsfältet, be Aron logga in.
- **Inga automatiska bevakningsrundor** (send_later eller schemalagda uppgifter). Det blir för dyrt. Aron ber själv om en genomgång.
- Fråga inte om nya sessioner bara för att kontexten är låg. Aron ser den.
- Gratis bygge till telefonen: GitHub Actions "iOS build" → artifact **Lumen-unsigned** → Sideloadly på datorn. En installation gäller i 7 dagar.

## Öppet hos Aron
- Till Aron #15 (ElevenLabs-behörighet för K6) väntar. Inte viktigt nu.
- Arons test av senaste bygget på telefonen med Tobys checklista (`docs/TEST-ARON-REPETITION.md`).

## Så jobbar du
1. `git pull`, läs `BOARD.md` och `git log --since` för de senaste timmarna, och läs nya rapporter.
2. Fynd blir köpunkter hos rätt session. Oscar och Toby ändrar aldrig kod.
3. Arons beslut blir nya D-nummer. Kontrollera att numret är ledigt först (`grep "^| D" docs/DECISIONS.md | tail`).
4. Pusha med Co-Authored-By och Claude-Session.
5. Ge Aron kort status och exakt vad som ska skickas till vem, eller skicka det själv om han ber om det.
