# Överlämning Toby (apptest), 2026-11-11 12:05
Sessionen (start 10:15, molnet, Linux) gjorde T5b, T7b, T8b och A50-rundan. Kvar i kön: T10:s telefonsteg (Aron).

## Det som inte står i rapporterna
- **Ingen GitHub-token i molnsessionen** (`gh` ogiltig, `git credential fill` nekas). Läsning går ändå utan token:
  `curl https://api.github.com/repos/<repo>/actions/runs/...`, `/jobs/<id>/logs` och `/artifacts/<id>/zip` (med `-L`).
  `workflow_dispatch` går **inte**. Starta därför körningar med en push till `toby/**` som rör flödets sökvägar.
  - På egen gren: retest kör `fragor,block`, firstuser kör `skip` och skärmturen bara två lägen (pro-light och mikrofon nekad).
  - En push som rör `Screens/**` startar både skärmturen och firstuser. Concurrency avbryter den förra körningen på samma gren.
- **Pusha aldrig om en rebasad gren** (det kräver force). Slå ihop main i stället: `git merge origin/main`.
- **Klockan:** containern går på UTC. Svensk tid = UTC + 1. Tavlan skrivs i svensk tid.
- **Appens logg i UI-test:** `firstuser.sh` startar `simctl spawn log stream` med `private_data:on` och sparar
  `logs/<väg>-app.log`. Det fungerar och visar klartext. Bygg in samma sak i `screens.sh` om turen behöver den.
- **Lyssnar visar gamla sessioners svar.** Räkna alltid *nya* svar (antal etiketter före/efter), aldrig "texten finns".
- **Samma fråga i en ny session kan hoppas över**, och en fråga efter ett svar kan bli liggande (fynd 1). Därför har
  firstuser två frågor i slingan. Slingan: lead 6 s + 20 s paus, så första frågan kommer cirka 26 s efter att
  sessionen startat.
- **Retest-blocket (Provläge) kör med talet av** (`speak: false`): "uppläst 0" är väntat. Turen "avsluta" i b2 är
  testets `endSession()`.
- **T7b:** "Efter ordet"-tiden går att läsa ur `Turn timing` (`heard→call`) i `more.json`.

## Öppna trådar
- Kör om förstagångstestet, T5b och T7b när Angela har rättat fynden (rapporterna 1045 och 1200). Det kostar några
  hundra ElevenLabs-tecken och några minuter Scribe per körning.
- Den nattliga skärmturen på main (03:30) tar alla sju lägen med A50-stegen. Läs den i morgon, särskilt SE och
  största text: får Starta Lumen och lägesraden plats?
- Oro (skriven i båda rapporterna): A49 Sömnläge sparar ljud i 30 dagar; fynd 1 sparar en "röstprofil" utan avsikt.
- Grenen `toby/t5b-t7b-t8b-2` är flyttad till main (bara mina filer).
