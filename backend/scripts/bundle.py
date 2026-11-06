#!/usr/bin/env python3
"""Builds one deployable file per Edge Function for the Supabase MCP (`deploy_edge_function` takes flat files).

    python3 scripts/bundle.py [outdir]      (default: /tmp/lumen-dist)

Per function it writes <outdir>/<name>.js (minified deno bundle, npm:/jsr: imports stay external). Non-ASCII
characters are written as \\uXXXX escapes so the file is pure ASCII (invisible characters such as NBSP survive
copy-and-paste into the deploy call); the control characters in regex classes stay escaped as they are.
Also prints size, number of `===` (a deploy that turned one into `==` is a silent bug) and verify_jwt.
"""
import os, re, subprocess, sys

FUNCS = {  # name -> verify_jwt
    "answer": True, "tts": True, "stt-token": True, "voices": True, "usage-stats": False,
    "feedback": True, "shared-history": True, "feedback-admin": False, "waitlist": False,
}
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lumen-dist"
os.makedirs(out, exist_ok=True)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for name, jwt in FUNCS.items():
    dst = os.path.join(out, f"{name}.js")
    subprocess.run(["deno", "bundle", "--platform", "deno", "--format", "esm", "--no-check", "--minify", "--keep-names",
                    "--external", "npm:*", "--external", "jsr:*", "-o", dst, f"supabase/functions/{name}/index.ts"],
                   cwd=root, check=True, capture_output=True)
    s = open(dst, encoding="utf-8").read()
    s = re.sub(r"[^\x00-\x7f]", lambda m: "\\u%04x" % ord(m.group(0)) if ord(m.group(0)) < 0x10000
               else "".join("\\u%04x" % c for c in [0xD800 + ((ord(m.group(0)) - 0x10000) >> 10), 0xDC00 + ((ord(m.group(0)) - 0x10000) & 0x3FF)]), s)
    open(dst, "w", encoding="utf-8").write(s)
    print(f"{name:15} {len(s):7d} bytes  ===:{s.count('===')}  verify_jwt={str(jwt).lower()}  ->{dst}")
