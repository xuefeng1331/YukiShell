#!/bin/sh
state="$HOME/.config/yukishell/wallpaper-video"
cache="$HOME/.cache/yukishell"
mkdir -p "$HOME/.config/yukishell" "$cache/frames" "$cache/anim"

igpu=""
for n in /dev/dri/renderD*; do
    [ "$(basename "$(readlink -f "/sys/class/drm/$(basename "$n")/device/driver")")" = i915 ] && { igpu="$n"; break; }
    [ "$(basename "$(readlink -f "/sys/class/drm/$(basename "$n")/device/driver")")" = xe ] && { igpu="$n"; break; }
done
MPV_OPTS="no-audio load-scripts=no loop-file=inf profile=fast panscan=1.0 hwdec=vaapi${igpu:+ vaapi-device=$igpu} vd-lavc-threads=2 framedrop=vo video-sync=display-resample interpolation=yes tscale=oversample"

is_video() { case "$(printf %s "$1" | tr 'A-Z' 'a-z')" in *.mp4|*.webm|*.mkv|*.mov|*.m4v) return 0 ;; esac; return 1; }
key_of() { printf '%s:%s' "$1" "$(stat -c %Y "$1" 2>/dev/null)" | md5sum | cut -c1-16; }

valid_video() { [ -s "$1" ] && [ "$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$1" 2>/dev/null | head -n1)" = video ]; }
with_lock() {
    l="$1"; shift
    if command -v flock >/dev/null 2>&1; then ( flock 8; "$@" ) 8>"$l"; else "$@"; fi
}

frame_for() {
    out="$cache/frames/$(key_of "$1").png"
    if [ ! -s "$out" ]; then
        tmp="$out.$$.part.png"
        { ffmpeg -loglevel error -y -ss 1 -i "$1" -frames:v 1 "$tmp" </dev/null \
            || ffmpeg -loglevel error -y -i "$1" -frames:v 1 "$tmp" </dev/null; } && mv -f "$tmp" "$out" || rm -f "$tmp"
    fi
    printf '%s' "$out"
}

preview_for() {
    k=$(key_of "$1"); mkdir -p "$cache/thumbs"
    t="$cache/thumbs/$k.jpg"; w="$cache/thumbs/$k.webp"
    if [ ! -s "$t" ]; then
        ffmpeg -loglevel error -y -ss 1 -i "$1" -frames:v 1 -vf "scale=480:-2" "$t.$$.part.jpg" </dev/null && mv -f "$t.$$.part.jpg" "$t" || rm -f "$t.$$.part.jpg"
    fi
    if [ ! -s "$w" ]; then
        nice -n 15 ffmpeg -loglevel error -y -t 4 -i "$1" -an -vf "fps=12,scale=360:-2:flags=lanczos" \
            -c:v libwebp_anim -lossless 0 -q:v 60 -loop 0 "$w.$$.part.webp" </dev/null && mv -f "$w.$$.part.webp" "$w" || rm -f "$w.$$.part.webp"
    fi
}

build_glass() {
    [ -s "$2" ] && return 0
    tmp="$2.$$.part.webp"
    nice -n 15 ionice -c3 ffmpeg -loglevel error -y -i "$1" -an -vf "fps=15,scale=480:-2:flags=bilinear" \
        -c:v libwebp_anim -lossless 0 -q:v 45 -compression_level 3 -loop 0 "$tmp" </dev/null && mv -f "$tmp" "$2" || rm -f "$tmp"
}
glass_for() {
    k=$(key_of "$1"); g="$cache/anim/$k-glass.webp"
    with_lock "$g.lock" build_glass "$1" "$g"
    printf '%s' "$g"
}

proxy_for() {
    d="$cache/glass"; mkdir -p "$d"
    k=$(printf '%s:%s:%s:%s' "$1" "$(stat -c %Y "$1" 2>/dev/null)" 720 60 | md5sum | cut -c1-16)
    o="$d/$k.mp4"; [ -s "$o" ] && return 0
    t="$d/$k.$$.part.mp4"
    nice -n 15 ionice -c3 ffmpeg -loglevel error -y -i "$1" -an -sn -dn -vf "scale='min(720,iw)':-2" -fpsmax 60 -c:v libx264 -preset veryfast \
        -crf 30 -pix_fmt yuv420p -g 60 -movflags +faststart -f mp4 "$t" </dev/null && mv -f "$t" "$o" || rm -f "$t"
}

target_width() {
    w=$(hyprctl -j monitors 2>/dev/null | jq '[.[] | (.width / .scale)] | max | floor' 2>/dev/null)
    case "$w" in ''|null|*[!0-9]*) w=1920 ;; esac
    [ "$w" -lt 1280 ] && w=1280
    printf '%s' "$w"
}

