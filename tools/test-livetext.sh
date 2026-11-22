#!/bin/sh
# tools/test-livetext.sh : checks shell/scripts/yukishell-livetext.sh reads the text in a picture (skipped without tesseract / magick)
command -v tesseract >/dev/null && command -v magick >/dev/null || { echo "livetext skipped"; exit 0; }
s=$(cd "$(dirname "$0")/.." && pwd)/shell/scripts/yukishell-livetext.sh
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
magick -size 520x90 xc:white -fill black -pointsize 36 -annotate +20+58 "Hello Live Text 42" "$t/a.png"
out=$(sh "$s" en "$t/a.png")
[ "$out" = "Hello Live Text 42" ] || { printf 'Error: got [%s]\n' "$out"; exit 1; }
echo "livetext ok"
