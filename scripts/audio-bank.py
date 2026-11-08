"""D88: picks 60 spoken cases from the Provläge test bank (scripts/provlage-bank.json) for the audio test and writes
scripts/audio-bank.json with the exact manuscript each voice will say. Kinds: subject terms, short key words, half
sentences and follow-ups (the other kinds are text-only questions). The first 15 are the pilot.
The manuscript is what a student would say out loud: the bank's spoken form, with the follow-up's earlier turns
kept as context (they are not spoken)."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bank = json.load(open(os.path.join(ROOT, "scripts", "provlage-bank.json"), encoding="utf-8"))

want = {"term": 24, "misheard": 0, "half": 10, "followup": 18, "short": 6, "exam": 2}
picked, seen_subjects = [], {}
for kind, n in want.items():
    pool = [c for c in bank if c["kind"] == kind]
    # spread over subjects: round-robin by subject
    by_sub = {}
    for c in pool:
        by_sub.setdefault(c["subject"], []).append(c)
    order = []
    while any(by_sub.values()):
        for s in sorted(by_sub):
            if by_sub[s]:
                order.append(by_sub[s].pop(0))
    picked += order[:n]

# the spoken form: the bank's spelling of a misheard term would not be "said"; terms are said as written
def manuscript(c):
    q = c["q"].strip()
    return q[0].upper() + q[1:] if c["kind"] in ("exam",) else q

PILOT_KINDS = {"term": 5, "half": 3, "followup": 5, "short": 2}
pilot, rest = [], []
counts = {}
for c in picked:
    k = c["kind"]
    if counts.get(k, 0) < PILOT_KINDS.get(k, 0):
        pilot.append(c)
        counts[k] = counts.get(k, 0) + 1
    else:
        rest.append(c)
cases = pilot + rest
out = []
for i, c in enumerate(cases, 1):
    out.append({"id": f"au-{i:02d}", "bank_id": c["id"], "kind": c["kind"], "grade": c["grade"], "subject": c["subject"],
                "say": manuscript(c), "profile": c["profile"], "context": c["context"], "expect": c["expect"],
                "pilot": i <= len(pilot)})
json.dump(out, open(os.path.join(ROOT, "scripts", "audio-bank.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(out), "cases,", len(pilot), "pilot")
for c in out:
    print(f"{c['id']} {'P' if c['pilot'] else ' '} {c['kind']:8} {c['subject']:16} \"{c['say']}\"")
