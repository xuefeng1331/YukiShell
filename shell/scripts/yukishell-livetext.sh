#!/bin/sh
# yukishell-livetext.sh [ui-language] [image]: Live Text. Pick a part of the screen and the text in it goes to the clipboard.
# With an image, prints the text in that image instead. Reads English plus the UI language, when its tesseract data is installed.
case "$1" in vi*) l=vie ;; ja*) l=jpn ;; ko*) l=kor ;; ru*) l=rus ;; zh_TW*) l=chi_tra ;; zh*) l=chi_sim ;; *) l= ;; esac
command -v tesseract >/dev/null || { notify-send -a yukishell "Live Text" "Install tesseract and tesseract-data-eng to copy text from the screen."; exit 1; }
langs=eng
[ -n "$l" ] && tesseract --list-langs 2>/dev/null | grep -qx "$l" && langs="$l+eng"
ocr() { tesseract "$1" - -l "$langs" 2>/dev/null | tr -d '\f' | sed -e '/./,$!d'; }   # no page break, no blank lines on top
[ -n "$2" ] && { ocr "$2"; exit; }

region=$(slurp) || exit 0
text=$(grim -g "$region" -s 2 - | ocr -)   # twice the size: tesseract reads small screen text much better
if [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then
    notify-send -a yukishell "No text found" "There was nothing to read in that part of the screen."
    exit 0
fi
printf '%s' "$text" | wl-copy
notify-send -a yukishell "Text copied" "$(printf '%s' "$text" | head -c 300)"
