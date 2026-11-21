"""A157 (D251): is every text in the app in both languages? `python3 tools/l10n/check.py [--compiler compiler.json]
[--areas] [--all]`. Fails (exit 1) on what would show wrong on a phone: a catalog entry without English or Swedish,
values that take different arguments than their key, a Swedish text that is looked up but has no entry, and, in the
folders that are done (done.txt), a Swedish string that is still a plain String and not marked as data (skip.json).
The folders not yet done are counted, not failed, until `--all`. `--areas` prints the count per folder."""
from __future__ import annotations
import sys, os, collections, re
sys.path.insert(0, os.path.dirname(__file__))
import l10n, classify

SWEDISH = re.compile(r"[åäöÅÄÖ]")


def _in_done(files, done):
    """Is one of the files (base names, from the compiler's list) in a folder that is done?"""
    for d in done:
        root = os.path.join(l10n.ROOT, d)
        for base in files:
            if os.path.isfile(root) and os.path.basename(root)[:-6] == base:
                return True
            for folder, _, names in os.walk(root):
                if base + ".swift" in names:
                    return True
    return False


def main(compiler_path=None, areas=False, everything=False):
    comp = l10n.compiler_keys(compiler_path)
    skip = l10n.load(l10n.SKIP, {})
    cats = {t: l10n.load(os.path.join(l10n.ROOT, c[0]), None)["strings"] for t, c in l10n.CATALOGS.items()}
    errors, legacy = [], collections.Counter()
    for target, strings in cats.items():
        for key, e in strings.items():
            loc = e.get("localizations", {})
            en = l10n.english_of(key, e)
            sv = loc.get("sv", {}).get("stringUnit", {}).get("value")
            if "variations" in loc.get("sv", {}) or "variations" in loc.get("en", {}):
                continue
            if sv is None:
                if classify.language(key) in ("sv", "en"):
                    errors.append(f"{target}: no Swedish for {key!r}")
                continue
            # An older key is English words with a Swedish translation; a Swedish key has itself as its Swedish.
            if en is None and sv == key and (SWEDISH.search(key) or classify.language(key) == "sv"):
                errors.append(f"{target}: no English for {key!r}")
            for name, value in (("en", en), ("sv", sv)):
                if value is not None and [t for _, t in l10n.specs_of(value)] != [t for _, t in l10n.specs_of(key)]:
                    errors.append(f"{target}: {name} takes other values than its key: {key!r} → {value!r}")
            if en is None:
                legacy[target] += 1
    plain = collections.Counter()
    done = [l.strip() for l in open(os.path.join(l10n.HERE, "done.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")]
    waiting = 0
    looked_up = missing = 0
    for lit in l10n.area_literals(()):
        lang = classify.language(lit.plain, lit.interpolated)
        ctx = classify.context(lit)
        if ctx in ("log", "nontext") or lang == "none":
            continue
        pat = l10n.pattern(lit.parts)
        base = os.path.basename(lit.file)[:-6]
        is_key = ctx == "key" or l10n.is_localized(lit)
        for target in l10n.target_of(lit.file):
            seen = [k for k, files in comp.get(target, {}).items() if base in files and pat.match(k)]
            if comp.get(target) and not seen and not l10n.is_localized(lit):
                # The compiler's list says this literal is a plain String, whatever the call before it looks like.
                if is_key and lang == "sv" and lit.text not in skip.get(lit.file, {}) and (
                        everything or any(lit.file.startswith(d) for d in done)):
                    errors.append(f"{lit.file}:{lit.line}: looks like a text but is a plain String (never looked up): {lit.text!r}")
                continue
            if not (is_key or seen):
                continue
            looked_up += 1
            hits = seen or [k for k in cats[target] if pat.match(k)]
            ok = hits and all(k in cats[target] and (l10n.english_of(k, cats[target][k]) is not None or lang != "sv")
                              for k in hits)
            if lang == "sv" and not ok:
                missing += 1
                if everything or any(lit.file.startswith(d) for d in done):
                    errors.append(f"{lit.file}:{lit.line}: looked up in {target} but no English: {lit.text!r}")
                else:
                    waiting += 1
            break
        else:
            if lang == "sv" and ctx in ("plain", "verbatim") and lit.text not in skip.get(lit.file, {}):
                plain["/".join(lit.file.split("/")[:3])] += 1
                if any(lit.file.startswith(d) for d in done):
                    errors.append(f"{lit.file}:{lit.line}: a Swedish text that is never looked up: {lit.text!r}")
    for target, strings in comp.items():
        for key in strings:
            if key not in cats.get(target, {}) and (SWEDISH.search(key) or classify.language(key) == "sv") and (
                    everything or any(os.path.basename(d.rstrip("/")) for d in done) and _in_done(strings[key], done)):
                errors.append(f"{target}: the compiler looks up {key!r} ({', '.join(sorted(strings[key]))}) – not in the catalog")
    print(f"catalogs: " + ", ".join(f"{t} {len(s)} keys" for t, s in cats.items()) + f"; texts looked up in the code: {looked_up}")
    if areas:
        print("Swedish strings that are plain Strings and not marked as data:")
        for a, n in sorted(plain.items()):
            print(f"  {a:36} {n}")
        print(f"  {'total':36} {sum(plain.values())}")
    seen = set()
    for e in errors:
        if e not in seen:
            seen.add(e); print("ERROR", e)
    print(f"{len(seen)} errors; {waiting} looked-up texts without English and {sum(plain.values())} plain Swedish strings in folders not yet done")
    return 1 if seen else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    sys.exit(main(a[a.index("--compiler") + 1] if "--compiler" in a else None, "--areas" in a, "--all" in a))
