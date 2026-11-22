#!/bin/sh
# tools/test-launcher-entry.sh : the Dock badge listener parses LauncherEntry updates (run by tools/check)
python3 -I "$(dirname "$0")/../shell/scripts/yukishell-launcher-entry.py" --test || { echo "Error: launcher entry parse"; exit 1; }
