#!/bin/sh
cd "$(dirname "$0")" || exit 1
QSB=$(command -v qsb || command -v qsb6 || echo /usr/lib/qt6/bin/qsb)
"$QSB" --qt6 -o glasstext.frag.qsb glasstext.frag && echo "built glasstext.frag.qsb"
