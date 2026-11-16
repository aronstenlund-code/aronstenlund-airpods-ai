# Kevin (moln): K84 – fetch-url, IPv6-skrivsätt och DNS inom tidsgränsen (Oscar O73) – 2026-11-17 00:05

**Fyndet:** `publicIp` (`fetch-url/guard.ts`) räknade `::ffff:0:7f00:1` (IPv4-översatt, `::ffff:0:0/96`) och `2002:7f00:1::` (6to4) som publika. Live försökte funktionen ansluta (inget internt nåddes). Dessutom låg DNS-uppslagen (2 × 3 s per hopp) utanför 10-sekundersgränsen.

**Rättat:**
- Den inbäddade IPv4-adressen bedöms för `::ffff:0:0/96` och för 6to4 `2002::/16` (grupp 1–2). 6to4 för en publik IPv4 är fortfarande publik.
- Teredo `2001::/32` och discard-prefixet `100::/64` stoppas alltid.
- `checkResolved` och DoH-uppslaget får hela anropets `deadline` (högst 3 s per uppslag och aldrig efter 10 s totalt).
- Test: fem nya SSRF-fall i `fetch-url/handler_test.ts` (`::ffff:0:7f00:1`, `2002:7f00:1::`, `2002:a9fe:a9fe::` (metadata via 6to4), Teredo, `100::1`), och 6to4 av en publik adress är tillåten. `deno task test` grön. Oscars `scripts/qa/o73_fetch_url_test.ts` går 11/11, fall 3 inräknat. Skriptet har ett typfel på rad 125 (Oscars fil), så det körs med `--no-check`.
- Omtest live: Oscar med `oscar-live.yml` och `o73_fetch_live.py`.
