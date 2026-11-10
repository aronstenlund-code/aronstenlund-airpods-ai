# Kelly Ke23: namn och logga (2026-11-10 19:32)

## Vad som gjordes
- `docs/design/namn.md`: de fyra namnkandidaterna (D117) med kontroll i App Store, TMview (EUIPO, PRV m.fl.) och DNS,
  risker som inte syns i registren, rangordning och en tabell över Arons sex ChatGPT-symboler.
- `docs/design/namn/namn-tavla.jpg`: varje namn ihop med symbol 1–6 på en hemskärm (JPEG efter del 2, eftersom PNG med palett tog bort färgen på prickarna).
- `docs/design/namn/storlekar.png`: symbol 1–6 i 29 pt (Inställningar) och 60 pt, ljust och mörkt. Det är underlag
  för Arons val i Ke24.
- Källa för bilderna: `docs/design/_src/namn.html`. Ikonerna är utklipp ur `logo/chatgpt-forslag-2026-11-10.jpg` och
  har inte ritats om (Ke24 väntar på Arons nummer).

**Avvikelse från punkten:** Ke23 bad om namnen ihop med loggorna A, B och C. Aron har avvisat A/B/C (Ke24), så jag
använde hans sex ChatGPT-förslag i stället.

## Resultat (sökt 2026-11-10, **verifierat i källorna nedan**, ingen juridisk bedömning)
| Namn | App Store SE/US | TMview | Domän |
|---|---|---|---|
| Proviska | ingen app | 0 träffar | `.com` registrerad av någon (Namecheap), `.se` utan poster |
| Testvisk | ingen app | 0 träffar; TESTVISION (Teelen, Benelux, klass 9, giltig till 2029) är lik | `.se` och `.com` utan poster |
| Pod Whisper | ingen app | inget exakt | `podwhisper.com` upptagen |
| Whisper Pod | ingen app | inget exakt | `.com`, `.app` och `.se` utan poster |

- "Pod": Apple bestrider -POD-namn (PODSHEDZ, HOLOPOD, THERIGHTPOD; förlorade MATEPOD i Kina). **Verifierat i
  nyhetskällor**, inte i TTAB-akterna.
- "Whisper": OpenAI har en väntande ansökan WHISPER i USA (97815511, klass 9/42). **Verifierat bara på
  aggregatorsidor**, inte i USPTO TSDR.
- Att en domän saknar DNS-poster betyder oftast att den är ledig: **ej verifierat** hos registrar.

Källor: iTunes Search API, tmdn.org/tmview (i den inbyggda webbläsaren, eftersom API:t spärrar skript),
`nslookup -type=NS` mot 8.8.8.8, webbsökning om Apples POD-tvister och OpenAIs WHISPER.

## Rekommendation
- **Namn:** 1 Proviska, 2 Whisper Pod, 3 Pod Whisper, 4 Testvisk. Skälen står i `namn.md`.
- **Symbol:** 4 (bock med ljudvågor). Den syns tydligt i 29 pt och liknar inga andra kända ikoner.
  2 och 6 ser ut som Gemini och den vanliga AI-gnistan, och 3 liknar Apples Meddelanden.
  1 och 5 flyter ihop i 29 pt.

## Test
- Bilderna renderades i Chrome headless (Familjen Grotesk från `site/fonts/`) och granskades visuellt.
- Ingen appkod eller `site/` ändrad. ElevenLabs: 0 tecken. API: 0 USD.

## Risker och begränsningar
- Snabbkoll och ingen fullständig sökning. Lika namn som stavas annorlunda kan finnas i klass 9/41/42.
- 29 pt är ritat i 1x CSS-pixlar. På telefonen (3x) blir det skarpare, men formen avgör läsbarheten.

## Concerns
- Proviska och Testvisk (och delvis "Whisper") kan läsas som "viska på provet". Det krockar med reglerna för
  marknadsföringen (inget om fusk, R6). Jag rekommenderar ändå Proviska, eftersom registren är rena, men Aron bör
  väga in det.

## Till Aron
1. Välj namn (rekommenderar Proviska) och kolla om `proviska.com` är din.
2. Välj symbol 1–6 för Ke24 (rekommenderar 4). Bilden `docs/design/namn/storlekar.png` visar alla i liten storlek.
3. Låt ett ombud titta på det valda namnet innan det registreras, särskilt om det innehåller "Pod" eller "Whisper".

## Nästa
Ke24 väntar på Arons nummer. Jag tar Ke25 (App Store-sidan).

---

## Del 2 (20:20): Earwise, Earmind, Earpiece AI (D122)
Deangelo lade till namnen i Ke23 19:57, medan del 1 pågick. De finns nu överst på tavlan och i `namn.md`.

| Namn | Resultat | Bedömning |
|---|---|---|
| Earwise | App Store: "EarWise: Ear Training" finns. earwise.se är en hörselklinik i Göteborg och earwise.app en uppläsningsapp. .com är till salu och .ai upptagen. EUIPO: inget exakt, GEARWISE (svenskt, klass 9) | **Rött** |
| Earmind | App Store: inget. EUIPO: inget exakt (ClearMind/BEARMIND liknar). .com och .ai upptagna, .app och .se utan DNS-poster | **Grönt till gult**, bäst av de nya |
| Earpiece AI | earpieceai.com är en AI-produkt för samtal i örat. Ordet är beskrivande. EUIPO: HEARPIECES, Spy Earpiece | **Rött** |

- **Verifierat i källorna:** App Store via iTunes Search API, EUIPO eSearch (en omladdning per sökning, eftersom
  sidan annars visar förra resultatet), domänernas DNS och startsidornas titlar.
- **Ej kontrollerat:** PRV (svenska nationella märken) och USPTO för del 2. TMview spärrade sessionen
  ("Problem detected") efter del 1, och jag försökte inte ta mig förbi spärren. För USA finns bara
  aggregatorsidor: EARWISE AUDIOLOGY avregistrerad 2002, EARWEISS väntande.
- **Del 1 är fortfarande giltig:** de positiva träffarna i TMview (PROVISKIN, TESTVISION, "whisper pod") kom
  mellan nollresultaten, så sökningen fungerade då.

### Till Aron (ersätter punkt 1 ovan)
1. **Rekommenderar Earmind** i stället för Earwise. Earwise används redan av en svensk hörselklinik och av en
   app i App Store. Proviska är reserv om namnet ska vara svenskt och handla om plugg.
2. Innan namnet bestäms: sök i PRV:s varumärkesdatabas och hos ett ombud. Jag kunde inte göra det i natt.
