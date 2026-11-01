#!/bin/sh
run="${XDG_RUNTIME_DIR:-/tmp}"; v=$([ "$2" = pause ] && echo true || echo false)

send() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -I - "$1" "$v" <<'PY' >/dev/null 2>&1
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(1)
try:
    s.connect(sys.argv[1])
    s.sendall(('{"command":["set_property","pause",%s]}\n' % sys.argv[2]).encode())
    s.recv(512)
except OSError:
    pass
PY
    elif command -v socat >/dev/null 2>&1; then
        printf '{"command":["set_property","pause",%s]}\n' "$v" | timeout 1 socat - "UNIX-CONNECT:$1" >/dev/null 2>&1
    else
        printf '{"command":["set_property","pause",%s]}\n' "$v" | timeout 1 nc -U -N "$1" >/dev/null 2>&1
    fi
}

for s in "$run"/yukishell-mpv-*.sock; do
    [ -S "$s" ] || continue
    case "$1" in all) ;; *) [ "$s" = "$run/yukishell-mpv-$1.sock" ] || continue ;; esac
    send "$s"
done