build_anim() {
    valid_video "$2" && return 0
    rm -f "$2"
    tmp="$2.$$.part.mp4"
    nice -n 15 ionice -c3 ffmpeg -loglevel error -y -i "$1" -an \
        -vf "scale='min($3,iw)':-2:flags=lanczos" -fpsmax 60 \
        -c:v libx264 -preset faster -crf 21 -pix_fmt yuv420p -g 60 -movflags +faststart "$tmp" </dev/null \
        && valid_video "$tmp" && mv -f "$tmp" "$2" || rm -f "$tmp"
}
anim_path() { printf '%s' "$cache/anim/$(key_of "$1")-$(target_width)-f60.mp4"; }
anim_for() {
    tw=$(target_width)
    out=$(anim_path "$1")
    valid_video "$out" || with_lock "$out.lock" build_anim "$1" "$out" "$tw"
    valid_video "$out" || { printf '%s' "$1"; return; }
    printf '%s' "$out"
}

awww_ready() {
    awww query >/dev/null 2>&1 && return 0
    pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/dev/null 2>&1 & }
    for i in 1 2 3 4 5 6 7 8 9 10; do awww query >/dev/null 2>&1 && return 0; sleep 0.3; done
    return 1
}

supfile="$cache/wallsup.pid"
stop_video() {
    if [ -f "$supfile" ]; then
        while read -r g; do
            [ -n "$g" ] && tr '\0' ' ' < "/proc/$g/cmdline" 2>/dev/null | grep -q ' wallsup ' && kill -TERM -- "-$g" 2>/dev/null
        done < "$supfile"
        rm -f "$supfile"
    fi
    pkill -CONT -x mpvpaper 2>/dev/null
    pkill -TERM -x mpvpaper 2>/dev/null
    for i in 1 2 3 4 5; do pgrep -x mpvpaper >/dev/null || break; sleep 0.1; done
    pkill -KILL -x mpvpaper 2>/dev/null
}

video_running() {
    [ "$(cat "$state" 2>/dev/null)" = "$1" ] && [ -f "$supfile" ] || return 1
    while read -r g; do
        [ -n "$g" ] && tr '\0' ' ' < "/proc/$g/cmdline" 2>/dev/null | grep -q ' wallsup ' && pgrep -x mpvpaper >/dev/null && return 0
    done < "$supfile"
    return 1
}

start_video() {
    src="$1"; play="$2"
    valid_video "$play" || play="$src"
    stop_video
    printf '%s\n' "$play" > "$HOME/.config/yukishell/wallpaper-video-play"
    outs=$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' 2>/dev/null); [ -n "$outs" ] || outs=ALL
    run="${XDG_RUNTIME_DIR:-/tmp}"
    setsid sh -c '
        echo $$ >> "$5"
        src="$1"; play="$2"; state="$3"; opts="$4"; run="$6"; pausebin="$7"; shift 7
        playfile="$HOME/.config/yukishell/wallpaper-video-play"
        for out in "$@"; do
            (
                fails=0
                while [ "$(cat "$state" 2>/dev/null)" = "$src" ] && [ "$fails" -lt 5 ]; do
                    t=$(date +%s)
                    rm -f "$run/yukishell-mpv-$out.sock"      # a stale socket (player was killed) would fool the wait below
                    # a fresh player starts playing, but the shell only sends "pause" when ITS state changes: if the desktop is already
                    # covered, tell the new player as soon as its socket exists (the shell lists the covered outputs in this file)
                    (
                        n=0; while [ ! -S "$run/yukishell-mpv-$out.sock" ] && [ "$n" -lt 40 ]; do n=$((n + 1)); sleep 0.25; done
                        grep -qx "$out" "$run/yukishell-wallpaused" 2>/dev/null && "$pausebin" "$out" pause
                    ) >/dev/null 2>&1 </dev/null &
                    hz=$(hyprctl -j monitors 2>/dev/null | jq -r --arg o "$out" ".[] | select(.name == \$o) | .refreshRate" 2>/dev/null | head -n1)
                    case "$hz" in [0-9]*) hzopt=" display-fps-override=$hz" ;; *) hzopt="" ;; esac
                    # a restart plays the file the wallpaper switched to last (the optimized copy, once swap_video moved to it)
                    p=$(cat "$playfile" 2>/dev/null); [ -s "$p" ] || p="$play"
                    mpvpaper -o "$opts$hzopt input-ipc-server=$run/yukishell-mpv-$out.sock" "$out" "$p" >/dev/null 2>&1 </dev/null
                    [ "$(cat "$state" 2>/dev/null)" = "$src" ] || exit 0
                    [ $(( $(date +%s) - t )) -lt 10 ] && fails=$((fails + 1)) || fails=0
                    sleep 1
                done
            ) &
        done
        wait
    ' wallsup "$src" "$play" "$state" "$MPV_OPTS" "$supfile" "$run" "$(dirname "$(readlink -f "$0")")/yukishell-wallpause.sh" $outs >/dev/null 2>&1 </dev/null 8>&- &
}
swap_video() {
    printf '%s\n' "$1" > "$HOME/.config/yukishell/wallpaper-video-play"
    command -v python3 >/dev/null 2>&1 || return 0
    for sock in "${XDG_RUNTIME_DIR:-/tmp}"/yukishell-mpv-*.sock; do
        [ -S "$sock" ] || continue
        python3 -I - "$sock" "$1" <<'PY' >/dev/null 2>&1
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(1)
buf = b""
def ask(cmd, rid):
    global buf
    s.sendall((json.dumps({"command": cmd, "request_id": rid}) + "\n").encode())
    while True:                                  # mpv also writes events on the socket: wait for our own answer
        while b"\n" not in buf:
            buf += s.recv(4096)
        line, buf = buf.split(b"\n", 1)
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("request_id") == rid:
            return o.get("data")
try:
    s.connect(sys.argv[1])
    pos = ask(["get_property", "time-pos"], 1) or 0
    paused = ask(["get_property", "pause"], 2) is True
    ask(["loadfile", sys.argv[2], "replace", -1, "start=%.3f,pause=%s" % (pos, "yes" if paused else "no")], 3)
except (OSError, ValueError):
    pass
PY
    done
}

