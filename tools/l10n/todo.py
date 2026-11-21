"""A157: lists the texts of an area that still need a decision. `python3 tools/l10n/todo.py <work.json> <prefix>…
[--compiler strings/compiler.json]`. The list is printed with numbers; the answers go to apply.py as lines of
`<number><TAB><English>` (or `-` = not a text on the screen, leave it; `=` = the same in English)."""
from __future__ import annotations
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
import l10n, classify, swiftlit


def items(prefixes, compiler_path=None, langs=("sv", "unknown")):
    comp = l10n.compiler_keys(compiler_path)
    en = l10n.load(l10n.EN, {})
    skip = l10n.load(l10n.SKIP, {})
    cats = {t: l10n.load(os.path.join(l10n.ROOT, c[0]), {"strings": {}})["strings"] for t, c in l10n.CATALOGS.items()}
    seen = {}
    for lit in l10n.area_literals(prefixes):
        lang = classify.language(lit.plain, lit.interpolated)
        ctx = classify.context(lit)
        text = lit.text
        n = seen[(lit.file, text)] = seen.get((lit.file, text), 0) + 1
        if lang not in langs or ctx in ("log", "nontext"):
            continue
        if text in skip.get(lit.file, {}):
            continue
        base = os.path.basename(lit.file)[:-6]
        pat = l10n.pattern(lit.parts)
        key, kind = None, "plain"
        for target in l10n.target_of(lit.file):
            for k, files in comp.get(target, {}).items():
                if base in files and pat.match(k):
                    key, kind = k, "key"
                    break
        # With the compiler's list at hand it decides (Text("a" + b) is a String, a helper may take a key);
        # without it, the call before the literal is the guess.
        known = all(comp.get(t) for t in l10n.target_of(lit.file))
        if kind == "plain" and (l10n.is_localized(lit) or (ctx == "key" and not known)):
            kind = "key"
        if kind == "plain" and ctx == "verbatim":
            kind = "verbatim"
        if kind == "key":
            # Ready when every catalog it is compiled into has the English.
            ready = True
            for target in l10n.target_of(lit.file):
                cat = cats[target]
                hits = [k for k in cat if pat.match(k)] if key is None else ([key] if key in cat else [])
                if not hits or any(l10n.english_of(k, cat[k]) is None for k in hits):
                    ready = False
            if ready:
                continue
        yield {"file": lit.file, "line": lit.line, "text": text, "nth": n, "kind": kind, "key": key,
               "before": lit.before.strip()[-44:], "known": en.get(text)}


if __name__ == "__main__":
    args = sys.argv[1:]
    compiler = None
    if "--compiler" in args:
        i = args.index("--compiler"); compiler = args[i + 1]; del args[i:i + 2]
    langs = ("sv", "unknown")
    if "--english" in args:
        args.remove("--english"); langs = ("en",)
    work, prefixes = args[0], args[1:]
    out = list(items(prefixes, compiler, langs))
    # The same words once: the first place stands for all of them (one decision, one English).
    first, rows = {}, []
    for it in out:
        k = (it["text"], it["kind"] == "key")
        if k in first:
            first[k]["more"].append([it["file"], it["line"], it["nth"], it["kind"]])
            continue
        it["more"] = []
        first[k] = it
        rows.append(it)
    json.dump(rows, open(work, "w"), ensure_ascii=False, indent=0)
    last = None
    for n, it in enumerate(rows):
        if it["file"] != last:
            last = it["file"]; print("##", last)
        mark = {"key": "K", "plain": "P", "verbatim": "V"}[it["kind"]]
        known = "  [en: " + it["known"] + "]" if it["known"] else ""
        more = f" (+{len(it['more'])})" if it["more"] else ""
        print(f"{n}\t{mark} {it['line']}{more}\t{it['before'][-30:]!s:30}\t{it['text']}{known}")
    print(f"{len(rows)} decisions, {len(out)} places", file=sys.stderr)
