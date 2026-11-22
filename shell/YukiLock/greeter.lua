-- The login screen's own Hyprland: greetd runs `Hyprland --config <this file>` as its "greeter" user (install.sh sets it up).
-- It shows greeter.qml and exits when you have signed in, so greetd can start your session.
local qml = os.getenv("YUKIGREET_QML") or "/usr/local/share/yukishell/YukiLock/greeter.qml"
hl.config({
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
    animations = { enabled = false },
})
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'qs -p \"" .. qml .. "\"; hyprctl dispatch \"hl.dsp.exit()\"'")
end)
