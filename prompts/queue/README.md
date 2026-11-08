# Köer per session

En fil per session: `kevin.md`, `angela.md`, `oscar.md`, `kelly.md`. Deangelo och Aron lägger till punkter; sessionen själv ändrar bara status på sina egna punkter.

Arbetssätt för sessionen:
1. När en uppgift är klar och rapporten pushad: `git pull`, öppna din köfil.
2. Ta översta punkten med `[ ]`. Ändra till `[~] pågår <ÅÅÅÅ-MM-DD HH:MM>` och pusha.
3. Gör uppgiften enligt CLAUDE.md (rapport, STATUS, DECISIONS, push).
4. Ändra till `[x] klar <ÅÅÅÅ-MM-DD HH:MM> → <sökväg till rapport>` och pusha.
5. Beror punkten på något som inte är klart (står i punkten): hoppa till nästa och kom tillbaka.
6. Tom kö, eller bara punkter som väntar på andra: skriv "Väntar på kö" på din rad i `docs/STATUS.md` och pusha. Har du verktyget `send_later` (claude-code-remote), schemalägg meddelandet "kolla kön" till dig själv om 30 minuter. Gör det bara mellan 08 och 23, och sluta efter 4 tomma kontroller i rad. Då behöver Aron inte väcka dig. Annars: sluta.

Ändra aldrig andras punkter eller andras köfiler. Effort står på varje punkt.
