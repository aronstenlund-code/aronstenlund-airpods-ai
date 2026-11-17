# Kevin (moln): K85 – täckningens placering och spridning (Oscar O73 del 2) – 2026-11-17 00:40

**(1) Placeringen, rättad.** `placeQuestions` (`exam/coverage.ts`) viktar nu orden efter hur ovanliga de är bland delarna (TF-IDF), i stället för rå ordöverlapp. Ett ord som alla delar har ("energi") avgör aldrig delen, och ett ord som bara en del har ("Newton") väger tyngst. Det var troligen därför servern räknade 6/6 där Oscar fick 4–5/6: en fråga med ett vanligt ord placerades i fel del, och den del som egentligen saknade fråga fick ingen. Svaren finns inte i steg 1 (appen hämtar dem efteråt med `drill_answers`), så bara frågan används, men med vikterna. Test: `exam/coverage_test.ts` "K85" ("energi" i alla delar avgör inte, "Newton" och "neutralisation" gör det, en fråga med bara gemensamma ord placeras ingenstans och räknas därför inte som täckning). `deno task test` grön. **untested assumption** att det ger Oscars siffra, tills han kör om `o73_coverage_live.py`.

**(2) Spridningen (10/1/1), inte ändrad.** D206 kräver minst en fråga per del, och det håller nu. "Högst hälften från en del när det finns tre eller fler delar" är en ny regel och Deangelos beslut. Den är lätt att bygga i `mergeCoverageParts` (samma ställe som väljer vilken fråga som ger plats) om Deangelo säger ja.

**(3) 6 frågor när 12 begärdes, inte ändrat.** Det är D159: steg 1 ger aldrig fler frågor än modellen säger att materialet bär (`questions_possible`), och svaret har då `note: "Materialet räckte till 6 frågor."`. I hopsatta material om tre ämnen kan modellen bedöma det lågt. Ska taket i stället vara minst ett visst antal per del eller per 1 000 tecken, är det också ett beslut för Deangelo.

Omtest: Oscar med `oscar-live.yml` och `o73_coverage_live.py` (cirka 0,03 USD, 0 ElevenLabs).
