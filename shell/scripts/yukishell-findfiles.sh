#!/bin/sh
# yukishell-findfiles.sh QUERY [DIR]: files and folders under DIR (default $HOME) whose name contains QUERY, ignoring case and
# hidden paths. Folders end in "/". Best matches first: the exact name, then names that start with QUERY, then the shallowest.
q=$1; dir=${2:-$HOME}
[ -n "$q" ] || exit 0
fd=$([ -n "$YUKI_NO_FD" ] || command -v fd || command -v fdfind)   # YUKI_NO_FD=1: use find (tests)
if [ -n "$fd" ]; then
    "$fd" -i -F --max-results 400 -- "$q" "$dir" 2>/dev/null
else
    lq=$(printf '%s' "$q" | sed 's/[][*?\\]/\\&/g')
    find "$dir" -mindepth 1 -name '.*' -prune -o \( -type d -iname "*$lq*" -printf '%p/\n' \) -o \( -iname "*$lq*" -print \) 2>/dev/null | head -n 400
fi | awk -v q="$q" 'BEGIN { q = tolower(q) } {
    p = $0; sub(/\/$/, "", p); n = tolower(p); sub(/.*\//, "", n)
    r = (n == q) ? 0 : (index(n, q) == 1 ? 1 : 2)
    printf "%d\t%d\t%s\n", r, gsub(/\//, "/", p), $0
}' | sort -t "$(printf '\t')" -k1,1n -k2,2n -s | cut -f3- | head -n 40
