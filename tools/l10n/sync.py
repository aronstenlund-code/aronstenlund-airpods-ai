"""A157: writes the catalog entries. `python3 tools/l10n/sync.py [--compiler strings/compiler.json]`.
For every Swedish text in the code that is looked up in a catalog (a SwiftUI text, a String(localized:) or a key the
compiler found) and has an English in en.json: the key with `en` (mine: needs_review, for Kelly) and `sv` (the key).
With the compiler's list the keys are exact (%lld, %@ …); without it the specifiers are guessed and corrected by the
next run. Entries that already have an English are left alone unless en.json says otherwise for one of mine."""
from __future__ import annotations
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import l10n, classify

NOTE = "A157: English by Angela Fable, for Kelly's review (Ke86)."


def entry(key, english, reviewed=False):
    e = {"extractionState": "manual",
         "localizations": {"en": {"stringUnit": {"state": "translated" if reviewed else "needs_review", "value": english}},
                           "sv": {"stringUnit": {"state": "translated", "value": key}}}}
    if not reviewed:
        e["comment"] = NOTE
    return e


def main(compiler_path=None):
    comp = l10n.compiler_keys(compiler_path)
    en = l10n.load(l10n.EN, {})
    cats = {t: l10n.load(os.path.join(l10n.ROOT, c[0]), None) for t, c in l10n.CATALOGS.items()}
    added = changed = removed = 0
    problems = []
    produced = {t: set() for t in l10n.CATALOGS}
    for lit in l10n.area_literals(()):
        text = lit.text
        if text not in en:
            continue
        ctx = classify.context(lit)
        en_parts = l10n.parse(en[text])
        pat = l10n.pattern(lit.parts)
        base = os.path.basename(lit.file)[:-6]
        for target in l10n.target_of(lit.file):
            keys = [k for k, files in comp.get(target, {}).items() if base in files and pat.match(k)]
            if not keys:
                if not (ctx == "key" or l10n.is_localized(lit)) and comp.get(target):
                    continue    # the compiler did not see it as a text and it is not wrapped: nothing to look up
                if not (ctx == "key" or l10n.is_localized(lit)):
                    continue
                keys = [l10n.key_with(lit.parts, [l10n.guess(e) for e in l10n.exprs(lit.parts)])]
            strings = cats[target]["strings"]
            produced[target].update(keys)
            for key in keys:
                specs = [m.group(0) for m in l10n.SPEC_RE.finditer(key.replace("%%", "\x00\x00"))] if lit.interpolated else []
                try:
                    value = l10n.english_value(lit.parts, en_parts, specs)
                except Exception as e:
                    problems.append(f"{lit.file}:{lit.line}: {e}")
                    continue
                old = strings.get(key)
                if old is None:
                    strings[key] = entry(key, value); added += 1
                elif l10n.english_of(key, old) is None:
                    old.setdefault("localizations", {})["en"] = {"stringUnit": {"state": "needs_review", "value": value}}
                    old["localizations"].setdefault("sv", {"stringUnit": {"state": "translated", "value": key}})
                    old.setdefault("comment", NOTE); changed += 1
                elif old.get("comment") == NOTE and l10n.english_of(key, old) != value:
                    old["localizations"]["en"]["stringUnit"]["value"] = value; changed += 1
    # An entry of mine that no text in the code becomes any more (a guessed %@ that the compiler made %lld, a text
    # that was reworded) goes away, so the catalog holds only what is looked up.
    for t in l10n.CATALOGS:
        strings = cats[t]["strings"]
        for key in [k for k, e in strings.items() if e.get("comment") == NOTE and k not in produced[t]]:
            del strings[key]; removed += 1
    for t, c in l10n.CATALOGS.items():
        l10n.save_catalog(os.path.join(l10n.ROOT, c[0]), cats[t])
    print(f"{added} added, {changed} changed, {removed} removed")
    for p in problems:
        print("PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    sys.exit(main(a[a.index("--compiler") + 1] if "--compiler" in a else None))
