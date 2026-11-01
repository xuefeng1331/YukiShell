#!/usr/bin/env python3
"""open-url.py URL: open a web link in the default browser and show it.

xdg-open hands the link to a browser that is already running, which opens it as a tab in its last used window, possibly on another
workspace: the click seemed to do nothing. After opening, this focuses the browser window the link went to (a new window if the
browser made one, else its most recently used one), so Hyprland switches to that workspace. With no browser running it is plain
xdg-open: the new window opens where the user is."""
import json, os, subprocess, sys, time

if len(sys.argv) < 2:
    sys.exit(0)
url = sys.argv[1]

def hc(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True).stdout

def browser_classes():
    """window classes the default browser may use: the desktop file's StartupWMClass and its name (chromium.desktop -> chromium)."""
    desk = subprocess.run(["xdg-settings", "get", "default-web-browser"], capture_output=True, text=True).stdout.strip()
    if not desk:
        return set()
    names = {desk[:-len(".desktop")].lower() if desk.endswith(".desktop") else desk.lower()}
    dirs = [os.path.expanduser("~/.local/share/applications")] + [d + "/applications" for d in
            os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")]
    for d in dirs:
        try:
            for line in open(os.path.join(d, desk)):
                if line.startswith("StartupWMClass="):
                    names.add(line.split("=", 1)[1].strip().lower())
            break
        except OSError:
            continue
    return names

def windows(classes):
    try:
        return [c for c in json.loads(hc("-j", "clients")) if c.get("mapped") and c.get("class", "").lower() in classes]
    except ValueError:
        return []

classes = browser_classes()
before = {c["address"] for c in windows(classes)}
subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
if not before:
    sys.exit(0)

target = None
for _ in range(5):
    time.sleep(0.12)
    wins = windows(classes)
    new = [c for c in wins if c["address"] not in before]
    if new:
        target = new[0]
        break
    shown = [c for c in wins if c.get("workspace", {}).get("id", -1) > 0] or wins
    target = min(shown, key=lambda c: c.get("focusHistoryID", 1 << 30), default=None)
if target:
    hc("dispatch", f'hl.dsp.focus({{ window = "address:{target["address"]}" }})')
