#!/usr/bin/env python3
"""Remove `font.family: X.fontForWeight(font.weight, fam)` binding loops from the QML.

Reading `font.weight` inside a `font.family` binding makes the two depend on each other (both live in the same `font`
group), so Qt re-evaluates it in a loop (thousands of "Binding loop detected for property font.family" warnings).
This passes the item's OWN explicit weight expression instead (or Font.Normal when it sets none)."""
import re, sys, pathlib

CALL = re.compile(r'(?:\bfontForWeight|\bFonts\.forWeight)\(font\.weight,')

def mask(src):
    """Same-length copy where comments and string contents are blanked, so braces/colons inside them are ignored."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i); j = n if j < 0 else j
            out.append(' ' * (j - i)); i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2); j = n if j < 0 else j + 2
            out.append(''.join(ch if ch == '\n' else ' ' for ch in src[i:j])); i = j
        elif c == '/' and re.search(r'(?:^|[(,=:\[!&|?{};+\-*%<>~^]|\breturn|\btypeof)\s*$', ''.join(out)[-40:]):
            j = i + 1; cls = False
            while j < n and src[j] != '\n':
                ch = src[j]
                if ch == '\\': j += 2; continue
                if ch == '[': cls = True
                elif ch == ']': cls = False
                elif ch == '/' and not cls: break
                j += 1
            out.append('/' + ' ' * (j - i - 1) + '/'); i = j + 1
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            out.append(c + ''.join(ch if ch == '\n' else ' ' for ch in src[i+1:j]) + c); i = j + 1
        else:
            out.append(c); i += 1
    return ''.join(out)

def enclosing_block(m, pos):
    depth = 0
    for i in range(pos - 1, -1, -1):
        if m[i] == '}': depth += 1
        elif m[i] == '{':
            if depth == 0: start = i; break
            depth -= 1
    else: return None
    depth = 0
    for j in range(start, len(m)):
        if m[j] == '{': depth += 1
        elif m[j] == '}':
            depth -= 1
            if depth == 0: return start, j
    return None

def direct_prop(src, m, start, end, name):
    """Value of `name: <expr>` declared directly in this block (not in a nested child), or None."""
    depth, i = 0, start + 1
    pat = re.compile(r'(?<![\w.])' + re.escape(name) + r'\s*:\s*')
    while i < end:
        if m[i] == '{': depth += 1
        elif m[i] == '}': depth -= 1
        elif depth == 0:
            mm = pat.match(m, i)
            if mm:
                k = mm.end(); d = 0; e = k
                while e < end:
                    ch = m[e]
                    if ch in '([{': d += 1
                    elif ch in ')]}':
                        if d == 0: break
                        d -= 1
                    elif d == 0 and ch in ';\n': break
                    e += 1
                return src[k:e].strip()
        i += 1
    return None

def process(path, apply):
    src = path.read_text(); m = mask(src)
    edits, stats = [], dict(explicit=0, bold=0, normal=0, skipped=0)
    for mt in CALL.finditer(m):
        blk = enclosing_block(m, mt.start())
        if not blk: stats['skipped'] += 1; continue
        w = direct_prop(src, m, blk[0], blk[1], 'font.weight')
        if w is None and re.search(r'(?<![\w.])font\s*\{', m[blk[0]:blk[1]]): stats['skipped'] += 1; continue
        if w is not None and 'font.weight' in w: stats['skipped'] += 1; continue
        if w is None:
            b = direct_prop(src, m, blk[0], blk[1], 'font.bold')
            if b is not None and b.replace(' ', '') == 'true': w = 'Font.Bold'; stats['bold'] += 1
            elif b is not None: stats['skipped'] += 1; continue
            else: w = 'Font.Normal'; stats['normal'] += 1
        else: stats['explicit'] += 1
        edits.append((mt.start(), mt.end() - 1, mt.group(0).replace('font.weight', w)))
    if apply:
        for a, b, rep in sorted(edits, reverse=True): src = src[:a] + rep + src[b + 1:]
        path.write_text(src)
    return stats

if __name__ == '__main__':
    apply = '--apply' in sys.argv
    for f in sorted(pathlib.Path('.').glob('*.qml')):
        if CALL.search(f.read_text()):
            print(f.name, process(f, apply))
