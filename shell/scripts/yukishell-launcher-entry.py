#!/usr/bin/env python3
# The Dock's badges: apps send com.canonical.Unity.LauncherEntry.Update for an unread count, a progress bar or a request for
# attention. Prints one JSON line per update: {"app", "sender", "count"?, "count-visible"?, "progress"?, "progress-visible"?, "urgent"?},
# and {"gone": sender} when an app that sent one leaves the bus, so its badge goes away with it.
import json
import os
import sys

from gi.repository import Gio, GLib

KEYS = ("count", "count-visible", "progress", "progress-visible", "urgent")
senders = set()


def emit(obj):
    print(json.dumps(obj), flush=True)


def parse(app_uri, props):
    app = app_uri[len("application://"):] if app_uri.startswith("application://") else app_uri
    if app.endswith(".desktop"):
        app = app[: -len(".desktop")]
    return {"app": app, **{k: props[k] for k in KEYS if k in props}}


def on_update(_conn, sender, _path, _iface, _signal, params):
    app_uri, props = params.unpack()
    senders.add(sender)
    emit({**parse(app_uri, props), "sender": sender})


def on_owner(_conn, _sender, _path, _iface, _signal, params):
    name, _old, new = params.unpack()
    if not new and name in senders:
        senders.discard(name)
        emit({"gone": name})


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        assert parse("application://org.telegram.desktop.desktop", {"count": 3, "count-visible": True, "x": 1}) == \
            {"app": "org.telegram.desktop", "count": 3, "count-visible": True}
        assert parse("firefox", {"progress": 0.5}) == {"app": "firefox", "progress": 0.5}
        print("launcher entry ok")
        sys.exit(0)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    bus.signal_subscribe(None, "com.canonical.Unity.LauncherEntry", "Update", None, None, Gio.DBusSignalFlags.NONE, on_update)
    bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged", "/org/freedesktop/DBus", None,
                         Gio.DBusSignalFlags.NONE, on_owner)
    loop, parent = GLib.MainLoop(), os.getppid()
    GLib.timeout_add_seconds(5, lambda: os.getppid() == parent or loop.quit())   # the shell was killed: don't linger
    loop.run()
