#!/usr/bin/env python3
"""imwatch.py: prints fcitx5's current input method (e.g. "keyboard-us", "pinyin", "bamboo") whenever it changes.

fcitx5 does not announce a switch: Ctrl+Space changes the input method without any D-Bus signal, and its tray item
(StatusNotifierItem) keeps the old icon and tooltip. So the menu bar asks: one D-Bus connection for the whole run,
org.fcitx.Fcitx.Controller1.CurrentInputMethod four times a second (an in-process call, no new program each time),
and a line on stdout only when the answer changes. "" means fcitx5 isn't running.

Started by YukiBar.qml (OwnedProcess: it ends with the shell) only while fcitx5's tray item is on the bar.
"""
import os
import sys

try:
    from gi.repository import Gio, GLib
except ImportError:
    sys.exit(0)

INTERVAL_MS = 250
parent = os.getppid()
last = None
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()

def emit(name):
    global last
    if name == last:
        return
    last = name
    try:
        sys.stdout.write(name + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        loop.quit()

def done(source, result):
    try:
        name = source.call_finish(result).unpack()[0]
    except GLib.Error:
        name = ""
    emit(name)

def tick():
    if os.getppid() != parent:
        loop.quit()
        return False
    bus.call("org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1", "CurrentInputMethod",
             None, GLib.VariantType.new("(s)"), Gio.DBusCallFlags.NO_AUTO_START, 1000, None, done)
    return True

tick()
GLib.timeout_add(INTERVAL_MS, tick)
loop.run()
