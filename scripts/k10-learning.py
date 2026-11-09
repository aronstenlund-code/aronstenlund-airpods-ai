#!/usr/bin/env python3
"""K10.4: "never correct Lumen twice". For each scenario the same user (1) asks a question, (2) corrects the answer
("kortare", "mer exempel" …), which /memory turns into a scoped setting + profile, and (3) asks a SIMILAR question,
with the settings and profile (as the app sends them) and, as the control, without. The second correction is not
needed when the answer with the setting already does what was asked (checked in code against the control).

  python3 scripts/k10-learning.py --tokens FILE [--out reports/eval]

Uses the public key and anonymous sessions like scripts/live-eval.py; no secrets.
"""
import argparse, datetime, importlib.util, json, os, re, statistics, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("pe", os.path.join(ROOT, "scripts", "provlage-eval.py"))
pe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pe)

P = lambda g, s: f"Årskurs: {g}. Ämne: {s}. Förklaringar: mellanlånga förklaringar."
# (kind, correction, mode, subject, q1, q2)
SCEN = [
    ("shorter", "kortare", "prov", "Biologi", "vad är fotosyntes", "vad är cellandning"),
    ("shorter", "det var för långt", "prov", "Historia", "franska revolutionen", "ryska revolutionen"),
    ("shorter", "Lumen, kortare", "fragor", None, "vad är inflation", "vad är ränta"),
    ("shorter", "för långt", "prov", "Kemi", "vad är en jonbindning", "vad är en kovalent bindning"),
    ("shorter", "kortare svar", "fragor", None, "hur fungerar en kylskåp", "hur fungerar en mikrovågsugn"),
    ("shorter", "kortare", "prov", "Geografi", "vad är plattektonik", "vad är vulkaner"),
    ("longer", "längre", "fragor", None, "vad är en svart hål", "vad är en neutronstjärna"),
    ("longer", "mer detaljer", "prov", "Fysik", "vad är tryck", "vad är densitet"),
    ("longer", "för kort", "fragor", None, "vem var Gustav Vasa", "vem var Karl XII"),
    ("longer", "utförligare", "prov", "Samhällskunskap", "vad gör riksdagen", "vad gör regeringen"),
    ("examples", "mer exempel", "prov", "Biologi", "vad är en näringskedja", "vad är ett ekosystem"),
    ("examples", "fler exempel tack", "prov", "Fysik", "vad är friktion", "vad är tröghet"),
    ("examples", "ge exempel", "fragor", None, "vad är en metafor", "vad är en liknelse"),
    ("examples", "Lumen, mer exempel", "prov", "Kemi", "vad är en syra", "vad är en bas"),
    ("examples", "jag behöver exempel", "prov", "Svenska", "vad är en novell", "vad är en krönika"),
    ("simpler", "enklare", "prov", "Biologi", "vad är DNA", "vad är en gen"),
    ("simpler", "för svårt", "prov", "Fysik", "vad är elektrisk spänning", "vad är elektrisk ström"),
    ("simpler", "jag förstår inte", "fragor", None, "vad är kvantfysik", "vad är relativitetsteorin"),
    ("simpler", "förklara enklare", "prov", "Kemi", "vad är oxidation", "vad är reduktion"),
    ("simpler", "för krångligt", "prov", "Samhällskunskap", "vad är parlamentarism", "vad är maktdelning"),
]


