# Ke86: engelska texter, webbetans design, skärmraden och sajten på engelska (Kelly (moln), 2026-11-21, D249–D252)

**Publicerat: inget än.** Sajten på engelska ligger på grenen `kelly/ke86-site-en` och slås ihop när Angela Schrutes
webbeta finns i `site/beta/` (annars leder "Try the beta" till en tom sida). Ke78-sidorna rörs inte.

## 1. Engelska texter (D251) – `docs/design/engelska.md` (på main)
Ordlista (Say in AirPods, Play for 10 min, How should it sound?, Top up, Weekly pass, Quiz, Recent …) och alla texter
ur mina designdokument på engelska: första skärmen och Säg-kortet, stil och röster, krediter och köp (inkl. A154:s nya
rader och webbens "Purchases come with the iOS app"), VoiceOver. Stil: kort, sentence case, engelska tal (1,236 · 1.2k).
Angela Fable (A157) och Angela Schrute (A156) har fått raden i sina köer.

## 2. Webbetans design (D249/D250) – `docs/design/webbeta.md` + skiss `bilder/webbeta/` (på main)
- Tokens ur appens skärmbilder (bakgrund #f2f2f7, Säg-kortet #101319, accent #2346c8 / #7f9bff, tonad #d7def5), ljust och
  mörkt, typsnitt, hörn, mobil först.
- Första skärmen som appen, med Beta-etikett; krediter utan köp; lyssnarlägen med samtycke och indikator; Media Session.
- **Skärmraden** (sv/en): "Keep the screen on … Your phone can be up to about 10 m (33 ft) from your AirPods" – Apples
  siffra (**verifierat i dokumentation**, D250); Screen Wake Lock när något spelar eller lyssnar.
- **Guide för Automatisk låsning** (sv/en): iPhone Inställningar › Skärm och ljusstyrka › Automatisk låsning › Aldrig, och
  att **Strömsparläget låser efter 30 s ändå** (Apples dokumentation); Android Inställningar › Skärm › Tidsgräns för
  skärm (**untested assumption** för alla tillverkare).
- **iOS-appen med skärmen av:** raden är skriven men **visas inte förrän Aron provat på telefon** (D209, TILL-ARON #29).

## 3. Sajten på engelska (D251) – grenen `kelly/ke86-site-en` (commit 72d38b7)
- `/` engelska: "Learn it by listening.", **Try the beta** (två knappar till `/beta`), kortet "Try it in your browser" med
  skärmraden, How it works (fyra steg, Ke80-bilderna; noten säger att skärmbilderna är på svenska tills A157:s engelska
  finns), Free to start (1,500 i månaden, inga priser i kronor), väntelistan för iPhone-appen (samtyckesversion
  `2026-11-21-en`), vanliga frågor. Ingen livedemo: betan är den riktiga varan nu.
- `/sv` svenska: hela den gamla sidan med demon, plus **Prova betan** och länken English; hreflang och canonical på båda.
- `sitemap.xml` med `/`, `/sv`, `/beta`. `kelly-site-check.yml` kollar också `/sv` och `/beta`.
- **Kontroll lokalt** (Chromium, iPhone 15 393 px, ljust och mörkt): scrollWidth 393 på båda sidorna, ingen vågrät
  rullning. Bilder: `reports/2026-11-21-ke86-bilder/`. Live kontrolleras efter ihopslagningen.

## 4. TikTok-svar (sv/en) – `docs/design/webbeta.md` §8
Kort, med länken till /beta och "ha skärmen på i betan"; inget om låst skärm, pris eller välkomstkrediter.

## Kvar (Ke86 öppen till deployen)
1. När A156 ligger i `site/beta/` på main: slå ihop `kelly/ke86-site-en`, lägg till rewrite i `site/vercel.json` om betan
   är en SPA, snabbspola `kelly/ke66-earmind-site`, kör `kelly-site-check` (200, storlek, /sv, /beta) och kontrollera
   393 px live.
2. Byt skärmbilderna på den engelska sidan mot A157:s engelska när de finns.
