#!/usr/bin/env python3
"""Turn a Windows cursor pack into a Linux (Xcursor) cursor theme. Used by cursors.py when you add a theme in Settings -> Cursor.

  wincursor.py <pack folder> <output theme folder> [name]

A pack is a folder with .cur (static) and/or .ani (animated) cursors, usually with an install.inf that says which file is which
pointer (Arrow, Hand, IBeam, ...); without one the file names decide. Some packs ship their animations as GIFs next to the static
cursors instead (often drawn bigger, without the arrow): every GIF is matched to the static cursor it animates by comparing the
pictures, shrunk to the cursor's size, and the parts only the static cursor has (the arrow, the I-beam...) are drawn on every frame.

The theme gets each cursor in several sizes (pixel art is scaled without blurring) and every name Linux apps ask for.
"""
import os, re, struct, sys
import numpy as np
from PIL import Image

SIZES = (32, 48, 64, 96)

ROLE_NAMES = {
    "arrow": ["left_ptr", "default", "arrow", "top_left_arrow", "context-menu", "copy", "alias", "dnd-copy", "dnd-link", "dnd-move", "dnd-none", "right_ptr", "draft_large", "draft_small"],
    "help": ["help", "question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "appstarting": ["progress", "left_ptr_watch", "half-busy", "3ecb610c1bf2410f44200f48c40d3599", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd"],
    "wait": ["wait", "watch", "0426c94ea35c87780ff01dc239897213"],
    "crosshair": ["crosshair", "cross", "tcross", "cross_reverse", "diamond_cross", "cell", "plus", "zoom-in", "zoom-out", "color-picker"],
    "ibeam": ["text", "xterm", "ibeam", "vertical-text"],
    "nwpen": ["pencil", "draft"],
    "no": ["not-allowed", "no-drop", "forbidden", "crossed_circle", "circle", "dnd-no-drop", "03b6e0fcb3499374a867c041f52298f0"],
    "sizens": ["ns-resize", "size_ver", "v_double_arrow", "sb_v_double_arrow", "n-resize", "s-resize", "top_side", "bottom_side", "row-resize", "split_v", "00008160000006810000408080010102"],
    "sizewe": ["ew-resize", "size_hor", "h_double_arrow", "sb_h_double_arrow", "e-resize", "w-resize", "left_side", "right_side", "col-resize", "split_h", "028006030e0e7ebffc7f7070c0600140"],
    "sizenwse": ["nwse-resize", "size_fdiag", "bd_double_arrow", "nw-resize", "se-resize", "top_left_corner", "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "sizenesw": ["nesw-resize", "size_bdiag", "fd_double_arrow", "ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner", "fcf1c3c07ccb0010aaf1b8b0a77a8b0e"],
    "sizeall": ["move", "fleur", "all-scroll", "size_all", "grabbing", "closedhand", "dnd-ask", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "uparrow": ["up-arrow", "up_arrow", "center_ptr", "sb_up_arrow"],
    "hand": ["pointer", "hand", "hand1", "hand2", "pointing_hand", "grab", "openhand", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106"],
    "person": [],
    "pin": [],
}
NAME_HINTS = [("appstart", "appstarting"), ("working", "appstarting"), ("progress", "appstarting"), ("busy", "wait"), ("wait", "wait"),
              ("help", "help"), ("precision", "crosshair"), ("cross", "crosshair"), ("text", "ibeam"), ("beam", "ibeam"),
              ("hand", "hand"), ("link", "hand"), ("write", "nwpen"), ("pen", "nwpen"), ("unavail", "no"), ("no", "no"),
              ("vert", "sizens"), ("horz", "sizewe"), ("horiz", "sizewe"), ("dgn1", "sizenwse"), ("diagonal1", "sizenwse"),
              ("dgn2", "sizenesw"), ("diagonal2", "sizenesw"), ("move", "sizeall"), ("alt", "uparrow"), ("up", "uparrow"),
              ("person", "person"), ("pin", "pin"), ("normal", "arrow"), ("arrow", "arrow"), ("pointer", "arrow")]

def read_dib(blob):
    """A cursor's bitmap (a BMP without its file header, twice as tall: the colours, then a 1-bit transparency mask)."""
    hs, w, h2, _, bpp = struct.unpack_from("<IiiHH", blob, 0)
    ncol = struct.unpack_from("<I", blob, 32)[0] or (1 << bpp if bpp <= 8 else 0)
    h = abs(h2) // 2
    pal = [struct.unpack_from("<BBBB", blob, hs + 4 * i) for i in range(ncol)]
    p = hs + 4 * ncol
    stride = ((w * bpp + 31) // 32) * 4
    mstride = ((w + 31) // 32) * 4
    mask_at = p + stride * h
    out = np.zeros((h, w, 4), np.uint8)
    has_alpha = False
    for row in range(h):
        y = h - 1 - row
        line = blob[p + row * stride: p + (row + 1) * stride]
        mline = blob[mask_at + row * mstride: mask_at + (row + 1) * mstride]
        for x in range(w):
            if bpp == 32:
                b, g, r, a = line[x * 4: x * 4 + 4]
                has_alpha = has_alpha or a != 0
            elif bpp == 24:
                b, g, r = line[x * 3: x * 3 + 3]; a = 255
            else:
                bit = x * bpp
                idx = (line[bit // 8] >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
                b, g, r, _ = pal[idx] if idx < len(pal) else (0, 0, 0, 0); a = 255
            masked = mline and (mline[x // 8] >> (7 - x % 8)) & 1
            out[y, x] = (r, g, b, a)
            if masked and not (bpp == 32 and has_alpha):
                out[y, x, 3] = 0
    if bpp == 32 and has_alpha:
        pass
    return Image.fromarray(out, "RGBA")

def read_cur(data):
    """(RGBA image, hotspot x, y) of the biggest picture in a .cur / .ico file."""
    _, typ, n = struct.unpack_from("<HHH", data, 0)
    best = None
    for i in range(n):
        w, h, _, _, hx, hy, size, off = struct.unpack_from("<BBBBHHII", data, 6 + i * 16)
        w, h = w or 256, h or 256
        if best is None or w > best[0]:
            best = (w, h, hx, hy, size, off)
    w, h, hx, hy, size, off = best
    import io
    blob = data[off: off + size]
    if blob[:8] == b"\x89PNG\r\n\x1a\n":
        img = Image.open(io.BytesIO(blob)).convert("RGBA")
    else:
        img = read_dib(blob)
    if typ != 2:
        hx = hy = 0
    return img, hx, hy

def read_ani(data):
    """[(RGBA image, hotspot x, y, delay ms)] of a RIFF ACON (.ani) animated cursor."""
    frames, rate, seq, jif = [], None, None, 10
    def walk(buf):
        nonlocal rate, seq, jif
        p = 0
        while p + 8 <= len(buf):
            cid, size = buf[p:p + 4], struct.unpack_from("<I", buf, p + 4)[0]
            body = buf[p + 8: p + 8 + size]
            if cid == b"anih" and len(body) >= 36:
                jif = struct.unpack_from("<I", body, 28)[0] or 10
            elif cid == b"rate":
                rate = list(struct.unpack_from("<%dI" % (len(body) // 4), body))
            elif cid == b"seq ":
                seq = list(struct.unpack_from("<%dI" % (len(body) // 4), body))
            elif cid == b"LIST":
                walk(body[4:])
            elif cid == b"icon":
                frames.append(read_cur(body))
            p += 8 + size + (size & 1)
    walk(data[12:])
    order = seq if seq else list(range(len(frames)))
    out = []
    for i, f in enumerate(order):
        j = rate[i] if rate and i < len(rate) else jif
        img, hx, hy = frames[f]
        out.append((img, hx, hy, max(20, round(j * 1000 / 60))))
    return out

def read_gif(path, size):
    """The frames of a GIF shrunk to `size` px (nearest: pixel art stays sharp), with their delays (ms)."""
    im = Image.open(path)
    out = []
    try:
        while True:
            fr = im.convert("RGBA")
            if fr.width != size:
                fr = fr.resize((size, size), Image.NEAREST)
            out.append((fr, max(20, im.info.get("duration", 80))))
            im.seek(im.tell() + 1)
    except EOFError:
        pass
    return out

def arr(img):
    return np.asarray(img.convert("RGBA"), dtype=np.int16)

def shift(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    xs, xd = (0, dx) if dx >= 0 else (-dx, 0)
    ys, yd = (0, dy) if dy >= 0 else (-dy, 0)
    out[yd:h - ys if dy < 0 else h, xd:w - xs if dx < 0 else w] = a[ys:h - yd if dy > 0 else h, xs:w - xd if dx > 0 else w]
    return out

def score(s, f):
    """How badly a GIF frame matches a static cursor: pixels both show but differently, and pixels only the GIF shows. Pixels only
    the static cursor has (the arrow) cost a little, so the GIF that has the same symbol still wins."""
    so, fo = s[..., 3] > 127, f[..., 3] > 127
    both = so & fo
    diff = np.abs(s[..., :3] - f[..., :3]).sum(axis=2) > 90
    return float((both & diff).sum() + (fo & ~so).sum() + 0.25 * (so & ~fo).sum())

def best_shift(s, f, reach=12):
    best = (1e9, 0, 0)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            sc = score(s, shift(f, dx, dy))
            if sc < best[0]:
                best = (sc, dx, dy)
    return best

def glyph_mask(s, frames):
    """The pixels only the static cursor has (its arrow / symbol): shown there, transparent in every GIF frame. Specks of under 6
    pixels are left out (they are just where a moving part was in the static picture)."""
    union = np.zeros(s.shape[:2], bool)
    for f in frames:
        union |= f[..., 3] > 127
    m = (s[..., 3] > 127) & ~union
    h, w = m.shape
    keep = np.zeros_like(m)
    seen = np.zeros_like(m)
    for y in range(h):
        for x in range(w):
            if not m[y, x] or seen[y, x]:
                continue
            comp, stack = [], [(y, x)]
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop(); comp.append((cy, cx))
                for ny in (cy - 1, cy, cy + 1):
                    for nx in (cx - 1, cx, cx + 1):
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
            if len(comp) >= 6:
                for cy, cx in comp:
                    keep[cy, cx] = True
    return keep

def with_glyph(f, s, keep):
    out = f.copy()
    out[keep] = s[keep]
    return Image.fromarray(out.astype(np.uint8), "RGBA")

def xcursor(frames_by_size):
    """An Xcursor file: frames_by_size = {size: [(RGBA image, hx, hy, delay ms)]}."""
    chunks = []
    for size, frames in sorted(frames_by_size.items()):
        for img, hx, hy, delay in frames:
            w, h = img.size
            px = np.asarray(img.convert("RGBA"), dtype=np.uint32).reshape(-1, 4)
            a = px[:, 3]
            pix = np.stack([px[:, 2] * a // 255, px[:, 1] * a // 255, px[:, 0] * a // 255, a], axis=1).astype(np.uint8).tobytes()
            chunks.append((size, struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, min(hx, w - 1), min(hy, h - 1), delay) + bytes(pix)))
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(chunks))
    pos = 16 + 12 * len(chunks)
    toc, body = b"", b""
    for size, c in chunks:
        toc += struct.pack("<III", 0xFFFD0002, size, pos + len(body))
        body += c
    return head + toc + body

def scaled(frames, base):
    out = {}
    for size in SIZES:
        f = size / base
        out[size] = [(img.resize((size, size), Image.NEAREST) if size != img.width else img, round(hx * f), round(hy * f), d)
                     for img, hx, hy, d in frames]
    return out

def inf_roles(folder):
    """file name (lower case) -> role, and the scheme's name, from an install.inf"""
    path = next((os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith(".inf")), None)
    if not path:
        return {}, ""
    txt = open(path, "rb").read().decode("utf-8", "replace").replace("\r", "")
    strings = {}
    m = re.search(r"\[Strings\](.*?)(\n\[|\Z)", txt, re.S | re.I)
    if m:
        for line in m.group(1).split("\n"):
            kv = re.match(r'\s*(\w+)\s*=\s*"?([^"\n]*)"?', line)
            if kv:
                strings[kv.group(1).lower()] = kv.group(2).strip()
    roles = {}
    for role, var in re.findall(r'"Control Panel\\Cursors",\s*(\w+)\s*,\s*0x\w+\s*,\s*"[^"]*%(\w+)%"', txt, re.I):
        f = strings.get(var.lower(), "")
        if f and role.lower() in ROLE_NAMES and f.lower() not in roles:
            roles[f.lower()] = role.lower()
    return roles, strings.get("scheme_name", "")

def guess_role(name):
    n = os.path.splitext(name)[0].lower()
    for word, role in NAME_HINTS:
        if word in n:
            return role
    return None

def convert(pack, out, name="", log=False):
    folders = [pack] + [os.path.join(pack, d) for d in sorted(os.listdir(pack)) if os.path.isdir(os.path.join(pack, d))]
    curs, gifs, roles, scheme = {}, [], {}, ""
    for d in folders:
        r, s = inf_roles(d)
        roles.update(r); scheme = scheme or s
        for f in sorted(os.listdir(d)):
            p, low = os.path.join(d, f), f.lower()
            if low.endswith((".cur", ".ani")):
                curs[low] = p
            elif low.endswith(".gif"):
                gifs.append(p)
    if not curs:
        sys.exit("no .cur or .ani cursors in " + pack)

    cursors = {}
    for low, p in curs.items():
        role = roles.get(low) or guess_role(low)
        if not role or role in cursors:
            continue
        data = open(p, "rb").read()
        if data[:4] == b"RIFF":
            cursors[role] = read_ani(data)
        else:
            img, hx, hy = read_cur(data)
            cursors[role] = [(img, hx, hy, 0)]

    if gifs:
        base = max(fr[0][0].width for fr in cursors.values())
        anim = {g: [(arr(f), d) for f, d in read_gif(g, base)] for g in gifs}
        for role, fr in list(cursors.items()):
            if len(fr) > 1:
                continue
            img, hx, hy, _ = fr[0]
            if img.width != base:
                continue
            st = arr(img)
            def ranked(g, frames):
                r = best_shift(st, frames[0][0])
                return (r[0] - (10 if guess_role(os.path.basename(g)) == role else 0), r[0], r[1], r[2])
            cands = sorted((ranked(g, frames) + (g,) for g, frames in anim.items()), key=lambda t: t[0])
            _, sc, dx, dy, g = cands[0]
            if sc > base * base * 0.06:
                continue
            moved = [(shift(f, dx, dy), d) for f, d in anim[g]]
            keep = glyph_mask(st, [f for f, _ in moved])
            cursors[role] = [(with_glyph(f, st, keep), hx, hy, d) for f, d in moved]
            if log:
                print("  %-12s <- %s moved %d,%d (%d frames, %d px differ)" % (role, os.path.basename(g), dx, dy, len(moved), sc))

    cdir = os.path.join(out, "cursors")
    os.makedirs(cdir, exist_ok=True)
    for role, frames in cursors.items():
        names = ROLE_NAMES.get(role) or []
        if not names:
            continue
        base = frames[0][0].width
        with open(os.path.join(cdir, names[0]), "wb") as f:
            f.write(xcursor(scaled(frames, base)))
        for alias in names[1:]:
            link = os.path.join(cdir, alias)
            if not os.path.lexists(link):
                os.symlink(names[0], link)
    title = name or re.sub(r"\[[^\]]*\]", "", scheme).strip() or os.path.basename(os.path.abspath(pack))
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=%s\nComment=Converted from a Windows cursor pack\nInherits=Adwaita\n" % title)
    return title

def is_pack(folder):
    for d in [folder] + [os.path.join(folder, s) for s in os.listdir(folder) if os.path.isdir(os.path.join(folder, s))]:
        if any(f.lower().endswith((".cur", ".ani")) for f in os.listdir(d)):
            return True
    return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    print(convert(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "", log=True))
