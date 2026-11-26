"""O100 (Oscar moln, 2026-11-26): säkerhetsgranskning av backend före App Store, live. Två nya testkonton (A och B),
x-earmind-test, 0 ElevenLabs (stt-token, tts och voice-lab får bara anrop utan inloggning eller med fel metod), inga
modellanrop (bara trasiga eller för stora kroppar mot /answer, /exam, /help), inga riktiga köp.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o100_security_live.py
Del 1 RLS via REST (/rest/v1) och RPC; del 2 lagringen; del 3 B:s prov genom /drill som A (IDOR); del 4 alla
edge-funktioner (utan inloggning, falsk token, fel metod, 2 MB, trasig JSON, läckor); del 5 köp, inbjudan och negativa tal.
Skriptet skriver inget utom: B:s testprov (defer_audio, raderas sist), ett försök till rader som ska nekas, A:s
inbjudningskod."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, json, re, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK, FIND = [], []
FIX = json.loads((HERE / "o78" / "fixtures.json").read_text())
LEAK = re.compile(r"(sb_secret|service_role|sk-ant|xi-api-key|ELEVENLABS|ANTHROPIC|SUPABASE_|postgres|PGRST|relation \"|duplicate key|"
                  r"\bat [\w$.]+ \(|file:///|/home/|Deno\.|TypeError|ReferenceError|stack)", re.I)


def check(name, ok, detail):
    OK.append(bool(ok))
    if not ok:
        FIND.append(name)
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def req(method, path, body=None, tok=None, headers=None, raw=None, auth=True):
    h = T.headers(tok, True) if auth else {"user-agent": "python-urllib/oscar-qa", "x-earmind-test": "oscar-qa"}
    h.update(headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    r = urllib.request.Request(T.URL + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            return x.status, {k.lower(): v for k, v in x.headers.items()}, x.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, (e.read() or b"").decode(errors="replace")
    except Exception as e:  # noqa: BLE001
        return -1, {}, f"exception {type(e).__name__}: {str(e)[:120]}"


def js(t):
    try:
        return json.loads(t)
    except ValueError:
        return None


def signup():
    j = json.loads(req("POST", "/auth/v1/signup", {})[2])
    return j["access_token"], j["user"]["id"]


A, A_ID = signup()
B, B_ID = signup()

# ---------- B makes a drill (no audio, no model), so A has someone else's rows to aim at ----------
s, _, t = req("POST", "/functions/v1/drill", {"action": "save", "defer_audio": True, "drill": {"title": "O100 B (QA)", "subject": "QA"},
                                              "items": [{"question": "Vad är O100?", "short": "Ett test.", "long": "Ett test av säkerheten."}]}, B)
bj = js(t) or {}
B_DRILL = (bj.get("drill") or {}).get("id")
B_ITEM = ((bj.get("items") or [{}])[0]).get("id")
check("förberedelse: B:s prov sparat", s == 200 and B_DRILL, {"status": s, "drill": B_DRILL, "item": B_ITEM, "svar": t[:200]})

# ---------- 1. RLS through PostgREST ----------
TABLES = ["answer_usage", "app_attest_challenges", "app_attest_keys", "ci_ranges", "connections", "credit_admins", "credit_ledger",
          "debug_testers", "debug_turns", "drill_audio_files", "drill_items", "drill_publications", "drill_quota", "drill_reports",
          "drill_settings", "drill_shares", "drill_try_credits", "drills", "feedback", "feedback_admin", "invite_claims", "invite_codes",
          "logo_votes", "provider_status", "qa_log", "rate_limits", "real_user_candidates", "schools", "shared_history",
          "store_products", "store_subscriptions", "test_accounts", "usage_by_category_day", "voice_catalog", "waitlist"]
reads = {}
for tb in TABLES:
    for who, tok in (("anon", None), ("A", A)):
        s, _, t = req("GET", f"/rest/v1/{tb}?select=*&limit=5", tok=tok)
        j = js(t)
        n = len(j) if isinstance(j, list) else None
        others = [r for r in (j or []) if isinstance(r, dict) and r.get("user_id") not in (None, A_ID)] if isinstance(j, list) else []
        reads[f"{tb}/{who}"] = {"status": s, "rader": n, "andras": len(others)}
leaky = {k: v for k, v in reads.items() if v["rader"] and (k.endswith("/anon") or v["andras"])}
check("1a: varken anon eller A kan läsa någon annans rader i någon tabell i public (35 tabeller och vyer)", not leaky, {"läckor": leaky})
check("1b: B:s prov syns inte för A genom REST (drills och drill_items med B:s id)",
      all(json.loads(req("GET", f"/rest/v1/{tb}?select=id&{col}=eq.{v}", tok=A)[2] or "[]") == [] for tb, col, v in
          (("drills", "id", B_DRILL), ("drill_items", "drill_id", B_DRILL), ("drills", "user_id", B_ID))),
      {"B_DRILL": B_DRILL})
own = js(req("GET", f"/rest/v1/drills?select=id&id=eq.{B_DRILL}", tok=B)[2])
check("1c: B ser sitt eget prov (policyn fungerar åt rätt håll)", isinstance(own, list) and len(own) == 1, {"svar": own})

writes = {}
W = [("POST", "credit_ledger", {"user_id": A_ID, "kind": "purchase", "credits": 100000, "product_id": "o100", "transaction_id": "o100-" + uuid.uuid4().hex}),
     ("POST", "drill_quota", {"user_id": A_ID, "used": -100000}),
     ("POST", "store_subscriptions", {"user_id": A_ID, "original_transaction_id": "o100-" + uuid.uuid4().hex}),
     ("POST", "test_accounts", {"user_id": A_ID}), ("POST", "credit_admins", {"user_id": A_ID}),
     ("POST", "debug_testers", {"user_id": A_ID}), ("POST", "drill_settings", {"key": "launch_percent", "value": 99}),
     ("POST", "rate_limits", {"key": "o100", "count": 0}), ("POST", "answer_usage", {"user_id": A_ID}),
     ("POST", "drills", {"user_id": A_ID, "title": "O100"}), ("POST", "feedback", {"user_id": B_ID, "message": "O100 QA (ska nekas)"}),
     ("POST", "shared_history", {"user_id": B_ID, "question": "O100 QA (ska nekas)"}),
     ("PATCH", f"drills?id=eq.{B_DRILL}", {"title": "O100 ändrat av A"}), ("PATCH", f"drills?user_id=eq.{A_ID}", {"user_id": B_ID}),
     ("PATCH", "drill_settings?key=eq.launch_percent", {"value": 99}), ("PATCH", "credit_ledger?user_id=eq." + A_ID, {"credits": 100000}),
     ("DELETE", f"drills?id=eq.{B_DRILL}", None), ("DELETE", f"drill_items?drill_id=eq.{B_DRILL}", None), ("DELETE", "rate_limits?key=neq.x", None)]
for m, path, body in W:
    s, h, t = req(m, f"/rest/v1/{path}", body, A, {"prefer": "return=representation"})
    j = js(t)
    writes[f"{m} {path.split('?')[0]}"] = {"status": s, "rader": len(j) if isinstance(j, list) else None, "kod": (j or {}).get("code") if isinstance(j, dict) else None}
bad = {k: v for k, v in writes.items() if v["status"] in (200, 201, 204) and v["rader"]}
still = js(req("GET", f"/rest/v1/drills?select=id,title&id=eq.{B_DRILL}", tok=B)[2])
check("1d: A kan inte skriva, ändra eller radera någon rad (krediter, köp, kvot, inställningar, B:s prov, gränser)",
      not bad and isinstance(still, list) and len(still) == 1 and still[0]["title"] == "O100 B (QA)", {"lyckades": bad, "alla": writes, "B:s prov efteråt": still})

RPC = {"credit_balance": {"p_user": B_ID}, "is_credit_admin": {"p_user": A_ID}, "logo_vote_counts": {}, "usage_stats": {"p_days": 1},
       "drill_storage_stats": {}, "use_purchased_credits": {"p_user": A_ID, "p_n": 0}, "refund_drill_chars": {"p_user": A_ID, "p_n": 0},
       "refund_drill_quota": {"p_user": A_ID, "p_n": 0}, "use_drill_chars": {"p_user": A_ID, "p_n": 0}, "use_drill_quota": {"p_user": A_ID, "p_n": 0},
       "use_week_chars": {"p_user": A_ID, "p_n": 0, "p_lim": 0}, "invite_reward": {"p_invitee": A_ID, "p_credits": 0, "p_max": 0},
       "claim_drill_audio": {"n": 0}, "check_rate_limit": {"p_key": "o100", "p_limit": 1, "p_window_sec": 60, "p_cost": 0}}
rpc = {}
for fn, args in RPC.items():
    s, _, t = req("POST", f"/rest/v1/rpc/{fn}", args, A)
    j = js(t)
    rpc[fn] = {"status": s, "kod": j.get("code") if isinstance(j, dict) else None}
okrpc = {k: v for k, v in rpc.items() if v["status"] in (200, 204)}
check("1e: inga databasfunktioner (krediter, kvot, inbjudan, gränser, statistik) går att anropa som A (bara annars nej)",
      not okrpc, {"anropbara": okrpc, "alla": rpc})
s, _, t = req("GET", "/rest/v1/", tok=None)
check("1f: REST-roten (OpenAPI) visar inte schemat för anon", s != 200 or '"paths"' not in t or "credit_ledger" not in t, {"status": s, "början": t[:200]})

# ---------- 2. storage ----------
st = {}
for b in ("drill_audio", "drill_material", "debug_audio"):
    s, _, t = req("POST", f"/storage/v1/object/list/{b}", {"prefix": "", "limit": 5}, A)
    j = js(t)
    st[f"list {b}"] = {"status": s, "antal": len(j) if isinstance(j, list) else None}
    s, _, t = req("GET", f"/storage/v1/object/public/{b}/x.mp3", tok=None)
    st[f"public {b}"] = {"status": s}
    s, _, t = req("POST", f"/storage/v1/object/{b}/o100/{uuid.uuid4().hex}.mp3", tok=A, raw=b"ID3o100", headers={"content-type": "audio/mpeg"})
    st[f"upload {b}"] = {"status": s}
check("2: lagringen: A kan inte lista, läsa publikt eller ladda upp i drill_audio, drill_material eller debug_audio",
      all(not v.get("antal") for k, v in st.items() if k.startswith("list")) and all(v["status"] not in (200, 201) for k, v in st.items() if not k.startswith("list")),
      st)

# ---------- 3. B's drill through /drill as A ----------
idor = {}
for body in ({"action": "get", "id": B_DRILL}, {"action": "status", "id": B_DRILL}, {"action": "delete", "id": B_DRILL},
             {"action": "share", "id": B_DRILL}, {"action": "stats", "id": B_DRILL, "presses": {"1": 1}}, {"action": "played", "id": B_DRILL},
             {"action": "publish", "id": B_DRILL}, {"action": "save", "drill": {"id": B_DRILL, "title": "O100 ändrat av A"}, "items": []},
             {"action": "start", "id": B_DRILL}, {"action": "cost", "drill": {"id": B_DRILL}, "items": []}):
    s, _, t = req("POST", "/functions/v1/drill", body, A)
    j = js(t) or {}
    idor[body["action"]] = {"status": s, "kod": (j.get("error") or {}).get("code"), "har B:s titel": "O100 B" in t}
still = js(req("POST", "/functions/v1/drill", {"action": "get", "id": B_DRILL}, B)[2]) or {}
check("3: A kommer inte åt B:s prov genom /drill (get, status, delete, share, stats, played, publish, save, start, cost)",
      not any(v["har B:s titel"] or (v["status"] == 200 and k in ("delete", "share", "publish", "save", "start")) for k, v in idor.items())
      and (still.get("drill") or {}).get("title") == "O100 B (QA)", {"A": idor, "B:s titel efteråt": (still.get("drill") or {}).get("title")})

# ---------- 4. every edge function ----------
FNS = ["account", "answer", "anthtest", "connect", "debug-audio", "drill", "drill-purge", "evallab", "exam", "feedback", "feedback-admin",
       "fetch-url", "help", "logo-vote", "memory", "my-answers", "provlage-eval", "purchase", "qa-log", "real-users-admin", "shared-history",
       "stt-token", "study-cards", "study-plan", "study-profile", "tts", "usage-stats", "voice-lab", "voices", "waitlist"]
ELEVEN = {"stt-token", "tts", "voice-lab"}  # D180: never with a valid token here
hdr = base64.urlsafe_b64encode(b'{"alg":"HS256","typ":"JWT"}').rstrip(b"=").decode()
pl = base64.urlsafe_b64encode(json.dumps({"sub": B_ID, "role": "authenticated", "exp": 4102444800, "is_anonymous": False, "email": "owner@example.com"}).encode()).rstrip(b"=").decode()
FORGED = f"{hdr}.{pl}.{base64.urlsafe_b64encode(b'x' * 32).rstrip(b'=').decode()}"
BIG = b'{"action":"x","text":"' + b"a" * 2_000_000 + b'"}'
table, leaks = {}, {}
for fn in FNS:
    p = "/functions/v1/" + fn
    row = {}
    s, _, t = req("POST", p, {}, auth=False, headers={"apikey": T.KEY, "content-type": "application/json"})
    row["utan token"] = s
    s, _, t2 = req("POST", p, {}, None, {"authorization": "Bearer " + FORGED})
    row["falsk token"] = s
    tok = None if fn in ELEVEN else A
    s, _, t3 = req("PUT", p, {}, tok)
    row["PUT"] = s
    if fn not in ELEVEN:
        s, _, t4 = req("POST", p, tok=A, raw=BIG)
        row["2 MB"] = s
        s, _, t5 = req("POST", p, tok=A, raw=b'{"action": "save", "x": [1,2,')
        row["trasig JSON"] = s
    else:
        t4 = t5 = ""
    table[fn] = row
    for name, txt in (("utan token", t), ("falsk token", t2), ("PUT", t3), ("2 MB", t4), ("trasig JSON", t5)):
        m = LEAK.search(txt or "")
        if m:
            leaks[f"{fn} {name}"] = (txt or "")[max(0, m.start() - 60): m.end() + 60]
print("     tabell: " + json.dumps(table, ensure_ascii=False), flush=True)
open_ = {fn: r for fn, r in table.items() if r["falsk token"] == 200 and fn not in ("voices", "purchase", "waitlist", "connect")}
check("4a: en förfalskad token (rätt form, fel signatur, påhittad e-post) släpps inte in någonstans", not open_, {"släppte in": open_})
check("4b: inga felsvar läcker interna detaljer (stack, SQL, nycklar, sökvägar, miljövariabler)", not leaks, {"läckor": leaks})
big_ok = {fn: r.get("2 MB") for fn, r in table.items() if r.get("2 MB") not in (None, 400, 401, 403, 404, 405, 413, 429, 503)}
check("4c: 2 MB kropp nekas (400/413) eller stoppas före arbete; aldrig 200 eller 500", not big_ok, {"avvikande": big_ok})
bad_json = {fn: r.get("trasig JSON") for fn, r in table.items() if r.get("trasig JSON") not in (None, 400, 401, 403, 404, 405, 413, 429)}
check("4d: trasig JSON ger 400, inte 500", not bad_json, {"avvikande": bad_json})
put = {fn: r["PUT"] for fn, r in table.items() if r["PUT"] in (200, 500)}
check("4e: fel metod (PUT) ger aldrig 200 eller 500", not put, {"avvikande": put})

# ---------- 5. purchases, invitations, negative numbers ----------
_, _, q0 = req("POST", "/functions/v1/drill", {"action": "quota"}, A)
q0 = js(q0) or {}
pv = {}
for k, v in (("falsk kedja", FIX["fake_chain_jws"]), ("samma igen", FIX["fake_chain_jws"]), ("skräp", "a.b.c"), ("tom", ""), ("tal", 12345)):
    s, _, t = req("POST", "/functions/v1/purchase", {"action": "verify", "jws": v}, A)
    pv[k] = [s, ((js(t) or {}).get("error") or {}).get("code")]
s, _, t = req("POST", "/functions/v1/purchase", {"signedPayload": FIX["fake_chain_jws"]}, None, {"apikey": T.KEY})
pv["App Store-notis utan kedja"] = [s, ((js(t) or {}).get("error") or {}).get("code")]
s, _, t = req("POST", "/functions/v1/purchase", {"action": "invite_code"}, A)
code = (js(t) or {}).get("code")
inv = {"kod": [s, bool(code)]}
for who, tok in (("A tar sin egen", A), ("B tar A:s", B), ("B tar A:s igen", B)):
    s, _, t = req("POST", "/functions/v1/purchase", {"action": "invite_claim", "code": code or "x"}, tok)
    inv[who] = [s, ((js(t) or {}).get("error") or {}).get("code") or (js(t) or {}).get("reason")]
neg = {}
for body in ({"action": "cost", "drill": {"kind": "text", "said": True}, "items": [{"kind": "para", "text": "x" * 10}], "quantity": -5},
             {"action": "save", "defer_audio": True, "drill": {"title": "O100 neg (QA)", "long_words": -50}, "items": []},
             {"action": "stats", "id": B_DRILL, "presses": {"1": -1000000}}):
    s, _, t = req("POST", "/functions/v1/drill", body, A)
    neg["drill " + body["action"]] = [s, ((js(t) or {}).get("error") or {}).get("code")]
for qn in (-5, 0, 10_000):
    s, _, t = req("POST", "/functions/v1/exam", {"action": "drill", "answers": False, "questions": qn, "subject": "", "pages": [], "text": ""}, A)
    neg[f"exam questions {qn} (tom text)"] = [s, ((js(t) or {}).get("error") or {}).get("code")]
_, _, q1 = req("POST", "/functions/v1/drill", {"action": "quota"}, A)
q1 = js(q1) or {}
_, _, qb = req("POST", "/functions/v1/drill", {"action": "quota"}, B)
qb = js(qb) or {}
check("5: inga krediter utan giltigt köp: falska och dubbla kvitton 422, App Store-notis utan Apples kedja nekas, A:s krediter oförändrade",
      all(v[0] in (400, 422) for k, v in pv.items() if k != "App Store-notis utan kedja") and pv["App Store-notis utan kedja"][0] in (400, 401, 403, 422)
      and q0.get("limit") == q1.get("limit") and (q1.get("remaining") or 0) <= (q0.get("remaining") or 0),
      {"köp": pv, "A före": {k: q0.get(k) for k in ("limit", "used", "remaining", "purchased")}, "A efter": {k: q1.get(k) for k in ("limit", "used", "remaining", "purchased")}})
check("5b: inbjudan: egen kod och dubbla anspråk ger inga krediter",
      inv.get("A tar sin egen", [200])[0] != 200 and inv.get("B tar A:s igen", [200])[0] != 200 or inv["kod"][0] == 503,
      {"inbjudan": inv, "B": {k: qb.get(k) for k in ("limit", "remaining", "gift")}})
check("5c: negativa och orimliga tal ger 400 eller rimliga gränser, aldrig 500 eller fler krediter", not any(v[0] == 500 for v in neg.values())
      and (q1.get("remaining") or 0) <= (q0.get("remaining") or 0), {"svar": neg})

# ---------- cleanup ----------
s, _, _ = req("POST", "/functions/v1/drill", {"action": "delete", "id": B_DRILL}, B)
print(f"     städat: B:s prov raderat ({s})", flush=True)
print(f"\n=== O100 {sum(OK)}/{len(OK)} ok" + (f"; FEL: {FIND}" if FIND else ""))
sys.exit(0 if all(OK) else 1)
