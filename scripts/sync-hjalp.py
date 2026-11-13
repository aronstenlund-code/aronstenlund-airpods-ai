#!/usr/bin/env python3
"""K57: copies docs/HJALP.md into backend/supabase/functions/_shared/hjalp.ts (run after every edit of HJALP.md)."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
s = (root / "docs/HJALP.md").read_text(encoding="utf-8")
(root / "backend/supabase/functions/_shared/hjalp.ts").write_text(
    "// K57 (D166): a copy of docs/HJALP.md for /help (the functions are deployed from backend/). hjalp_test.ts fails when\n"
    "// the two differ: edit docs/HJALP.md, then run  python -X utf8 scripts/sync-hjalp.py\n"
    "export const HJALP: string = " + json.dumps(s, ensure_ascii=False) + ";\n", encoding="utf-8", newline="\n")
print("synced", len(s), "characters")
