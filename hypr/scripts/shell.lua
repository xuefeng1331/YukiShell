hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("sh ~/.config/quickshell/YukiLock/enable-sleep-lock.sh")
    hl.exec_cmd("env YUKILOCK_DAEMON=1 qs -c YukiLock")
    hl.exec_cmd("sh ~/.local/bin/yuki-start")
end)

local qs = "qs -c YukiShell ipc call "
local bind = require("scripts.keys").bind

bind("SUPER + Z",       hl.dsp.exec_cmd(qs .. "settings toggle"), "System Settings")
bind("SUPER + V",       hl.dsp.exec_cmd(qs .. "spotlight clipboard"), "Clipboard History")
bind("SUPER + period",  hl.dsp.exec_cmd(qs .. "spotlight emoji"), "Emoji Picker")
bind("SUPER + Space",   hl.dsp.exec_cmd(qs .. "spotlight toggle"), "Spotlight")
bind("ALT + TAB",       hl.dsp.exec_cmd(qs .. "switcher next"), "Switch Windows", { fixed = true })
bind("CTRL + ALT + W",  hl.dsp.exec_cmd(qs .. "wallpapers toggle"), "Wallpapers")
bind("PRINT",           hl.dsp.exec_cmd(qs .. "screenshot region"), "Screenshot a Region")
bind("SHIFT + PRINT",   hl.dsp.exec_cmd(qs .. "screenshot screen"), "Screenshot the Screen")
bind("CTRL + PRINT",    hl.dsp.exec_cmd(qs .. "screenshot window"), "Screenshot a Window")
bind("SUPER + G",       hl.dsp.exec_cmd(qs .. "gaming toggle"), "Game Mode")
bind("SUPER + comma",   hl.dsp.exec_cmd(qs .. "notifications open"), "Notifications")
bind("SUPER + A",       hl.dsp.exec_cmd(qs .. "controlcenter toggle"), "Control Center")
bind("SUPER + ALT + R", hl.dsp.exec_cmd(qs .. "actions recording"), "Start or Stop Screen Recording")
bind("SUPER + ALT + C", hl.dsp.exec_cmd(qs .. "actions pickColor"), "Pick Color")

local function hw(action, fallback)
    return "sh -c '" .. qs .. "hardware " .. action .. " >/dev/null 2>&1 || " .. fallback .. "'"
end
local hwkeys = {
    { "XF86AudioRaiseVolume",  hw("volumeUp",       "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),   true  },
    { "XF86AudioLowerVolume",  hw("volumeDown",     "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        true  },
    { "XF86AudioMute",         hw("mute",           "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       false },
    { "XF86AudioMicMute",      hw("micMute",        "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     false },
    { "XF86MonBrightnessUp",   hw("brightnessUp",   "yuki-brightness step +5"),                         true  },
    { "XF86MonBrightnessDown", hw("brightnessDown", "yuki-brightness step -5"),                     true  },
    { "XF86KbdBrightnessUp",   "brightnessctl -q -d '*kbd_backlight*' set 10%+",                         true  },
    { "XF86KbdBrightnessDown", "brightnessctl -q -d '*kbd_backlight*' set 10%-",                         true  },
    { "XF86AudioPlay",         "playerctl play-pause",                                                   false },
    { "XF86AudioPause",        "playerctl pause",                                                        false },
    { "XF86AudioNext",         "playerctl next",                                                         false },
    { "XF86AudioPrev",         "playerctl previous",                                                     false },
}
for _, k in ipairs(hwkeys) do
    pcall(hl.unbind, k[1])
    hl.bind(k[1], hl.dsp.exec_cmd(k[2]), { locked = true, repeating = k[3] })
end

bind("SUPER + L",       hl.dsp.exec_cmd("sh ~/.config/quickshell/YukiLock/lock-via-ipc.sh"), "Lock Screen")

require("scripts.keys").flush()
