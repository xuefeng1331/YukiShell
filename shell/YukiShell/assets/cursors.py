#!/usr/bin/env python3
"""Cursor themes for Settings -> Cursor.

  cursors.py list                  JSON list of the installed cursor themes: [{id, name, dir, preview}]; preview is a PNG of the
                                   theme's arrow, extracted from its Xcursor file into ~/.cache/yukishell/cursors/ ("" if none)
  cursors.py install <folder>      copy a cursor theme folder (one with a "cursors" or "hyprcursors" folder inside, or holding one
                                   such theme) into ~/.local/share/icons, or turn a Windows cursor pack (.cur / .ani, GIF
                                   animations) into one (wincursor.py); prints the theme's id
  cursors.py apply <theme> <size>  use it now and from the next login: Hyprland (setcursor + the environment new apps get), GTK,
                                   KDE/Qt apps, X apps (the "default" theme), and ~/.config/yukishell/cursor for hypr/scripts/look.lua
"""
import json, os, re, shutil, struct, subprocess, sys, zlib

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
ICON_DIRS = [os.path.join(HOME, ".icons"), os.path.join(DATA, "icons")] + \
            [os.path.join(d, "icons") for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if d]
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "yukishell", "cursors")
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "yukishell", "cursor")

def is_theme(d):
    return os.path.isdir(os.path.join(d, "cursors")) or os.path.isfile(os.path.join(d, "manifest.hl")) \
        or os.path.isdir(os.path.join(d, "hyprcursors"))

def theme_name(d, fallback):
    for f in ("index.theme", "cursor.theme"):
        try:
            with open(os.path.join(d, f), errors="replace") as fh:
                for line in fh:
                    if line.startswith("Name="):
                        n = line[5:].strip()
                        if n:
                            return n
        except OSError:
            pass
    return fallback

def xcursor_png(path, out, want=48):
    """The image of an Xcursor file closest to `want` px, written as a PNG. False if it is not an Xcursor file."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        return False
    hsize, _, ntoc = struct.unpack_from("<III", data, 4)
    best = None
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, hsize + i * 12)
        if typ == 0xFFFD0002 and (best is None or abs(sub - want) < abs(best[0] - want)):
            best = (sub, pos)
    if not best:
        return False
    _, _, _, _, w, h, _, _, _ = struct.unpack_from("<IIIIIIIII", data, best[1])
    px = data[best[1] + 36: best[1] + 36 + w * h * 4]
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            b, g, r, a = px[(y * w + x) * 4: (y * w + x) * 4 + 4]
            if a and a < 255:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            rows += bytes((r, g, b, a))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(bytes(rows), 6)) + chunk(b"IEND", b"")
    tmp = out + ".tmp"
    with open(tmp, "wb") as f:
        f.write(png)
    os.replace(tmp, out)
    return True

def preview(tid, d):
    os.makedirs(CACHE, exist_ok=True)
    out = os.path.join(CACHE, tid.replace("/", "_") + ".png")
    for n in ("left_ptr", "default", "arrow", "top_left_arrow"):
        src = os.path.join(d, "cursors", n)
        if not os.path.exists(src):
            continue
        try:
            if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(src):
                return out
            if xcursor_png(src, out):
                return out
        except (OSError, struct.error, ValueError):
            pass
    return ""

def list_themes():
    seen, out = set(), []
    for base in ICON_DIRS:
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for n in names:
            d = os.path.join(base, n)
            if n in seen or n == "default" or not is_theme(d):
                continue
            seen.add(n)
            out.append({"id": n, "name": theme_name(d, n), "dir": d, "preview": preview(n, d)})
    out.sort(key=lambda t: t["name"].lower())
    print(json.dumps(out))

def install(src):
    src = os.path.abspath(os.path.expanduser(src))
    if not is_theme(src) and not any(is_theme(os.path.join(src, x)) for x in os.listdir(src)):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import wincursor
        if wincursor.is_pack(src):
            tmp = os.path.join(DATA, "icons", ".yukishell-converting")
            if os.path.exists(tmp):
                shutil.rmtree(tmp)
            title = wincursor.convert(src, tmp)
            tid = re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-") or "Custom-Cursor"
            dest = os.path.join(DATA, "icons", tid)
            if os.path.exists(dest):
                shutil.rmtree(dest)
            os.rename(tmp, dest)
            print(tid)
            return
    if not is_theme(src):
        subs = [os.path.join(src, s) for s in sorted(os.listdir(src)) if is_theme(os.path.join(src, s))]
        if not subs:
            sys.exit("no cursor theme in " + src)
        src = subs[0]
    dest_base = os.path.join(DATA, "icons")
    os.makedirs(dest_base, exist_ok=True)
    tid = os.path.basename(src.rstrip("/"))
    dest = os.path.join(dest_base, tid)
    if os.path.realpath(dest) != os.path.realpath(src):
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.copytree(src, dest, symlinks=True)
    print(tid)

def run(*cmd):
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        pass

def apply(theme, size):
    size = str(max(12, min(128, int(float(size)))))
    run("hyprctl", "setcursor", theme, size)
    q = json.dumps
    run("hyprctl", "eval", f"hl.env('XCURSOR_THEME', {q(theme)}) hl.env('XCURSOR_SIZE', {q(size)}) hl.env('HYPRCURSOR_THEME', {q(theme)}) hl.env('HYPRCURSOR_SIZE', {q(size)})")
    run("gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme)
    run("gsettings", "set", "org.gnome.desktop.interface", "cursor-size", size)
    run("kwriteconfig6", "--file", "kcminputrc", "--group", "Mouse", "--key", "cursorTheme", theme)
    run("kwriteconfig6", "--file", "kcminputrc", "--group", "Mouse", "--key", "cursorSize", size)
    d = os.path.join(DATA, "icons", "default")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName=Default\nInherits={theme}\n")
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    with open(CONF, "w") as f:
        f.write(f"{theme}\n{size}\n")

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        list_themes()
    elif a[:1] == ["install"] and len(a) == 2:
        install(a[1])
    elif a[:1] == ["apply"] and len(a) == 3:
        apply(a[1], a[2])
    else:
        sys.exit(__doc__)
