#!/bin/sh
# tools/test-greeter-sync.sh : checks shell/bin/yuki-greeter-sync copies the login screen's profile (skipped without jq)
command -v jq >/dev/null || { echo "greeter sync skipped"; exit 0; }
s=$(cd "$(dirname "$0")/.." && pwd)/shell/bin/yuki-greeter-sync
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/home/.config/yukibar" "$t/out"
printf 'png' > "$t/home/.face"; printf 'jpg' > "$t/wall.jpg"
printf '{"wallpaperPath":"%s","use24h":false,"language":"vi","lockClockFont":"serif"}' "$t/wall.jpg" > "$t/home/.config/yukibar/settings.json"
HOME="$t/home" XDG_CONFIG_HOME= YUKIGREET_DIR="$t/out" sh "$s" || { echo "Error: sync failed"; exit 1; }
p="$t/out/profile.json"
[ "$(jq -r '[.user, .avatar, .wallpaper, .use24h, .language, .clock.f] | join(" ")' "$p")" = "$(id -un) avatar wallpaper false vi serif" ] \
    || { echo "Error: profile is"; cat "$p"; exit 1; }
[ "$(cat "$t/out/wallpaper")" = jpg ] && [ "$(cat "$t/out/avatar")" = png ] || { echo "Error: pictures not copied"; exit 1; }
# a picture given by the wallpaper script wins over settings.json, a separate lock wallpaper wins over both
printf 'new' > "$t/new.png"
HOME="$t/home" XDG_CONFIG_HOME= YUKIGREET_DIR="$t/out" sh "$s" "$t/new.png"
[ "$(cat "$t/out/wallpaper")" = new ] || { echo "Error: new wallpaper not copied"; exit 1; }
# no folder (the login screen isn't set up): nothing happens
HOME="$t/home" YUKIGREET_DIR="$t/none" sh "$s" && [ ! -e "$t/none" ] || { echo "Error: wrote without the folder"; exit 1; }
echo "greeter sync ok"
