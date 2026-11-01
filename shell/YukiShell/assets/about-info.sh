#!/bin/sh

dmi() { cat "/sys/class/dmi/id/$1" 2>/dev/null | tr -d '\n'; }
junk() {
    case "$(printf %s "$1" | tr 'A-Z' 'a-z')" in
        ""|none|"not applicable"|"not specified"|unknown*|*"to be filled"*|*"o.e.m"*|*"system product"*|*"system version"*|*"default string"*|*"type1productconfigid"*|"n/a"|"-") return 0 ;;
    esac
    return 1
}
clean_vendor() { printf %s "$1" | sed -e 's/,\? *\(Inc\|INC\|Corporation\|CORPORATION\|Corp\|CO\.\?, *LTD\|Co\., *Ltd\|Computer\|COMPUTER\)\.\?//g' -e 's/  */ /g' -e 's/^ //; s/ $//'; }

[ -r /etc/os-release ] && . /etc/os-release || { [ -r /usr/lib/os-release ] && . /usr/lib/os-release; }

vendor=$(dmi sys_vendor); pname=$(dmi product_name); pver=$(dmi product_version)
bvendor=$(dmi board_vendor); bname=$(dmi board_name)
model=""
if ! junk "$pname"; then
    model="$pname"
    if ! junk "$pver" && printf %s "$vendor" | grep -qi lenovo; then model="$pver"; fi
elif ! junk "$bname"; then
    model="$(clean_vendor "$bvendor") $bname"; junk "$bvendor" && model="$bname"
fi
vend=""; junk "$vendor" || vend=$(clean_vendor "$vendor")
[ -n "$vend" ] || { junk "$bvendor" || vend=$(clean_vendor "$bvendor"); }

kind="Computer"
ct=$(dmi chassis_type)
case "$ct" in
    8|9|10|14|31|32) kind="Laptop" ;;
    30) kind="Tablet" ;;
    3|4|5|6|7|13|15|16|17|23|24|35|36) kind="Desktop" ;;
    11) kind="Handheld" ;;
esac
if [ "$kind" = Computer ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then kind="Laptop"; fi
virt=$(systemd-detect-virt 2>/dev/null)
case "$virt" in ""|none) ;; *) kind="Virtual Machine" ;; esac
printf 'model=%s\n' "$model"
printf 'sub=%s\n' "$kind${vend:+ · $vend}"

cpu=$(awk -F: '/^model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)
[ -n "$cpu" ] || cpu=$(lscpu 2>/dev/null | sed -n 's/^Model name: *//p' | head -n1)
[ -n "$cpu" ] || cpu=$(awk -F: '/^(Hardware|Processor|cpu model)/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)
cpu=$(printf %s "$cpu" | sed -e 's/(R)//g; s/(TM)//g; s/ CPU / /; s/ CPU$//; s/ @ .*//; s/ with Radeon.*//; s/ w\/ .*//; s/  */ /g; s/^ //; s/ $//')
threads=$(nproc --all 2>/dev/null || grep -c '^processor' /proc/cpuinfo)
cores=$(lscpu -p=CORE,SOCKET 2>/dev/null | grep -v '^#' | sort -u | wc -l)
printf 'cpu=%s\n' "${cpu:-Unknown}"
if [ "${cores:-0}" -gt 0 ] 2>/dev/null && [ "${threads:-0}" -gt 0 ] 2>/dev/null; then
    if [ "$cores" = "$threads" ]; then printf 'cpusub=%s cores\n' "$cores"; else printf 'cpusub=%s cores, %s threads\n' "$cores" "$threads"; fi
fi

gpu=""
if command -v lspci >/dev/null 2>&1; then
    gpu=$(lspci -mm 2>/dev/null | awk -F'"' 'tolower($2) ~ /vga|3d|display/ {
        v=$4; d=$6
        if (match(d, /\[[^]]*\]/)) d=substr(d, RSTART+1, RLENGTH-2)
        if (v ~ /AMD|ATI|Advanced Micro/) v="AMD"; else if (v ~ /NVIDIA/) v="NVIDIA"; else if (v ~ /Intel/) v="Intel"
        sub(/ Corporation.*/, "", v)
        print v " " d }' | awk '!seen[$0]++' | head -n 3 | paste -sd'|' -)
fi
if [ -z "$gpu" ]; then
    for c in /sys/class/drm/card[0-9]; do
        [ -r "$c/device/vendor" ] || continue
        case "$(cat "$c/device/vendor")" in 0x10de) n="NVIDIA Graphics" ;; 0x1002) n="AMD Graphics" ;; 0x8086) n="Intel Graphics" ;; *) n="" ;; esac
        [ -n "$n" ] && gpu="${gpu:+$gpu|}$n"
    done
fi
printf 'gpu=%s\n' "${gpu:-Unknown}"

awk '/^MemTotal/ {
    g = $2 / 1048576
    n = split("1 2 3 4 6 8 12 16 24 32 48 64 96 128 192 256 384 512 768 1024", s, " ")
    r = int(g + 0.5)
    for (i = 1; i <= n; i++) if (s[i] >= g) { r = s[i]; break }
    printf "mem=%d GB\n", r }' /proc/meminfo
df -B1 --output=size,avail / 2>/dev/null | awk 'NR==2 {
    t=$1; a=$2
    printf "disk=%s\ndisksub=%s available\n", f(t), f(a) }
    function f(b) { if (b >= 1e12) return sprintf("%.1f TB", b/1e12); return sprintf("%d GB", int(b/1e9 + 0.5)) }'
printf 'kernel=%s\n' "$(uname -r)"
osname="${NAME:-Linux}"
osname=$(printf %s "$osname" | sed -e 's/ GNU\/Linux$//; s/ Linux$//')
osver="${VERSION:-${VERSION_ID:-}}"
if [ -z "$osver" ]; then case "${BUILD_ID:-}" in rolling|"") osver="Rolling Release" ;; *) osver="$BUILD_ID" ;; esac; fi
printf 'osname=%s\nosver=%s\n' "$osname" "$osver"
printf 'pretty=%s\n' "${PRETTY_NAME:-Linux}"
printf 'logo=%s\n' "${LOGO:-}"
printf 'osid=%s\n' "${ID:-linux}"
printf 'home=%s\n' "${HOME_URL:-https://www.kernel.org}"
d=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
for f in linux-logo.svg linux-logo.png; do [ -f "$d/$f" ] && { printf 'userlogo=%s\n' "$d/$f"; break; }; done
