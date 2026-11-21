"""A157 (D251): the shared pieces of the language tools. English is the base language of the String Catalogs and
Swedish a translation; the Swedish texts stay in the code as the keys (see DECISIONS), so every key needs an English
value (`en`) and its Swedish one (`sv`, the key itself).

  todo.py   lists the texts of an area that are not ready: no English yet, or a plain String the catalog never sees
  apply.py  takes my answers: wraps the plain ones in String(localized:) and remembers the English (en.json)
  sync.py   writes the catalog entries from en.json (exact keys from the compiler when its list is at hand)
  check.py  says what is missing; run before every push
"""
from __future__ import annotations
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import swiftlit, classify

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
EN = os.path.join(HERE, "en.json")          # Swedish literal (as written in Swift) → English literal
COMPILER = os.path.join(HERE, "compiler.json")  # the keys the compiler found in the latest Fable screens run
SKIP = os.path.join(HERE, "skip.json")      # file → Swedish literals that are not texts on the screen (and why)
CATALOGS = {                                # target → (its catalog, the folders compiled into it)
    "Lumen": ("Lumen/Resources/Localizable.xcstrings", ("Lumen", "Shared")),
    "LumenControls": ("LumenControls/Localizable.xcstrings", ("LumenControls", "Shared")),
}
SPEC = r"%(?:\d+\$)?(?:@|lld|llu|ld|lu|d|u|lf|f|\.\d+l?f|c|s|\d*\.?\d*[dfgeE@])"
SPEC_RE = re.compile(SPEC)
LOCALIZED = re.compile(r"\bString\s*\(\s*localized\s*:\s*$")


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")


def save_catalog(path, data):
    """As the file is written today (two spaces, keys in order); new keys are sorted in."""
    data["strings"] = dict(sorted(data["strings"].items(), key=lambda kv: kv[0]))
    text = json.dumps(data, ensure_ascii=False, indent=2)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text + "\n")


def parse(text: str):
    """A literal as it is written in Swift ("Fråga \\(n) av \\(m)") → parts, as swiftlit gives them."""
    lits = swiftlit.literals("<text>", '"' + text + '"')
    assert lits and lits[0].start == 0 and lits[0].end == len(text) + 2, text
    return lits[0].parts


def exprs(parts):
    return [swiftlit.unwrapped(p[1]).strip() for p in parts if not isinstance(p, str)]


def filled(english: str, sv_parts) -> str:
    """An answer may say {1}, {2} … for the Swedish text's first, second … value instead of repeating it."""
    values = [p[1] for p in sv_parts if not isinstance(p, str)]
    return re.sub(r"\{(\d+)\}", lambda m: "\\(" + swiftlit.unwrapped(values[int(m.group(1)) - 1]) + ")", english)


# Whole numbers the patterns below do not recognise (read from the code, A157). A value not listed here and not
# matched below is taken as text (%@); the compiler's list, when at hand, decides over both.
INTEGERS = {
    "$0 + 1", "$0.dots", "CommandPhraseStore.phraseLimit", "Int(modes.speakerThresholdDBFS)", "Int(p50)", "Int(p95)",
    "Int(seconds)", "batch", "counts", "daysLeft", "drill.sentenceCount", "exams", "heading.paragraphs", "knewCount", "lap",
    "line", "made.ready", "max(1, Int(left.rounded(.up)))", "max(1, quiz.asked)", "maxItems", "min(index + 1, cards.count)",
    "min(reader.sentenceIndex + 1, reader.sentenceCount)", "missing", "night.snoreMinutes", "p.ready", "parts[2]", "photos",
    "player.lap + 1", "quota.left - draft.countsAs", "read.chars_per_question", "reader.sentenceCount", "ready", "restless",
    "saved + 1", "session.readingLap", "start + 1", "startCount(drill)",
}


def guess(expr: str) -> str:
    """The format specifier the compiler will most likely give an interpolation (the compiler's list corrects it)."""
    e = expr.strip()
    if e in INTEGERS:
        return "%lld"
    if re.search(r"(?:^|\.)(count|index|number|total|left|cost|limit|minutes|seconds|hours|days|points|max|min|n|questions|credits|characters|words|pages|rows)\b\s*(?:[-+*/]\s*\d+)?$", e, re.I) and "(" not in e.split(".")[-1]:
        return "%lld"
    if re.fullmatch(r"[\w.]*\b(n|i|k|count|index|total|left|number)\s*[-+]\s*\d+", e):
        return "%lld"
    if re.fullmatch(r"\d+", e):
        return "%lld"
    return "%@"


def pattern(parts) -> re.Pattern:
    """Matches the catalog key a literal becomes, whatever specifiers the compiler chose."""
    out = []
    for p in parts:
        out.append(re.escape(p.replace("%", "%%")) if isinstance(p, str) else "(" + SPEC + ")")
    return re.compile("^" + "".join(out) + "$", re.S)


def key_with(parts, specs) -> str:
    out, k = [], 0
    for p in parts:
        if isinstance(p, str):
            out.append(p.replace("%", "%%"))
        else:
            out.append(specs[k]); k += 1
    return "".join(out)


def english_value(sv_parts, en_parts, specs) -> str:
    """The English format string: the same arguments as the Swedish key, by position when the order differs."""
    sv_e, en_e = exprs(sv_parts), exprs(en_parts)
    if sorted(sv_e) != sorted(en_e):
        raise ValueError(f"different values in the English text: {sv_e} / {en_e}")
    if sv_e == en_e:
        return key_with(en_parts, specs)
    used, order = [False] * len(sv_e), []
    for e in en_e:
        i = next(i for i, s in enumerate(sv_e) if s == e and not used[i])
        used[i] = True
        order.append(i)
    return key_with(en_parts, [f"%{i + 1}${specs[i][1:]}" for i in order])


def specs_of(value: str):
    """The arguments a format string takes, as a sorted list of (position, type)."""
    out, n = [], 0
    for m in SPEC_RE.finditer(value.replace("%%", "")):
        s = m.group(0)
        pos = re.match(r"%(\d+)\$", s)
        n += 1
        out.append((int(pos.group(1)) if pos else n, re.sub(r"^%(\d+\$)?", "", s)))
    return sorted(out)


def area_literals(prefixes):
    for target_roots in (("Lumen", "LumenControls", "Shared"),):
        for f in swiftlit.swift_files(*target_roots):
            if prefixes and not any(f.startswith(p) for p in prefixes):
                continue
            for lit in swiftlit.literals(f):
                yield lit


def is_localized(lit) -> bool:
    return bool(LOCALIZED.search(lit.before))


def compiler_keys(path):
    """{target: {key: set(file basenames)}} from the list the Fable screens run collects (strings/compiler.json)."""
    out = {}
    path = path or (COMPILER if os.path.exists(COMPILER) else None)
    if not path:
        return out
    for target, tables in load(path, {}).items():
        for table, rows in tables.items():
            if table != "Localizable":
                continue
            for row in rows:
                out.setdefault(target, {}).setdefault(row["key"], set()).add(row["file"])
    return out


def target_of(path: str):
    if path.startswith("LumenControls/"):
        return ["LumenControls"]
    if path.startswith("Shared/"):
        return ["Lumen", "LumenControls"]
    return ["Lumen"]


def has_both(entry) -> bool:
    loc = entry.get("localizations", {})
    return "sv" in loc


def english_of(key, entry):
    loc = entry.get("localizations", {})
    if "en" in loc:
        return loc["en"].get("stringUnit", {}).get("value")
    return None