change_video() { with_lock "$cache/wallpaper-start.lock" "$@"; }

case "$1" in
    --prepare-all)
        shift
        exec 7>"$cache/prepare.lock"
        command -v flock >/dev/null 2>&1 && { flock -n 7 || exit 0; }
        for v do [ -f "$v" ] && is_video "$v" && preview_for "$v"; done
        for v do
            [ -f "$v" ] && is_video "$v" || continue
            frame_for "$v" >/dev/null; anim_for "$v" >/dev/null; proxy_for "$v"
        done
        exit 0 ;;
    --prepare) [ -f "$2" ] && is_video "$2" && { preview_for "$2"; frame_for "$2" >/dev/null; a=$(anim_for "$2"); glass_for "$a" >/dev/null; }; exit 0 ;;
    --restore)
        [ -f "$state" ] || exit 0
        f=$(cat "$state")
        [ -f "$f" ] || { rm -f "$state"; exit 0; } ;;
    *) f="$1" ;;
esac
[ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }

if is_video "$f"; then
    still=$(frame_for "$f")
    if video_running "$f"; then printf '%s\n' "$still"; exit 0; fi
    printf '%s\n' "$f" > "$state"
    put_still() {
        if awww_ready && [ -s "$still" ] && ! { [ "$1" = --restore ] && awww query 2>/dev/null | grep -qF -- "$still"; }; then
            awww img "$still" --transition-type grow --transition-duration 0.8 >/dev/null 2>&1
        fi
    }
    if [ "$1" = --restore ]; then put_still --restore >/dev/null 2>&1 </dev/null & else put_still; fi
    printf '%s\n' "$still"
    (
        copy=$(anim_path "$f")
        if valid_video "$copy"; then play="$copy"; else play="$f"; fi
        [ "$(cat "$state" 2>/dev/null)" = "$f" ] || exit 0
        change_video start_video "$f" "$play"
        if [ "$play" = "$f" ]; then
            play=$(anim_for "$f")
            [ "$(cat "$state" 2>/dev/null)" = "$f" ] || exit 0
            [ "$play" != "$f" ] && change_video swap_video "$play"
        fi
        g=$(glass_for "$play")
        [ "$(cat "$state" 2>/dev/null)" = "$f" ] && [ -s "$g" ] && printf '%s\n' "$g" > "$HOME/.config/yukishell/wallpaper-video-glass"
    ) >/dev/null 2>&1 </dev/null &
else
    rm -f "$state" "$HOME/.config/yukishell/wallpaper-video-play" "$HOME/.config/yukishell/wallpaper-video-glass"
    change_video stop_video
    awww_ready && awww img "$f" --transition-type grow --transition-duration 0.9 >/dev/null 2>&1
    printf '%s\n' "$f"
fi
