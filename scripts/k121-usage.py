"""K121 (Kevin moln 2026-11-26): what each action cost while the credits lasted. Read only, no model call, 0 ElevenLabs.
Reads answer_usage (est_cost_usd, tokens, endpoint, model) with the service key and groups it by endpoint and model,
real users apart from test traffic (public.test_accounts). Prints sums only, never a user id or any text.
Usage (kevin-live.yml): python -X utf8 scripts/k121-usage.py [from YYYY-MM-DD] [to YYYY-MM-DD]"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
import collections, json, os, urllib.parse, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
svc = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
a = [x for x in _s.argv[1:] if x[:2] == "20"]
start, end = (a + ["2026-11-01", "2026-11-23"])[:2] if len(a) < 2 else a[:2]


def rows(table, query):
    out, off = [], 0
    while True:
        r = urllib.request.Request(f"{T.URL}/rest/v1/{table}?{query}&limit=1000&offset={off}", headers={"apikey": svc, "authorization": "Bearer " + svc})
        page = json.loads(urllib.request.urlopen(r, timeout=60).read())
        out += page
        if len(page) < 1000:
            return out
        off += 1000


tests = {x["user_id"] for x in rows("test_accounts", "select=user_id")}
q = "select=user_id,endpoint,model,mode,category,status,input_tokens,output_tokens,est_cost_usd,created_at" + \
    f"&created_at=gte.{start}&created_at=lt.{end}&order=created_at.asc"
data = rows("answer_usage", q)
print(f"=== answer_usage {start}..{end}: {len(data)} rows, test accounts known: {len(tests)}")
agg = collections.defaultdict(lambda: {"n": 0, "cost": 0.0, "in": 0, "out": 0, "nocost": 0})
days = collections.defaultdict(float)
for r in data:
    who = "test" if r["user_id"] in tests else "real"
    k = (who, r["endpoint"], r.get("model") or "-")
    a = agg[k]
    a["n"] += 1
    c = r.get("est_cost_usd")
    if c is None:
        a["nocost"] += 1
    else:
        a["cost"] += float(c)
        days[(r["created_at"][:10], who)] += float(c)
    a["in"] += r.get("input_tokens") or 0
    a["out"] += r.get("output_tokens") or 0
tot = sum(v["cost"] for v in agg.values())
print(f"=== total est_cost_usd {tot:.2f}")
print("who  | endpoint | model | calls | usd | usd/call | in/call | out/call | share")
for k, v in sorted(agg.items(), key=lambda kv: -kv[1]["cost"]):
    n = max(1, v["n"] - v["nocost"])
    print(f"{k[0]} | {k[1]} | {k[2]} | {v['n']} | {v['cost']:.2f} | {v['cost'] / n:.4f} | {v['in'] // max(1, v['n'])} | {v['out'] // max(1, v['n'])} | {100 * v['cost'] / max(tot, 1e-9):.1f}%")
for who in ("real", "test"):
    print(f"=== {who} total {sum(v['cost'] for k, v in agg.items() if k[0] == who):.2f}")
print("=== per day (real / test)")
for d in sorted({k[0] for k in days}):
    print(f"{d} | {days.get((d, 'real'), 0):.2f} | {days.get((d, 'test'), 0):.2f}")
# answer by mode and category (real users), the biggest single action
m = collections.defaultdict(lambda: [0, 0.0])
for r in data:
    if r["endpoint"] == "answer" and r.get("est_cost_usd") is not None:
        key = ("test" if r["user_id"] in tests else "real", r.get("mode") or "-", r.get("category") or "-")
        m[key][0] += 1
        m[key][1] += float(r["est_cost_usd"])
print("=== answer by who/mode/category (top 25)")
for k, v in sorted(m.items(), key=lambda kv: -kv[1][1])[:25]:
    print(f"{k[0]} | {k[1]} | {k[2]} | {v[0]} | {v[1]:.2f} | {v[1] / v[0]:.4f}")
