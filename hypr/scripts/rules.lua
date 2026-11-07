hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

FLOAT_NEW_RULE = hl.window_rule({ name = "float-new-windows", match = { class = ".*" }, float = true, center = true, size = "900 560" })

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-polkit",      match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })
hl.window_rule({ name = "float-utilities",   match = { class = "^(nm-connection-editor|blueman-manager|org\\.gnome\\.Calculator|org\\.kde\\.kcalc|qalculate-gtk|io\\.github\\.Qalculate\\.qalculate-gtk|org\\.kde\\.kdeconnect.*|org\\.gnome\\.Characters)$" }, float = true, center = true })
hl.window_rule({ name = "pip-float",         match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })

hl.window_rule({
    name  = "float-video-players",
    match = { class = "^(mpv|vlc|org\\.videolan\\.VLC)$" },
    float = true,
    center = true,
    size = "900 560",
})

hl.window_rule({
    name  = "float-image-viewer",
    match = { class = "^(swayimg)$" },
    float = true,
    center = true,
    size = "900 560",
})

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

hl.window_rule({
    name  = "yukishell-picker",
    match = { class = "^org\\.quickshell$", title = "^YukiShell Picker$" },
    float = true,
    center = true,
    size = "1120 740",
})

hl.window_rule({
    name  = "glass-kitty",
    match = { class = "^(kitty|dash-.*)$" },
    opacity  = "1.0 override 1.0 override",
    xray     = false,
    rounding = 20,
})

for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

hl.window_rule({
    name  = "yukishell-settings",
    match = { class = "^org\\.quickshell$", title = "^YukiShell Settings$" },
    float = true,
    center = true,
    size = "800 880",
    min_size = "640 480",
})

-- Chromium windows tile even with "Open windows floating" on (Super+W, tabs dragged out); the one-shot rule below wins for links
hl.window_rule({
    name  = "tile-chromium",
    match = { class = "^[Cc]hromium$" },
    tile = true,
})

hl.layer_rule({ name = "yukishell-clock-alert", match = { namespace = "^yukishell-clock-alert$" }, blur = true, ignore_alpha = 0.45 })

-- games keep out of the 900x560 floating size: they tile and can still go fullscreen
hl.window_rule({
    name  = "tile-games",
    match = { class = "^(steam_app_[0-9]+|gamescope)$" },
    tile = true,
})

FLOAT_CHROMIUM_RULE = hl.window_rule({
    name  = "float-chromium-once",
    enabled = false,
    match = { class = "^[Cc]hromium$" },
    float = true,
    center = true,
    size = "900 560",
})
