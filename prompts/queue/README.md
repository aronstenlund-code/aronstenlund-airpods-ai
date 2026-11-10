# Köer per session

En fil per session: `kevin.md`, `angela.md`, `oscar.md`, `kelly.md`. Deangelo och Aron lägger till punkter; sessionen själv ändrar bara status på sina egna punkter.

Arbetssätt för sessionen:
0. **Tavlan `prompts/queue/BOARD.md`:** uppdatera din egen rad (modell, effort, vad du gör, status, resultatet i en mening med siffror och tid) varje gång du tar en punkt, blir klar, fastnar eller väntar. Pusha den i samma commit som köändringen.
1. När en uppgift är klar och rapporten pushad: `git pull`, öppna din köfil.
2. Ta översta punkten med `[ ]`. Ändra till `[~] pågår <ÅÅÅÅ-MM-DD HH:MM>` och pusha.
3. Gör uppgiften enligt CLAUDE.md (rapport, STATUS, DECISIONS, push).
4. Ändra till `[x] klar <ÅÅÅÅ-MM-DD HH:MM> → <sökväg till rapport>` och pusha.
5. Beror punkten på något som inte är klart (står i punkten): hoppa till nästa och kom tillbaka.
6. Tom kö, eller bara punkter som väntar på andra: skriv "Väntar på kö" på din rad i `docs/STATUS.md` och pusha. Har du verktyget `send_later` (claude-code-remote), schemalägg meddelandet "kolla kön" till dig själv om 30 minuter. Gör det bara mellan 08 och 23, och sluta efter 4 tomma kontroller i rad. Då behöver Aron inte väcka dig. Annars: sluta.

7. **Kontext (lätt, läs aldrig om sessionen):** skriv i kolumnen *Kontext* på din tavelrad hur många punkter du gjort i den här sessionen, och "komprimerad" om sessionen har komprimerats. Vid 5 punkter eller efter en komprimering: skriv "byt snart" i kolumnen, gör klart pågående punkt, ta ingen ny, och skriv en kort `docs/HANDOVER-<namn>.md` (högst 30 rader: vad du lärt dig som inte står i rapporterna, öppna trådar). Deangelo ger Aron en startprompt för en ny session.

8. **Nattläge** (står överst på tavlan med en sluttid, Aron sover):
   - Jobba igenom kön utan att avsluta din tur mellan punkterna. Rapport, STATUS, kö och tavla pushas efter varje punkt som vanligt.
   - Tom kö eller bara punkter som väntar: ta din stående uppgift (`docs/PLAN.md` 2b), skriv den som en egen punkt i din kö och gör den.
   - Punkt 7 stoppar inte arbetet: skriv överlämningen när du når gränsen men fortsätt jobba. Efter **två** komprimeringar: gör klart pågående punkt och sluta (PLAN 2e).
   - Vänta aldrig på Aron. Det som är hans beslut skrivs under "Till Aron" i rapporten, och du tar nästa punkt.
   - Har du `send_later`: schemalägg "kolla kön" om 30 min innan du avslutar en tur, fram till sluttiden.
   - Kör du i molnet och ett verktyg saknas (simulator, gh, MCP): skriv det under "Till Aron" och ta nästa punkt som går att göra. Pusha alltid allt innan turen tar slut.
   - Fortfarande aldrig utan Aron (CLAUDE.md): radera data eller historik, force-push, betaltjänster eller köp, publicera (TestFlight/App Store), ändra kontoinställningar. API-kostnad i natt: högst 6 USD för Kevin och 2 USD för Oscar.

Ändra aldrig andras punkter eller andras köfiler. Effort står på varje punkt.
