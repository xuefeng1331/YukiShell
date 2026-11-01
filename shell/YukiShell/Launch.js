.pragma library

// Starts a desktop entry through Hyprland so the window opens tiled or floating, whatever "Open windows floating" says.
// An app that hands the launch to a copy already running (Discord, Spotify...) opens where its own rules put it.
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

function argv(entry, floating, terminal) {
    var parts = entry && entry.command ? entry.command : [];
    var cmd = Array.prototype.map.call(parts, q).join(" ");
    if (!cmd) return null;
    if (floating && /^chromium/.test(entry.id))  // Chromium windows always tile by rule; this helper floats one anyway
        return ["sh", "-c", 'exec "$HOME/.config/hypr/bin/float-chromium"'];
    if (entry.runInTerminal) cmd = (terminal || "kitty") + " -e " + cmd;
    if (entry.workingDirectory) cmd = "cd " + q(entry.workingDirectory) + " && exec " + cmd;
    var opts = floating ? '{ float = true, center = true, size = "1280 800" }' : "{ tile = true }";
    return ["hyprctl", "dispatch", "hl.dsp.exec_cmd([==[" + cmd + "]==], " + opts + ")"];
}
