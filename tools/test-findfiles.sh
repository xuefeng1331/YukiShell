#!/bin/sh
# tools/test-findfiles.sh : checks shell/scripts/yukishell-findfiles.sh (ranking, folders, hidden paths) with fd and with find
s=$(cd "$(dirname "$0")/.." && pwd)/shell/scripts/yukishell-findfiles.sh
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/a/b/Report" "$t/.hidden" "$t/x"
touch "$t/a/b/old report.txt" "$t/report" "$t/x/Reports.pdf" "$t/.hidden/report.txt" "$t/a/unrelated.txt"
exp="$t/report
$t/a/b/Report/
$t/x/Reports.pdf
$t/a/b/old report.txt"
for nofd in "" 1; do
    out=$(YUKI_NO_FD=$nofd sh "$s" report "$t")
    [ "$out" = "$exp" ] || { printf 'Error (YUKI_NO_FD=%s): got\n%s\nwant\n%s\n' "$nofd" "$out" "$exp"; exit 1; }
done
[ -z "$(sh "$s" "" "$t")" ] || { echo "Error: empty query listed files"; exit 1; }
echo "findfiles ok"
