"""K109 (D239, Oscar O90; Kevin moln 2026-11-19) live with a new test account (1 500 credits), 0 ElevenLabs:
(1) exam drill with 12 questions and drill_answers with 12 items are 402 before Claude (fast, `fits`, `estimated`,
the quota unchanged); a drill with 3 questions still works, and its real cost (drill action "cost", saves nothing) is
compared with the estimate; (2) purchase attest_challenge is 503 attest_unconfigured while the App ID is missing.
Claude: one 3-question exam (about 0.02 USD). Usage (kevin-live.yml): python -X utf8 scripts/k109-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, time, urllib.error, urllib.request  # noqa: E402
_s.path.insert(0, str(HERE / "qa" / "o79"))
_s.path.insert(0, str(HERE / "qa" / "repetition_bank"))
from o79_materials import O79  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")


def req(fn, body, tok, timeout=240, header=True):
    # header=False: the 402 checks go the user's way ("user-path"; from Actions the test header alone skips the
    # estimate, Oscar O91); still a test call (D180)
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    r.add_header("x-earmind-test", "kevin-k109" if header else "kevin-k109 user-path")
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=timeout) as x:
            st, j = x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            st, j = e.code, json.loads(raw)
        except ValueError:
            st, j = e.code, {"raw": raw[:200].decode(errors="replace")}
    return st, j, int((time.time() - t0) * 1000)


def remaining(tok):
    return req("drill", {"action": "quota"}, tok)[1].get("remaining")


ok, out = {}, {}
tok = T.signup()[0]
q0 = remaining(tok)
m = O79["o79-bi-ekosystem"]
full = "\n\n".join(f"{h}\n\n{p}" for h, p in m["parts"])
keep = ("status", "ms", "code", "message", "cost", "remaining", "fits", "per_question", "questions", "estimated")

st, j, ms = req("exam", {"action": "drill", "answers": False, "questions": 12, "subject": m["subject"], "pages": [], "text": full}, tok, header=False)
out["drill12"] = {k: v for k, v in {"status": st, "ms": ms, **(j.get("error") or {}), **j}.items() if k in keep}
ok["drill12_402_fits_fast"] = st == 402 and j.get("fits") == 1500 // 642 and j.get("min_questions") == 3 and j.get("estimated") is True and j.get("remaining") == q0 and ms < 8000 and "items" not in j
items = [{"id": f"q{i + 1}", "question": f"Vad händer med energin i steg {i + 1} i en näringskedja?"} for i in range(12)]
st, j, ms = req("exam", {"action": "drill_answers", "items": items, "subject": m["subject"], "may_fix": True}, tok, header=False)
out["answers12"] = {k: v for k, v in {"status": st, "ms": ms, **(j.get("error") or {}), **j}.items() if k in keep}
ok["answers12_402_fits"] = st == 402 and isinstance(j.get("fits"), int) and j["fits"] < 12 and ms < 8000 and "items" not in j

tok3 = T.signup()[0]  # its own account: the exam calls per minute above would give 429 (K110 live 18:45)
st, plan, ms = req("exam", {"action": "drill", "answers": False, "questions": 3, "subject": m["subject"], "pages": [], "text": full}, tok3)
out["drill3"] = {"status": st, "ms": ms, "items": len(plan.get("items") or []), "error": plan.get("error")}
real = None
if st == 200:
    sa, ans, ms2 = req("exam", {"action": "drill_answers", "items": plan["items"], "notes": plan.get("notes"), "subject": plan["summary"]["subject"],
                                "grade": plan["summary"]["grade"], "may_fix": True}, tok3)
    qi = ans.get("items") or []
    out["answers3"] = {"status": sa, "ms": ms2, "items": len(qi)}
    save_items = [{k: it[k] for k in ("question", "short", "long", "display") if it.get(k)} for it in qi]
    sc, c, _ = req("drill", {"action": "cost", "drill": {"title": "K109 (QA)", "subject": "Biologi"}, "items": save_items}, tok3)
    real = c.get("cost")
    out["cost3"] = {"status": sc, "real_cost": real, "estimate": 3 * 642, "per_question_real": real and round(real / max(1, len(save_items)))}
ok["drill3_works"] = st == 200 and out.get("answers3", {}).get("status") == 200
ok["real_within_estimate"] = bool(real) and real <= 3 * 642  # K110: an upper bound
ok["quota_unchanged"] = remaining(tok) == q0
st, j, ms = req("exam", {"action": "drill", "answers": False, "questions": 12, "subject": m["subject"], "pages": [], "text": "Kort material om fotosyntes. Växter gör socker av ljus."}, T.signup()[0])
out["qa_header_from_ci"] = {"status": st, "ms": ms, "items": len(j.get("items") or [])}
ok["qa_measure_skips_estimate"] = st == 200

st, j, ms = req("purchase", {"action": "attest_challenge"}, tok)
out["attest_challenge"] = {"status": st, "code": (j.get("error") or {}).get("code"), "has_challenge": bool(j.get("challenge"))}
ok["attest_challenge_503"] = st == 503 and out["attest_challenge"]["code"] == "attest_unconfigured"

print(json.dumps({"quota_start": q0, **out}, ensure_ascii=False, indent=1))
print("=== OK", json.dumps(ok, ensure_ascii=False))
print("=== ALL", all(ok.values()))
