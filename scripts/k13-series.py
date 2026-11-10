#!/usr/bin/env python3
"""K13 series against the deployed backend (Provläge, two_level):
  1. learned length: q1 short + 'ja', q2 short + 'ja' -> q3 comes long at once (no short part); then 'kortare'
     -> q4 is short-first again. The app's part (keeping the settings, sending the signals) is simulated here.
  2. situation: the same 5 questions with and without 'others_talking': the answers are shorter when others talk.
  python -X utf8 -I scripts/k13-series.py --tokens FILE -> reports/eval/k13-series-<date>.json"""
import argparse, datetime, importlib.util, json, pathlib, re, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
D = load("demo", ROOT / "scripts/qa/demo.py")
SETUP = "Prov i Biologi på fredag (om 3 dagar). Årskurs: Åk 9. Ämne: Biologi. Förklaringar: mellanlånga förklaringar."
CTX = {"mode": "prov", "subject": "Biologi", "answer_type": "explanation"}


def answer(tok, q, settings, extra=None):
    b = {"fragment": q, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": SETUP, "context": {},
         "two_level": True, "pref_context": {"subject": "Biologi"}, **({"preferences": settings} if settings else {}), **(extra or {})}
    r = D.ask(tok, b)
    done = r.get("done") or {}
    return {"q": q, "status": r["status"], "short": r.get("text", ""), "more": done.get("more"), "first_ms": r.get("first_ms")}


def memory(tok, payload):
    o = D.call("POST", "/functions/v1/memory", payload, tok)
    return D.jbody(o) or {}


def words(t):
    return len(re.findall(r"\w+", t or ""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    a = ap.parse_args()
    tok = PE.signup(a.tokens, 2)
    out = {"series": [], "situation": []}
    settings = []
    for i, q in enumerate(["vad är osmos", "vad gör mitokondrien", "vad är diffusion"]):
        x = answer(tok, q, settings)
        x["step"] = i + 1
        out["series"].append(x)
        print("step", i + 1, x["status"], "short", words(x["short"]), "more", words(x["more"]), "|", x["short"][:100], flush=True)
        if i < 2:
            m = memory(tok, {"length_signal": {"signal": "yes", "context": CTX}, "settings": settings})
            settings = m.get("settings", settings)
            x["long_first_after"] = m.get("long_first")
    m = memory(tok, {"correction": {"text": "kortare", "context": CTX}, "settings": settings})
    settings = m.get("settings", settings)
    x = answer(tok, "vad är en cellvägg", settings)
    x["step"] = "after kortare"
    out["series"].append(x)
    print("after kortare", x["status"], "short", words(x["short"]), "more", words(x["more"]), flush=True)
    s = out["series"]
    out["series_ok"] = {
        "q1_two_level": bool(s[0]["more"]),
        "q2_two_level": bool(s[1]["more"]),
        "q3_long_at_once": not s[2]["more"] and words(s[2]["short"]) > max(words(s[0]["short"]), words(s[1]["short"])),
        "after_kortare_two_level_again": bool(s[3]["more"]),
    }
    for q in ["vad är fotosyntes", "vad är ett ekosystem", "vad gör röda blodkroppar", "vad är en gen", "vad är evolution"]:
        row = {"q": q}
        for k, extra in (("alone", {}), ("others", {"situation": {"others_talking": True}})):
            r = answer(tok, q, [], {"two_level": False, **extra})
            row[k] = words(r["short"])
            row[k + "_text"] = r["short"][:300]
        out["situation"].append(row)
        print("situation", q, row["alone"], row["others"], flush=True)
    sit = out["situation"]
    out["situation_ok"] = f"{sum(r['others'] < r['alone'] for r in sit)}/{len(sit)} shorter when others talk"
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    json.dump(out, open(ROOT / "reports" / "eval" / f"k13-series-{date}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps({"series_ok": out["series_ok"], "situation_ok": out["situation_ok"]}, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
