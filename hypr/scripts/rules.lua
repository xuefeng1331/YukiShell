hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- New windows open floating and centred instead of tiling (Settings -> Windows -> "Open windows floating", on by default).
-- YukiShell switches this rule on / off (FLOAT_NEW_RULE:set_enabled, see applyWindowRules in YukiBar.qml); Super+Alt+Space still
-- tiles or floats one window. The rules below can still give a window its own size.
FLOAT_NEW_RULE = hl.window_rule({ name = "float-new-windows", match = { class = ".*" }, float = true, center = true })

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Small utility windows float.
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-polkit",      match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })
hl.window_rule({ name = "float-utilities",   match = { class = "^(nm-connection-editor|blueman-manager|org\\.gnome\\.Calculator|org\\.kde\\.kcalc|qalculate-gtk|io\\.github\\.Qalculate\\.qalculate-gtk|org\\.kde\\.kdeconnect.*|org\\.gnome\\.Characters)$" }, float = true, center = true })
hl.window_rule({ name = "pip-float",         match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })

-- Video players float, centred, at two thirds of the screen. Without this a 4K video opened mpv at 3840x2160, off the edges, and
-- VLC grew to the video's own size once it started playing (install.sh turns VLC's "Resize interface to video size" off, so it
-- keeps this size; mpv keeps it by itself and letterboxes).
hl.window_rule({
    name  = "float-video-players",
    match = { class = "^(mpv|vlc|org\\.videolan\\.VLC)$" },
    float = true,
    center = true,
    size = "(monitor_w*0.66) (monitor_h*0.66)",
})

-- swayimg, the image viewer (swayimg/init.lua), the same way: a picture opens over your work, centred, instead of tiling into it.
hl.window_rule({
    name  = "float-image-viewer",
    match = { class = "^(swayimg)$" },
    float = true,
    center = true,
    size = "(monitor_w*0.66) (monitor_h*0.66)",
})

-- File pickers float, centred, instead of tiling next to your work. "Choose a picture", Chromium's Open/Save, Dolphin and the like all
-- go through the desktop portal (xdg-desktop-portal-gtk / -kde); zenity, kdialog and yad are covered too, and so are the GTK/Qt
-- dialogs that name themselves "Open File", "Save As" etc. (Chromium page titles end in " - Chromium", so they never match.)
hl.window_rule({
    name  = "float-file-pickers",
    match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|org\\.freedesktop\\.impl\\.portal\\.desktop\\.(gtk|kde)|zenity|org\\.gnome\\.Zenity|kdialog|yad)$" },
    float = true,
    center = true,
    size = "1000 680",
})
hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = "^(Open Files?|Open Folder|Save Files?|Save As|Select (a )?([Ff]iles?|[Ff]olders?)|File Upload|Choose Files?|Choose a [Ff]ile)$" },
    float = true,
    center = true,
    size = "1000 680",
})


-- YukiShell's own picture / folder chooser (shell/YukiShell/FilePicker.qml): floats, centred, big enough for the thumbnails.
hl.window_rule({
    name  = "yukishell-picker",
    match = { class = "^org\\.quickshell$", title = "^YukiShell Picker$" },
    float = true,
    center = true,
    size = "1120 740",
})

-- Liquid-glass kitty, like the Dock: clear glass (light blur, a light dark fill from kitty.conf). Its border is the same accent
-- border as every other window (YukiShell sets it from the accent colour, see applyBorders in YukiBar.qml).
hl.window_rule({
    name  = "glass-kitty",
    match = { class = "^(kitty|dash-.*)$" },
    opacity  = "1.0 override 1.0 override",
    xray     = false,
    rounding = 20,
})

-- Workspaces 1-10 always exist, so the YukiShell bar shows all ten and Super+scroll can reach any of them.
for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- YukiShell Settings: born floating, centred, at its own size (the shell used to float it only after it mapped as a tile).
hl.window_rule({
    name  = "yukishell-settings",
    match = { class = "^org\\.quickshell$", title = "^YukiShell Settings$" },
    float = true,
    center = true,
    size = "800 880",
    min_size = "720 480",    -- below this the panes no longer fit their widest controls (the sidebar alone is 232px)
})

-- Super+Shift+W (hypr/bin/float-chromium): a floating Chromium window, born floating. The rule is off by default; the script
-- switches it on just before it starts the window and off again once the window exists, so other Chromium windows stay tiled.
FLOAT_CHROMIUM_RULE = hl.window_rule({
    name  = "float-chromium-once",
    enabled = false,
    match = { class = "^[Cc]hromium$" },
    float = true,
    center = true,
    size = "1280 800",
})
