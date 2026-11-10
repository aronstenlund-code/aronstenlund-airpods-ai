#!/usr/bin/env python3
"""K4.3: real errors become test cases every night, without storing anyone's words.
The newest "det där var fel" reports (feedback type "report", at most 15, not yet processed) are asked again on the
deployed /answer and graded by Sonnet (provlage-eval "grade", the report's comment as what was wrong). Only numbers
are written (reports/eval/reported-<date>.json): how many reports, how many are now answered well; no fragment,
answer or comment text, ids hashed. The feedback rows themselves are deleted by the D80 retention (90 days).
Needs SUPABASE_ACCESS_TOKEN (the repo secret the deploy uses) to read the service key through the Management API;
without access it stops with a message and exit 0.
  SUPABASE_ACCESS_TOKEN=... python3 scripts/reported-cases.py"""
import datetime, hashlib, importlib.util, json, os, pathlib, re, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
REF = "xjczbzfkmbjdebwlccki"
URL = f"https://{REF}.supabase.co"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def get(url, headers):
    return json.loads(urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30).read())


def anonymize(t):
    t = re.sub(r"\S+@\S+", "[e-post]", t or "")
    t = re.sub(r"\+?\d[\d \-]{6,}\d", "[nummer]", t)
    t = re.sub(r"(?i)\b(jag heter|mitt namn är|heter)\s+\p{L}+" if False else r"(?i)\b(jag heter|mitt namn är)\s+\w+", r"\1 [namn]", t)
    return t


def main():
    tok = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not tok:
        print("no SUPABASE_ACCESS_TOKEN: skipped")
        return 0
    try:
        keys = get(f"https://api.supabase.com/v1/projects/{REF}/api-keys?reveal=true", {"authorization": "Bearer " + tok})
    except Exception as e:
        print(f"::warning::cannot read the service key with SUPABASE_ACCESS_TOKEN ({getattr(e, 'code', e)}): skipped")
        return 0
    svc = next((k.get("api_key") for k in keys if k.get("name") in ("service_role",) or k.get("type") == "secret"), None)
    if not svc:
        print("::warning::no service key in the Management API answer: skipped")
        return 0
    print("::add-mask::" + svc)
    rows = get(f"{URL}/functions/v1/feedback-admin?type=report&limit=40", {"authorization": "Bearer " + svc})
    rows = [r for r in rows if (r.get("status") or "new") != "processed" and (r.get("fragment") or "").strip()][:15]
    PE = load("pe", ROOT / "scripts/provlage-eval.py")
    users = [PE.signup(None, i) for i in range(2)]
    out = []
    for i, r in enumerate(rows):
        mode = r.get("mode") or "push_to_talk"
        body = {"fragment": anonymize(r["fragment"])[:500], "mode": mode if mode in ("tutor", "push_to_talk", "text", "auto") else "push_to_talk",
                "language": "sv", "persona": "tutor", "context": {}}
        a = PE.stream_answer(users[i % 2], "sonnet", body) if body["mode"] == "tutor" else None
        if a is None:  # not Provläge: the normal /answer
            D = load("demo", ROOT / "scripts/qa/demo.py")
            x = D.ask(users[i % 2], body)
            a = {"text": x.get("text", "")}
        case = {"grade": "", "subject": "", "kind": "reported", "profile": "", "context": [], "q": body["fragment"],
                "expect": "Användaren rapporterade att förra svaret var fel: " + anonymize(r.get("comment") or "")[:300]}
        g = PE.post(users[i % 2], {"action": "grade", "judge": "sonnet", "case": case, "answer": a.get("text", "")})
        out.append({"id": hashlib.sha256(str(r.get("id")).encode()).hexdigest()[:10], "mode": body["mode"],
                    "answered": bool((a.get("text") or "").strip()), "now_ok": g.get("first_answer_suffices") == 1,
                    "correct": (g.get("scores") or {}).get("correct")})
        print(out[-1], flush=True)
    s = {"reports": len(rows), "answered_now": sum(x["answered"] for x in out), "now_ok": sum(x["now_ok"] for x in out)}
    date = datetime.date.today().isoformat()
    json.dump({"summary": s, "rows": out, "note": "numbers only: no user text is stored (K4.3)"},
              open(ROOT / "reports" / "eval" / f"reported-{date}.json", "w", encoding="utf-8"), indent=1)
    print(json.dumps(s))
    return 0


if __name__ == "__main__":
    sys.exit(main())
