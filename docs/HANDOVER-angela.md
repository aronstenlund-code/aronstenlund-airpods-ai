# Överlämning: Angela (app), 2026-11-09

Sessionen gjorde 11 punkter: A8, A6, A7, A10, A11, A9, A12, A14, A13, A15 och A17. Nästa i kön är A21 (Tobys
T5-fynd), sedan A18 och A20. Läs rapporterna i `reports/2026-11-09-angela-*.md`.

## Det här står inte i rapporterna
- **Ingen Mac.** CI är kompilatorn (`ios-build.yml`). Push → vänta ungefär 15–25 min.
  - Hjälpskript: `ghapi.sh` och `waitrun.sh` (token via `git credential fill`). Se minnet `lumen-project-setup`.
  - En ny push avbryter körningen som pågår. Vänta därför på grönt innan du pushar nästa.
- **Inline-Python i bash-heredoc** förstör `\(` och `\.` ibland. Skriv redigeringsskript med Write-verktyget och kör
  `python -I fil.py "$(pwd)"`.
- **Swift 6-fällor som kostade en CI-runda var:**
  - `static let` i en `@MainActor`-klass som används från en vanlig enum måste vara `nonisolated`
    (`PreferenceStore.limit`, `CommandPhraseStore.phraseLimit`);
  - testsviter som anropar `CloudAnswerProvider.encodeBody` måste vara `@MainActor`;
  - kolla namnkrockar: `FlowChips` och `FlowLayout` fanns redan i AddExamView.
- **Delad utcheckning.** Kevin, Deangelo och andra pushar hela tiden. Stagea bara egna filer, gör `git pull --rebase
  --autostash` före push, och kontrollera `git status -sb` efteråt.
- **Skärmbilder:**
  - `screenshots.yml` tar indatat `device` ("iPhone 17 Pro" / "iPhone SE (3rd generation)"). Det går att köra
    parallellt per enhet och tar cirka 25 min.
  - Tobys T3 tar över en timme och avbryts ofta.
  - Scenerna finns i `ScreenshotStage.swift`.
- **Kommandotabellen** (`CommandRegistry.swift`) är den enda källan. VoiceChannel, VoiceCommand, tipsen och skärmraden
  läser `CommandBook.shared`. `docs/COMMANDS.md` ska följa med varje ändring.
- **Turtabellen** (`controller.turns`, A8) i Diagnostik-exporten är det bästa sättet att se varför en fråga inte fick
  svar.

## Öppna trådar
- **Inget är verifierat på enhet**, från A8 till A17.
  - Aron behöver testa Frågor (paus mitt i en fråga), Provläge (flera frågor i ett andetag), "igen", "Mer?" och
    Spotify.
- **A15:** "ja" hämtar det långa svaret som "utveckla" tills Kevins K13 ger ett cachat svars-id och /memory-signaler.
  Byt i `takeMore` när det finns.
- **A10:** har ingen ljudmätning än. Oscar och Toby är ombedda: regeln står i A10-rapporten.
- **A6:** Spotify behöver hemligheten `SPOTIFY_CLIENT_ID` (Aron, stegen står i A6-rapporten). Frågan om Lumen ska
  lyssna efter "Lumen" medan musiken spelar (orange prick) väntar på Aron.
- **A8:** Frågor svarar nu bärarens röst, vilket ändrar D81. Deangelo får bekräfta.
- **A13:** `IntroElias`-bilden väntar på Aron. Justera `IntroHeroView.ringOrigin` när den kommer.
- **Tobys runda behöver nya steg:** "Avancerat" i Inställningar, "Fler lägen" på Start och nya texter. De står i
  A13-rapporten.
