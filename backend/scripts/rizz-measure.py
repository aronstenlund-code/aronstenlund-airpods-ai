#!/usr/bin/env python3
"""Live measurement of Rizzläge / Socialt läge / calibration on the DEPLOYED /answer (D69).

Uses an anonymous Supabase session and the PUBLIC publishable key (both public by design, no secrets).
For every request: time to suggestion_preview and to suggestions, the options, done.usage (tokens, cache
read/write, est. cost) and done.calibration. Runs each scenario twice back to back so the second call
shows whether the system prompt is read from the prompt cache.

    python -I backend/scripts/rizz-measure.py [--style flirt|social|both] [--json out.json] [--quick]
"""
import argparse, json, sys, time, urllib.error, urllib.request

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design

# Own scenarios (not the owner's test lines). Several other speakers for Socialt läge.
SCENARIOS = [
    {"id": "fest-kok", "transcript": [
        {"speaker": "other", "text": "Jag brände pastan, alltså vem bränner pasta?"},
        {"speaker": "other", "text": "Och sen ställde jag den på fönsterbrädan som om det skulle hjälpa."}]},
    {"id": "jobb-fika", "transcript": [
        {"speaker": "other", "text": "Kaffemaskinen har varit trasig i tre dagar nu."},
        {"speaker": "user", "text": "Ja, folk börjar bli konstiga."},
        {"speaker": "other", "text": "Martin har börjat dricka te. Martin!"}]},
    {"id": "gym", "transcript": [
        {"speaker": "other", "text": "Jag har tränat i en månad och kan fortfarande inte göra en enda armhävning."}]},
    {"id": "tag-forsenat", "transcript": [
        {"speaker": "other", "text": "Tåget är fyrtio minuter sent igen, jag tror jag bor här nu."}]},
    {"id": "skidresa", "transcript": [
        {"speaker": "user", "text": "Hur var fjällen?"},
        {"speaker": "other", "text": "Jag åkte mest på rumpan, men utsikten var fin."}]},
]
CALIBRATIONS = ["lite mindre kaxig", "mer skämt, hon gillar fotboll"]


class Backend:
    def __init__(self):
        self.tok = self._post("/auth/v1/signup", {}, None)["access_token"]

    def _req(self, path, body, tok):
        h = {"apikey": KEY, "content-type": "application/json"}
        if tok:
            h["Authorization"] = "Bearer " + tok
        return urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h)

    def _post(self, path, body, tok):
        with urllib.request.urlopen(self._req(path, body, tok), timeout=60) as r:
            return json.load(r)

    def ask(self, body):
        t0 = time.time()
        out = {"preview_ms": None, "suggestions_ms": None, "options": None, "done": {}, "error": None}
        try:
            with urllib.request.urlopen(self._req("/functions/v1/answer", body, self.tok), timeout=60) as r:
                ev = None
                for line in r:
                    line = line.decode().rstrip("\n")
                    if line.startswith("event: "):
                        ev = line[7:]
                    elif line.startswith("data: "):
                        d = json.loads(line[6:])
                        ms = int((time.time() - t0) * 1000)
                        if ev == "suggestion_preview":
                            out["preview_ms"] = ms
                        elif ev == "suggestions":
                            out["suggestions_ms"], out["options"] = ms, d
                        elif ev == "done":
                            out["done"] = d
                        elif ev == "error":
                            out["error"] = d
        except urllib.error.HTTPError as e:
            out["error"] = {"http": e.code, "body": e.read().decode()[:200]}
        out["total_ms"] = int((time.time() - t0) * 1000)
        return out


def body_for(style, sc, calibration="", calibrate=""):
    s = {"style": style, "trigger": "other_spoke", "transcript": sc["transcript"]}
    if calibration:
        s["calibration"] = calibration
    if calibrate:
        s["calibrate"] = calibrate
    b = {"fragment": "", "mode": "tutor", "language": "sv", "persona": "social", "social": s, "context": {}}
    if style == "flirt":
        b["adult_confirmed"] = True
    return b


def line(tag, r):
    u = (r["done"] or {}).get("usage") or {}
    return (f"{tag:28} preview {r['preview_ms']!s:>5} ms  list {r['suggestions_ms']!s:>5} ms  "
            f"in {u.get('input_tokens')!s:>5} cache_r {u.get('cache_read_tokens')!s:>5} "
            f"cache_w {u.get('cache_write_tokens')!s:>5} out {u.get('output_tokens')!s:>4} "
            f"${u.get('est_cost_usd') or 0:.5f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", default="both")
    ap.add_argument("--json", default="")
    ap.add_argument("--quick", action="store_true", help="first two scenarios only")
    a = ap.parse_args()
    be = Backend()
    styles = ["flirt", "social"] if a.style == "both" else [a.style]
    rows = []
    scen = SCENARIOS[:2] if a.quick else SCENARIOS
    for style in styles:
        for sc in scen:
            for rep in (1, 2):
                r = be.ask(body_for(style, sc))
                rows.append({"style": style, "id": sc["id"], "rep": rep, **r})
                print(line(f"{style}/{sc['id']}#{rep}", r))
                if rep == 1 and r["options"]:
                    for o in r["options"]:
                        print("     -", o)
                if r["error"]:
                    print("     ERROR", r["error"])
                time.sleep(0.5)
    # calibration: instruction -> done.calibration, no suggestions; then apply it
    cal = ""
    for instr in CALIBRATIONS:
        r = be.ask(body_for("flirt", SCENARIOS[0], calibration=cal, calibrate=instr))
        cal = (r["done"] or {}).get("calibration") or cal
        rows.append({"style": "calibrate", "id": instr, "rep": 1, **r})
        print(line(f"calibrate '{instr}'", r), "| options:", r["options"], "| calibration:", repr(cal))
        time.sleep(0.5)
    if cal:
        for sc in SCENARIOS[:2]:
            r = be.ask(body_for("flirt", sc, calibration=cal))
            rows.append({"style": "flirt+cal", "id": sc["id"], "rep": 1, "calibration": cal, **r})
            print(line(f"flirt+cal/{sc['id']}", r))
            for o in r["options"] or []:
                print("     -", o)
            time.sleep(0.5)
    prev = [r["preview_ms"] or r["suggestions_ms"] for r in rows if r["style"] in ("flirt", "social")]
    prev = sorted(x for x in prev if x)
    if prev:
        print(f"\nfirst line: p50 {prev[len(prev) // 2]} ms, max {prev[-1]} ms, n={len(prev)}")
    second = [r for r in rows if r["rep"] == 2]
    hits = sum(1 for r in second if ((r["done"] or {}).get("usage") or {}).get("cache_read_tokens"))
    print(f"cache hits on repeat calls: {hits}/{len(second)}")
    cost = [((r["done"] or {}).get("usage") or {}).get("est_cost_usd") or 0 for r in rows if r["style"] in ("flirt", "social")]
    if cost:
        print(f"avg est. cost per suggestion request: {sum(cost) / len(cost) * 100:.3f} US cent")
    if a.json:
        json.dump(rows, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
