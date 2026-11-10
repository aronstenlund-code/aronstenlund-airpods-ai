#!/usr/bin/env python3
"""Start a GitHub Actions workflow with the git credentials of this machine (agents; the owner never runs it).
  python scripts/dispatch.py credits-ready.yml [key=value ...]   e.g. tag=after"""
import json, subprocess, sys, urllib.request

REPO = "aronstenlund-code/aronstenlund-airpods-ai"
wf = sys.argv[1]
inputs = dict(a.split("=", 1) for a in sys.argv[2:])
out = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n", capture_output=True, text=True).stdout
tok = dict(l.split("=", 1) for l in out.splitlines() if "=" in l)["password"]
req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/workflows/{wf}/dispatches", method="POST",
                             data=json.dumps({"ref": "main", **({"inputs": inputs} if inputs else {})}).encode(),
                             headers={"authorization": "Bearer " + tok, "accept": "application/vnd.github+json"})
print("started" if urllib.request.urlopen(req, timeout=30).status == 204 else "failed", wf, inputs)