def post_json(tok, path, body):
    req = urllib.request.Request(pe.URL + path, method="POST", data=json.dumps(body).encode(),
                                 headers={"apikey": pe.KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    for attempt in range(3):
        try:
            return urllib.request.urlopen(req, timeout=90).read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 2:
                time.sleep(int(e.headers.get("retry-after") or 20))
                continue
            raise


def answer(tok, body):
    raw = post_json(tok, "/functions/v1/answer", body)
    text = "".join(json.loads(m)["text"] for m in re.findall(r"^event: delta\ndata: (.*)$", raw, re.M))
    done = re.findall(r"^event: done\ndata: (.*)$", raw, re.M)
    return text.strip(), json.loads(done[-1]) if done else {}


def words(t):
    return len(t.split())


def sent_len(t):
    s = [x for x in re.split(r"(?<=[.!?])\s+", t) if x.strip()]
    return statistics.mean(words(x) for x in s) if s else 0


def long_share(t):
    w = re.findall(r"[A-Za-zÅÄÖåäöéü]+", t)
    return sum(1 for x in w if len(x) >= 12) / max(1, len(w))


EX = re.compile(r"\b(?:till exempel|exempel|t\.ex\.|tänk dig|som när|om du)\b", re.I)


def satisfied(kind, with_, without):
    if kind == "shorter":
        return words(with_) <= 0.75 * words(without), f"{words(with_)} mot {words(without)} ord"
    if kind == "longer":
        return words(with_) >= 1.25 * words(without), f"{words(with_)} mot {words(without)} ord"
    if kind == "examples":
        a, b = len(EX.findall(with_)), len(EX.findall(without))
        return a >= 1 and a >= b, f"exempelord {a} mot {b}"
    sa, sb, la, lb = sent_len(with_), sent_len(without), long_share(with_), long_share(without)
    return (sa <= 0.9 * sb or la <= 0.8 * lb), f"ord/mening {sa:.1f} mot {sb:.1f}, långa ord {la:.2f} mot {lb:.2f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "eval"))
    a = ap.parse_args()
    toks = [pe.signup(a.tokens, i) for i in (0, 1)]
    rows = []
    for i, (kind, corr, mode, subject, q1, q2) in enumerate(SCEN):
        tok = toks[i % 2]
        base = {"language": "sv"}
        if mode == "prov":
            base.update(mode="tutor", persona="tutor", persona_setup=P("Åk 9", subject))
        else:
            base.update(mode="push_to_talk")
        a1, d1 = answer(tok, {**base, "fragment": q1, "context": {}})
        at = (d1.get("breakdown") or {}).get("answer_type") or "study"
        ctx = {"mode": mode, **({"subject": subject} if subject else {}),
               "answer_type": "math" if subject == "Matematik" else ("explanation" if at == "study" else "fact")}
        mem = json.loads(post_json(tok, "/functions/v1/memory", {"correction": {"text": corr, "context": ctx}, "settings": []}))
        hist = {"recent_qa": [{"q": q1, "a": a1[:1400]}]}
        with_, _ = answer(tok, {**base, "fragment": q2, "context": hist, "preferences": mem.get("settings", []),
                                "pref_profile": mem.get("profile", "")})
        without, _ = answer(tok, {**base, "fragment": q2, "context": hist})
        ok, why = satisfied(kind, with_, without)
        rows.append({"kind": kind, "correction": corr, "mode": mode, "subject": subject, "q1": q1, "q2": q2,
                     "setting": mem.get("setting"), "profile": mem.get("profile"), "ok": ok, "why": why,
                     "with": with_, "without": without})
        print(f"{'OK ' if ok else 'NEJ'} {kind:9} {q2[:40]:40} {why}", flush=True)
    n = sum(r["ok"] for r in rows)
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    base = os.path.join(a.out, f"k10-learning-{date}")
    json.dump({"ok": n, "of": len(rows), "rows": rows}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    by = {}
    for r in rows:
        by.setdefault(r["kind"], [0, 0])
        by[r["kind"]][0] += r["ok"]
        by[r["kind"]][1] += 1
    lines = [f"# K10.4: rätta en gång, liknande fråga ({date})", "",
             f"**Andra rättelsen behövs inte: {n} av {len(rows)} ({round(100 * n / len(rows))} %).** Krav ≥ 90 %.", "",
             "Per sort: " + ", ".join(f"{k} {v[0]}/{v[1]}" for k, v in by.items()), "", "| sort | rättelse | läge | fråga 2 | inställning | resultat |", "|---|---|---|---|---|---|"]
    for r in rows:
        lines.append(f"| {r['kind']} | {r['correction']} | {r['mode']} | {r['q2']} | {(r['setting'] or {}).get('text', '')} | {'ja' if r['ok'] else 'nej'}: {r['why']} |")
    open(base + ".md", "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(json.dumps({"ok": n, "of": len(rows), "by_kind": by}, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
