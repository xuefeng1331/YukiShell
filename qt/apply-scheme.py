#!/usr/bin/env python3
"""Copy a KDE colour scheme into kdeglobals, the way Plasma's colour settings do.

KDE apps (Dolphin's file view, for one) read their colours from the [Colors:*] groups in kdeglobals itself, not
from the scheme file that ColorScheme= points to. Without the groups they fall back to Breeze Light (a white view).
usage: apply-scheme.py <scheme.colors>
"""
import os, re, subprocess, sys

path = sys.argv[1]
name = os.path.splitext(os.path.basename(path))[0]
group, groups = None, {}
for raw in open(path, encoding="utf-8"):
    line = raw.strip()
    m = re.fullmatch(r"\[(.+)\]", line)
    if m:
        group = m.group(1); groups.setdefault(group, []); continue
    if group and "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1); groups[group].append((k, v))

def write(g, k, v):
    subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", g, "--key", k, v], check=True)

for g, kv in groups.items():
    if g == "General":
        continue
    for k, v in kv:
        write(g, k, v)
write("General", "ColorScheme", name)
