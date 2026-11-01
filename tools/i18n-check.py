#!/usr/bin/env python3
"""List interface strings that have no translation.

Every user-visible string in the shell goes through I18n.tr("English text"); the languages live in
shell/YukiShell/lang/<code>.js (and, for the lock screen, shell/YukiLock/I18n.js). This finds each I18n.tr("...") literal in the
QML files and reports the ones a language does not have. With --json it prints {code: [missing, ...]} for scripting.

  tools/i18n-check.py            summary + the first few missing strings per language
  tools/i18n-check.py --all      every missing string
  tools/i18n-check.py --json     machine readable
Exit status 1 when anything is missing (handy in a pre-commit hook).
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
shell = root / "shell" / "YukiShell"

def unescape(raw):
    """the value of a QML / JS string literal body"""
    out, i = [], 0
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            n = raw[i + 1]
            if n == "u" and re.fullmatch(r"[0-9a-fA-F]{4}", raw[i + 2:i + 6]):
                out.append(chr(int(raw[i + 2:i + 6], 16))); i += 6; continue
            out.append({"n": "\n", "t": "\t"}.get(n, n)); i += 2; continue
        out.append(c); i += 1
    return "".join(out)

SAME = {"H:mm", "Spotlight", "YukiShell", "MacBook", "Tailscale", "\u25cf", "Rice", "Hyprland \u2022 Quickshell \u2022 Catppuccin Mocha"}

call = re.compile(r'I18n\.tr\(\s*(?:"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\')\s*[,)]')

used = {}
for f in sorted(shell.glob("*.qml")):
    for m in call.finditer(f.read_text(encoding="utf-8")):
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        used.setdefault(unescape(raw), f.name)

lua_desc = [re.compile(r'description = "([^"]+)"'), re.compile(r'\band "([^"]+)" or nil'),
            re.compile(r'^\s*bind\(.*?,\s*"([^"]+)"(?:,\s*\{[^}]*\})?\)\s*(?:--.*)?$', re.M),
            re.compile(r'\bdesc = "([^"]+)"'), re.compile(r'\bsection\("([^"]+)"\)')]
for f in sorted((root / "hypr" / "scripts").glob("*.lua")):
    text = f.read_text(encoding="utf-8")
    for rx in lua_desc:
        for m in rx.finditer(text):
            used.setdefault(m.group(1), f.name)

entry = re.compile(r'^\s*"((?:[^"\\\n]|\\.)*)"\s*:', re.M)
langs = {}
for f in sorted((shell / "lang").glob("*.js")):
    keys = set()
    for m in entry.finditer(f.read_text(encoding="utf-8")):
        keys.add(unescape(m.group(1)))
    langs[f.stem] = keys

lock = root / "shell" / "YukiLock"
lock_used = {}
for f in sorted(lock.glob("*.qml")):
    for m in call.finditer(f.read_text(encoding="utf-8")):
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        lock_used.setdefault(unescape(raw), f.name)
lock_langs = {}
if (lock / "I18n.js").exists():
    text = (lock / "I18n.js").read_text(encoding="utf-8")
    for bm in re.finditer(r'^    (\w+): \{\n(.*?)^    \}', text, re.M | re.S):
        lock_langs[bm.group(1)] = {unescape(k.group(1)) for k in entry.finditer(bm.group(2))}

missing = {code: sorted(k for k in used if k not in keys and k not in SAME) for code, keys in langs.items()}
for code, keys in lock_langs.items():
    lm = sorted(k for k in lock_used if k not in keys and k not in SAME)
    if lm:
        missing.setdefault(code, [])
        for k in lm:
            used.setdefault(k, lock_used[k])
            missing[code].append(k)
        missing[code].sort()
if "--json" in sys.argv:
    print(json.dumps(missing, ensure_ascii=False, indent=1))
else:
    print(f"{len(used)} translatable strings in the shell, {len(langs)} languages")
    for code, miss in missing.items():
        print(f"  {code:6} {len(used) - len(miss):4} translated, {len(miss):3} missing")
        for k in (miss if "--all" in sys.argv else miss[:5]):
            print(f"           - {k!r}   ({used[k]})")
sys.exit(1 if any(missing.values()) else 0)
