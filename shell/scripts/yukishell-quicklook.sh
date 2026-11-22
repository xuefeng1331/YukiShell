#!/bin/sh
# yukishell-quicklook.sh PATH: what Spotlight's preview shows. First line, tab separated:
#   kind (folder|image|text|pdf|video|audio|other)  mime  size-in-bytes  modified-epoch  thumbnail-path-or-empty  entry-count
# then, for a text file, its first lines.
p=$1
[ -e "$p" ] || exit 1
set -- $(stat -L -c '%s %Y' -- "$p" 2>/dev/null); size=${1:-0}; mtime=${2:-0}
if [ -d "$p" ]; then
    n=$(find "$p" -mindepth 1 -maxdepth 1 ! -name '.*' 2>/dev/null | wc -l)
    printf 'folder\tinode/directory\t%s\t%s\t\t%s\n' "$size" "$mtime" "$n"
    exit 0
fi
mime=$(file -Lb --mime-type -- "$p" 2>/dev/null)
dir="${XDG_RUNTIME_DIR:-/tmp}/yukishell-ql"; mkdir -p "$dir"
thumb="$dir/$(printf '%s' "$p$mtime" | md5sum | cut -c1-16).png"
kind=other
case "$mime" in
    image/*) kind=image; thumb=$p ;;
    application/pdf) kind=pdf; [ -s "$thumb" ] || pdftoppm -f 1 -l 1 -singlefile -png -scale-to 640 -- "$p" "${thumb%.png}" >/dev/null 2>&1 ;;
    video/*) kind=video; [ -s "$thumb" ] || ffmpegthumbnailer -s 640 -i "$p" -o "$thumb" >/dev/null 2>&1 ;;
    audio/*) kind=audio; [ -s "$thumb" ] || ffmpegthumbnailer -s 640 -i "$p" -o "$thumb" >/dev/null 2>&1 ;;   # the cover art, if any
    text/*|application/json|application/xml|application/javascript|application/x-shellscript|application/toml|inode/x-empty) kind=text ;;
esac
[ "$kind" = image ] || [ -s "$thumb" ] || thumb=
printf '%s\t%s\t%s\t%s\t%s\t\n' "$kind" "$mime" "$size" "$mtime" "$thumb"
[ "$kind" = text ] && head -c 3000 -- "$p" | head -n 60
exit 0
