"""O75: K88 (D211, client_id) live med testkonton (Oscar moln, 2026-11-17). Kör i Actions (oscar-live.yml):
  python -I -X utf8 scripts/qa/o75_k88_live.py
Bara testkonton (qa_testaccount: x-earmind-test + script-UA), teströsten, 0 ElevenLabs, 0 Claude.
Skriver ut svaren (förkortade) för varje fall, så att rapporten kan visa dem."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, threading, time, uuid  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
STAMP = time.strftime("%H%M%S")


def call(body, tok):
    st, _h, raw = T.call("POST", "/functions/v1/drill", body, tok, timeout=120)
    try:
        return st, json.loads(raw or b"{}")
    except ValueError:
        return st, {"raw": raw[:200].decode("utf8", "replace")}


def short(j):
    d = j.get("drill") or {}
    keep = {k: j.get(k) for k in ("already_saved", "new_chars", "generated_questions", "chars_on_start") if k in j}
    if j.get("error"):
        keep["error"] = j["error"]
    return {"drill.id": (d.get("id") or "")[:8], "title": d.get("title"), "items": [i.get("question") for i in j.get("items") or []], **keep}


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:600], flush=True)


def items(tag, n=2):
    return [{"question": f"O75 {tag} fråga {i} {STAMP}?", "short": f"Svar {i}.", "long": f"Svar {i}. Mer om {tag}."} for i in range(1, n + 1)]


def save(tok, cid=None, its=None, title="O75", defer=True, did=None):
    drill = {"title": f"{title} {STAMP} (QA)", "subject": "Biologi"}
    if cid is not None:
        drill["client_id"] = cid
    if did:
        drill["id"] = did
    body = {"action": "save", "drill": drill, "items": its or items(title)}
    if defer:
        body["defer_audio"] = True
    return call(body, tok)


def count(tok):
    return len(call({"action": "list"}, tok)[1].get("drills") or [])


def quota(tok):
    return call({"action": "quota"}, tok)[1].get("used")


A = T.signup(True)[0]
B = T.signup(True)[0]

# 1. samma client_id två gånger (defer_audio), andra gången med andra frågor
cid = str(uuid.uuid4())
s1, j1 = save(A, cid, items("1a"), "O75-1")
s2, j2 = save(A, cid, items("1b", 3), "O75-1 ändrad titel")
same = (j1.get("drill") or {}).get("id") == (j2.get("drill") or {}).get("id")
check("1 samma client_id två gånger: samma prov, already_saved, 0 nya tecken, första frågorna kvar",
      s1 == 200 and s2 == 200 and same and j2.get("already_saved") is True and j2.get("new_chars") == 0 and j2.get("generated_questions") == 0
      and [i["question"] for i in j2.get("items") or []] == [i["question"] for i in j1.get("items") or []] and count(A) == 1,
      {"första": [s1, short(j1)], "andra": [s2, short(j2)], "prov i listan": count(A)})

# 2. samma id med versaler
s3, j3 = save(A, cid.upper(), items("2"), "O75-2")
check("2 samma id med VERSALER ger samma prov", s3 == 200 and (j3.get("drill") or {}).get("id") == (j1.get("drill") or {}).get("id") and j3.get("already_saved") is True,
      {"svar": [s3, short(j3)], "prov i listan": count(A)})

# 3. två anrop utan client_id ger två prov
n0 = count(A)
s4, j4 = save(A, None, items("3a"), "O75-3")
s5, j5 = save(A, None, items("3a"), "O75-3")
check("3 två anrop utan client_id ger två prov", s4 == 200 and s5 == 200 and (j4.get("drill") or {}).get("id") != (j5.get("drill") or {}).get("id") and count(A) == n0 + 2,
      {"första": [s4, short(j4)], "andra": [s5, short(j5)], "prov före/efter": [n0, count(A)]})

# 4. samma id från ett annat konto: eget prov, A orört
s6, j6 = save(B, cid, items("4"), "O75-4 konto B")
sa, ja = call({"action": "get", "id": (j1.get("drill") or {}).get("id")}, A)
check("4 samma client_id från konto B: eget prov, A:s prov orört",
      s6 == 200 and j6.get("already_saved") is not True and (j6.get("drill") or {}).get("id") != (j1.get("drill") or {}).get("id")
      and [i["question"] for i in ja.get("items") or []] == [i["question"] for i in j1.get("items") or []],
      {"B": [s6, short(j6)], "A get efteråt": [sa, short(ja)], "B:s lista": count(B)})
sb, jb = call({"action": "get", "id": (j1.get("drill") or {}).get("id")}, B)
check("4b konto B kan inte läsa A:s prov", sb == 404, {"B get på A:s id": [sb, jb.get("error")]})

# 5. ljud vid spara (testljud): kvoten räknas en gång
C = T.signup(True)[0]
q0 = quota(C)
cid5 = str(uuid.uuid4())
s7, j7 = save(C, cid5, items("5", 3), "O75-5", defer=False)
q1 = quota(C)
s8, j8 = save(C, cid5, items("5", 3), "O75-5", defer=False)
q2 = quota(C)
check("5 ljud vid spara: andra sparningen räknar inget (kvoten en gång)",
      s7 == 200 and s8 == 200 and j8.get("already_saved") is True and q1 - q0 == (j7.get("generated_questions") or 0) and q2 == q1,
      {"första": [s7, short(j7)], "andra": [s8, short(j8)], "kvot före/efter 1/efter 2": [q0, q1, q2]})

# 6. tre anrop samtidigt med samma id (ljud vid spara)
D = T.signup(True)[0]
qd0 = quota(D)
cid6 = str(uuid.uuid4())
res = [None, None, None]


def go(k):
    res[k] = save(D, cid6, items("6", 3), "O75-6", defer=False)


th = [threading.Thread(target=go, args=(k,)) for k in range(3)]
[t.start() for t in th]
[t.join() for t in th]
ids = {(r[1].get("drill") or {}).get("id") for r in res}
qd1 = quota(D)
gen = [r[1].get("generated_questions") for r in res]
check("6 tre samtidiga anrop med samma id: ett prov, kvoten räknas en gång",
      all(r[0] == 200 for r in res) and len(ids) == 1 and count(D) == 1 and qd1 - qd0 == 3,
      {"svar": [[r[0], short(r[1])] for r in res], "prov i listan": count(D), "kvot före/efter": [qd0, qd1], "generated per anrop": gen})

# 7. redigering med drill.id och client_id: client_id ignoreras, redigeringen går igenom
did = (j1.get("drill") or {}).get("id")
s9, j9 = save(A, str(uuid.uuid4()), items("7 redigerad"), "O75-7", did=did)
check("7 redigering med drill.id (och ett annat client_id) ändrar provet",
      s9 == 200 and (j9.get("drill") or {}).get("id") == did and j9.get("already_saved") is not True and any("7 redigerad" in (i.get("question") or "") for i in j9.get("items") or []),
      {"svar": [s9, short(j9)]})

# 8. ogiltiga client_id
bad = {}
for v in ["abc", "", 123, "not-a-uuid-" + "x" * 40, "00000000-0000-0000-0000-00000000000g", str(uuid.uuid4()) + " "]:
    st, j = save(A, v, items("8"), "O75-8")
    bad[repr(v)] = [st, (j.get("error") or {}).get("code"), ((j.get("drill") or {}).get("id") or "")[:8]]
    if st == 200 and (j.get("drill") or {}).get("id"):
        call({"action": "delete", "id": j["drill"]["id"]}, A)
check("8 ogiltiga client_id ger 400 (tom sträng: se rapporten)", all(r[0] == 400 for k, r in bad.items() if k not in ("''",)), bad)

# 9. efter att provet tagits bort: samma client_id igen
cid9 = str(uuid.uuid4())
sa9, ja9 = save(A, cid9, items("9"), "O75-9")
call({"action": "delete", "id": (ja9.get("drill") or {}).get("id")}, A)
sb9, jb9 = save(A, cid9, items("9"), "O75-9")
check("9 samma client_id efter borttaget prov: (beteende registreras)", sb9 in (200, 409),
      {"före borttag": [sa9, short(ja9)], "efter borttag": [sb9, short(jb9)]})

# städa
for tok in (A, B, C, D):
    for d in call({"action": "list"}, tok)[1].get("drills") or []:
        call({"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O75 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
