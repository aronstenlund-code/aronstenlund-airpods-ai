#!/usr/bin/env python3
"""K48 (D144, D146): blind test of ElevenLabs voice models for Repetitionsläget.

The same three Swedish sentences (one with subject terms, one with numbers, one long) from an invented A answer are
read by the app's default voice with Multilingual v2, v3 and Flash v2.5 through /voice-lab "sample" (service role,
run by the "Voice blind test" workflow). The three files get shuffled names A, B and C; which is which goes ONLY to
FACIT.md (for Deangelo). About 1 500 ElevenLabs characters in total (budget <= 3 000, D146).
  python3 scripts/k48-blindtest.py --out docs/rost-blindtest
Needs SUPABASE_SERVICE_ROLE_KEY."""
import argparse, base64, datetime, json, os, pathlib, secrets, sys, urllib.error, urllib.request

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
MODELS = ["eleven_multilingual_v2", "eleven_v3", "eleven_flash_v2_5"]
NAMES = {"eleven_multilingual_v2": "Multilingual v2", "eleven_v3": "Eleven v3", "eleven_flash_v2_5": "Flash v2.5"}
# Invented A answer (Biologi, åk 8), numbers written as words as the drill pipeline sends them (D46, toSpeech).
SENTENCES = [
    "Fotosyntesen sker i kloroplasterna, där klorofyllet fångar ljusenergi så att växten kan bygga glukos av koldioxid och vatten.",
    "Formeln är sex koldioxid plus sex vatten ger en glukos och sex syre, och klorofyllet tar främst upp ljus mellan fyrahundra och sjuhundra nanometer.",
    "Eftersom växterna bildar både det syre vi andas och det socker som andra organismer lever av, är fotosyntesen grunden för nästan alla näringskedjor på jorden, och utan den skulle varken djur eller människor kunna leva här.",
]
TEXT = " ".join(SENTENCES)
MAX_TOTAL = 3000


def call(svc: str, model: str) -> dict:
    req = urllib.request.Request(URL + "/functions/v1/voice-lab", method="POST",
                                 data=json.dumps({"action": "sample", "text": TEXT, "model": model}).encode(),
                                 headers={"authorization": "Bearer " + svc, "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="docs/rost-blindtest")
    a = ap.parse_args()
    svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not svc:
        print("SUPABASE_SERVICE_ROLE_KEY missing")
        return 1
    assert len(TEXT) * len(MODELS) <= MAX_TOTAL, "over the character budget"
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    order = MODELS[:]
    secrets.SystemRandom().shuffle(order)
    rows = []
    for letter, model in zip("ABC", order):
        try:
            j = call(svc, model)
        except urllib.error.HTTPError as e:
            print(f"{letter}: HTTP {e.code} {e.read()[:300].decode('utf-8', 'replace')}")
            return 1
        (out / f"{letter}.mp3").write_bytes(base64.b64decode(j["audio_base_64"]))
        rows.append((letter, model, j.get("chars"), j.get("character_cost")))
        print(f"{letter}: ok, {j.get('chars')} characters")  # never the model here: the log is public
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    total = sum(r[2] or 0 for r in rows)
    usd = sum((r[2] or 0) / 1000 * (0.04 if "flash" in r[1] else 0.08) for r in rows)
    (out / "README.md").write_text(
        "# Blindtest av röstmodeller (K48, D146)\n\n"
        f"Gjort {now}. Samma tre meningar, samma röst (appens standardröst) och samma format (mp3, 44,1 kHz, 128 kbit/s) "
        "i tre filer. Bara röstmodellen skiljer.\n\n"
        "Lyssna på `A.mp3`, `B.mp3` och `C.mp3` och säg vilken du tycker låter bäst, och om du hör skillnad alls. "
        "Vilken modell som är vilken står i `FACIT.md`, som bara Deangelo läser innan du har valt.\n\n"
        "## Texten\n\n" + "\n".join(f"{i}. {s}" for i, s in enumerate(SENTENCES, 1)) + "\n",
        encoding="utf-8")
    (out / "FACIT.md").write_text(
        "# FACIT (bara Deangelo, visa inte Aron förrän han har valt)\n\n"
        "| Fil | Modell | Tecken | Debiterat enligt ElevenLabs (`character-cost`) | Listpris (USD) |\n|---|---|---|---|---|\n"
        + "".join(f"| {l} | {NAMES[m]} (`{m}`) | {c} | {cc if cc is not None else 'okänt'} | {(c or 0) / 1000 * (0.04 if 'flash' in m else 0.08):.3f} |\n" for l, m, c, cc in rows)
        + f"\nTotalt {total} tecken, cirka {usd:.2f} USD efter listpris (0,08 USD per 1 000 för v2/v3, 0,04 för Flash). Gjort {now}.\n",
        encoding="utf-8")
    print(f"total {total} characters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
