#!/usr/bin/env python3
"""qml-dupes.py file.qml...: find a signal handler or property declared twice in the same QML object.

qmllint doesn't flag this, but Qt refuses the whole file at load time ("Property value set multiple times"), and the
part of the shell that lives in it (the bar, the widgets...) is simply gone. Only `onSomething:` handlers and
`property ... name` declarations are looked at: JavaScript object literals reuse plain keys like `x:` all the time."""
import re, sys

HANDLER = re.compile(r"(on[A-Z]\w*)\s*:")
PROPERTY = re.compile(r"(?:readonly\s+|required\s+|default\s+)*property\s+[\w<>.]+\s+(\w+)")

def scan(path):
    src = open(path, encoding="utf-8").read()
    found = []
    stack = [{}]
    i, n, line = 0, len(src), 1
    at_start = True
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; at_start = True; i += 1; continue
        if c in " \t\r":
            i += 1; continue
        if src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j; continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2); seg = src[i:(n if j < 0 else j + 2)]
            line += seg.count("\n"); i += len(seg); continue
        if c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\": j += 1
                elif src[j] == "\n": line += 1
                j += 1
            i = j + 1; at_start = False; continue
        if c == "{":
            stack.append({}); i += 1; at_start = True; continue
        if c == "}":
            if len(stack) > 1: stack.pop()
            i += 1; at_start = False; continue
        if at_start:
            rest = src[i:i + 200]
            m = HANDLER.match(rest) or PROPERTY.match(rest)
            if m:
                key = m.group(1) if m.re is HANDLER else "property " + m.group(1)
                seen = stack[-1]
                if key in seen: found.append(f"{path}:{line}: {key} already set on line {seen[key]} (same object)")
                else: seen[key] = line
        at_start = c == ";"
        i += 1
    return found

out = []
for p in sys.argv[1:]:
    out += scan(p)
print("\n".join(out))
sys.exit(1 if out else 0)
