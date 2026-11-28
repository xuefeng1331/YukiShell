#!/bin/sh
# greeter-list.sh [data dir]: one line of JSON for the login screen (greeter.qml): the accounts it offers, the sessions it can
# start and who signed in last.
#   {"users":[{user,name,base,mtime,profile}], "sessions":[{id,name,exec,desktop}], "last":"<user>"}
# A profile counts only when the account itself wrote it (yuki-greeter-sync): the owner of the data folder keeps theirs at
# the top, everyone else in users/<name>/, and a folder another account made under that name is ignored. Accounts that
# never synced are offered with their name only.
d="${1:-/var/lib/yukigreet}"
command -v jq >/dev/null 2>&1 || { echo '{"users":[],"sessions":[],"last":""}'; exit 0; }
owner() { stat -c %U "$1" 2>/dev/null; }
tab=$(printf '\t')

users=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 "\t" $5 }' |
    while IFS="$tab" read -r u gecos; do
        n=${gecos%%,*}; n=${n:-$u}; base=""
        if [ "$(owner "$d")" = "$u" ] && [ -f "$d/profile.json" ] && [ "$(owner "$d/profile.json")" = "$u" ]; then base=$d
        elif [ -f "$d/users/$u/profile.json" ] && [ "$(owner "$d/users/$u")" = "$u" ] && [ "$(owner "$d/users/$u/profile.json")" = "$u" ]; then base=$d/users/$u
        fi
        if [ -n "$base" ] && p=$(jq -c --arg u "$u" 'select(type == "object" and .user == $u)' "$base/profile.json" 2>/dev/null) && [ -n "$p" ]; then
            jq -nc --arg u "$u" --arg n "$n" --arg b "$base" --argjson m "$(stat -c %Y "$base/profile.json")" --argjson p "$p" \
                '{user: $u, name: ($p.name // $n), base: $b, mtime: $m, profile: $p}'
        else
            jq -nc --arg u "$u" --arg n "$n" '{user: $u, name: $n, base: "", mtime: 0, profile: {}}'
        fi
    done | jq -sc '.')

# desktop sessions, as display managers list them: hidden ones and ones whose program is missing (TryExec) are left out
sessions=$(for f in /usr/share/wayland-sessions/*.desktop; do
        [ -f "$f" ] || continue
        v() { sed -n "/^\[Desktop Entry\]/,/^\[/ s/^$1=//p" "$f" | head -n1; }
        [ "$(v Hidden)" = true ] || [ "$(v NoDisplay)" = true ] && continue
        t=$(v TryExec); [ -n "$t" ] && ! command -v "$t" >/dev/null 2>&1 && continue
        e=$(v Exec); [ -n "$e" ] || continue
        id=${f##*/}; id=${id%.desktop}
        jq -nc --arg id "$id" --arg n "$(v Name)" --arg e "$e" --arg dn "$(v DesktopNames)" \
            '{id: $id, name: (if $n == "" then $id else $n end), exec: $e, desktop: ($dn | rtrimstr(";") | gsub(";"; ":"))}'
    done | jq -sc '.')

jq -nc --argjson u "${users:-[]}" --argjson s "${sessions:-[]}" \
    '{users: $u, sessions: $s, last: ([$u[] | select(.mtime > 0)] | max_by(.mtime) | .user // "")}'
