"""A157: takes the answers to a todo list. `python3 tools/l10n/apply.py <work.json> <answers.tsv>`.
A line is `<number><TAB><English>`; `-` leaves the literal as it is (remembered in skip.json with the reason after a
second tab); `=` says the English is the same words. Plain strings that get an English are wrapped in
String(localized:) in the code; the English goes to en.json, from which sync.py writes the catalogs."""
from __future__ import annotations
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(__file__))
import l10n, swiftlit


def main(work, answers):
    rows = json.load(open(work))
    en = l10n.load(l10n.EN, {})
    skip = l10n.load(l10n.SKIP, {})
    wraps = collections.defaultdict(list)       # file → [(text, nth)]
    done = 0
    for raw in open(answers, encoding="utf-8"):
        raw = raw.rstrip("\n")
        if not raw.strip() or raw.startswith("#"):
            continue
        cols = raw.split("\t")
        n, answer = int(cols[0]), cols[1]
        it = rows[n]
        places = [[it["file"], it["line"], it["nth"], it["kind"]]] + it["more"]
        if answer == "-":
            for f, _, _, _ in places:
                skip.setdefault(f, {})[it["text"]] = cols[2] if len(cols) > 2 else "not a text on the screen"
            done += 1
            continue
        sv_parts = l10n.parse(it["text"])
        english = it["text"] if answer == "=" else l10n.filled(answer, sv_parts)
        en_parts = l10n.parse(english)
        edge = lambda t: (t[:len(t) - len(t.lstrip(" "))], t[len(t.rstrip(" ")):])
        if edge(english) != edge(it["text"]):
            sys.exit(f"{n}: the spaces at the ends differ: {it['text']!r} / {english!r}")
        if sorted(l10n.exprs(sv_parts)) != sorted(l10n.exprs(en_parts)):
            sys.exit(f"{n}: the values differ: {l10n.exprs(sv_parts)} / {l10n.exprs(en_parts)}")
        if it["text"] in en and en[it["text"]] != english:
            print(f"note {n}: {it['text']!r} was {en[it['text']]!r}, now {english!r}", file=sys.stderr)
        en[it["text"]] = english
        for f, _, nth, kind in places:
            if kind in ("plain", "verbatim"):
                wraps[f].append((it["text"], nth))
        done += 1
    changed = 0
    for f, wanted in wraps.items():
        path = os.path.join(l10n.ROOT, f)
        src = open(path, encoding="utf-8").read()
        seen, edits = {}, []
        for lit in swiftlit.literals(f, src):
            k = seen[lit.text] = seen.get(lit.text, 0) + 1
            if (lit.text, k) in wanted and not l10n.is_localized(lit):
                edits.append((lit.start, lit.end))
        if len(edits) != len(set(wanted)):
            print(f"note {f}: {len(set(wanted))} wanted, {len(edits)} found", file=sys.stderr)
        marks = [(a, "String(localized: ") for a, _ in edits] + [(b, ")") for _, b in edits]
        for at, what in sorted(marks, reverse=True):       # from the end, so a literal inside another keeps its place
            src = src[:at] + what + src[at:]
        changed += len(edits)
        open(path, "w", encoding="utf-8").write(src)
    l10n.save(l10n.EN, en)
    l10n.save(l10n.SKIP, skip)
    print(f"{done} answers, {changed} literals wrapped in {len(wraps)} files")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
