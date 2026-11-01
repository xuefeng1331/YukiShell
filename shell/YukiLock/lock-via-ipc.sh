#!/bin/sh
set -u

get_state() {
    qs -c YukiLock ipc call lockscreen state 2>/dev/null || true
}

lock_now() {
    exec qs -c YukiLock ipc call lockscreen lock
}

state=$(get_state)
case "$state" in
    ready)
        lock_now
        ;;
    busy)
        exit 0
        ;;
    stopping)
        tries=0
        while [ "$state" = "stopping" ] && [ "$tries" -lt 60 ]; do
            sleep 0.1
            state=$(get_state)
            tries=$((tries + 1))
        done
        if [ "$state" = "stopping" ]; then
            printf '%s\n' 'YukiLock is still shutting down; try the lock key again in a moment.' >&2
            exit 1
        fi
        ;;
esac

YUKILOCK_DAEMON=1 qs -c YukiLock >/dev/null 2>&1 &
daemon_pid=$!
tries=0
while [ "$tries" -lt 60 ]; do
    state=$(get_state)
    case "$state" in
        ready) lock_now ;;
        busy) exit 0 ;;
    esac
    if ! kill -0 "$daemon_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
    tries=$((tries + 1))
done

printf '%s\n' 'YukiLock IPC did not become ready. Check that Quickshell can load the YukiLock config.' >&2
exit 1
