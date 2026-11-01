#!/usr/bin/env python3
"""Build assets/yukishell-logo.png (the rounded app icon) from assets/yukishell-icon.jpg.
usage: tools/make-logo.py   (run from anywhere; needs python-pillow)"""
import os
from PIL import Image, ImageDraw

assets = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "YukiShell", "assets")
S = 512
src = Image.open(os.path.join(assets, "yukishell-icon.jpg")).convert("RGBA")
side = min(src.size)
src = src.crop(((src.width - side) // 2, (src.height - side) // 2, (src.width + side) // 2, (src.height + side) // 2))
src = src.resize((S, S), Image.LANCZOS)
mask = Image.new("L", (S * 4, S * 4), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S * 4 - 1, S * 4 - 1), radius=int(S * 4 * 22 / 80), fill=255)
out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
out.paste(src, (0, 0), mask.resize((S, S), Image.LANCZOS))
out.save(os.path.join(assets, "yukishell-logo.png"))
print("wrote yukishell-logo.png", out.size)
