hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("sh ~/.config/quickshell/YukiLock/enable-sleep-lock.sh")
    hl.exec_cmd("env YUKILOCK_DAEMON=1 qs -c YukiLock")
    hl.exec_cmd("sh ~/.local/bin/yuki-start")
end)

local qs = "qs -c YukiShell ipc call "
local keys = require("scripts.keys")
local bind, section = keys.bind, keys.section

section("YukiShell")
bind("SUPER + Z",       hl.dsp.exec_cmd(qs .. "settings toggle"), "System Settings")
bind("SUPER + V",       hl.dsp.exec_cmd(qs .. "spotlight clipboard"), "Clipboard History")
bind("SUPER + period",  hl.dsp.exec_cmd(qs .. "spotlight emoji"), "Emoji Picker")
bind("SUPER + Space",   hl.dsp.exec_cmd(qs .. "spotlight toggle"), "Spotlight")
bind("ALT + TAB",       hl.dsp.exec_cmd(qs .. "switcher next"), "Switch Windows", { fixed = true })
bind("CTRL + ALT + W",  hl.dsp.exec_cmd(qs .. "wallpapers toggle"), "Wallpapers")
bind("SUPER + G",       hl.dsp.exec_cmd(qs .. "gaming toggle"), "Game Mode")
bind("SUPER + comma",   hl.dsp.exec_cmd(qs .. "notifications open"), "Notifications")
bind("SUPER + A",       hl.dsp.exec_cmd(qs .. "controlcenter toggle"), "Control Center")

bind("SUPER + slash",   hl.dsp.exec_cmd(qs .. "settings pane keyboard"), "Keyboard Shortcuts")

section("Screenshots and Recording")
bind("PRINT",           hl.dsp.exec_cmd(qs .. "screenshot region"), "Screenshot a Region")
bind("SHIFT + PRINT",   hl.dsp.exec_cmd(qs .. "screenshot screen"), "Screenshot the Screen")
if not keys.overridden("Screenshot a Region") then bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(qs .. "screenshot region"), "Screenshot a Region", { fixed = true }) end   -- keyboards without Print
bind("CTRL + PRINT",    hl.dsp.exec_cmd(qs .. "screenshot window"), "Screenshot a Window")
bind("SUPER + ALT + R", hl.dsp.exec_cmd(qs .. "actions recording"), "Start or Stop Screen Recording")
bind("SUPER + ALT + C", hl.dsp.exec_cmd(qs .. "actions pickColor"), "Pick Color")

local function hw(action, fallback)
    return "sh -c '" .. qs .. "hardware " .. action .. " >/dev/null 2>&1 || " .. fallback .. "'"
end
section("Media and Hardware")
local hwkeys = {
    { "XF86AudioRaiseVolume",  hw("volumeUp",       "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),   true,  desc = "Change Volume" },
    { "XF86AudioLowerVolume",  hw("volumeDown",     "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        true,  desc = "Change Volume" },
    { "XF86AudioMute",         hw("mute",           "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       false, desc = "Mute Sound" },
    { "XF86AudioMicMute",      hw("micMute",        "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     false, desc = "Mute Microphone" },
    { "XF86MonBrightnessUp",   hw("brightnessUp",   "yuki-brightness step +5"),                         true,  desc = "Screen Brightness" },
    { "XF86MonBrightnessDown", hw("brightnessDown", "yuki-brightness step -5"),                     true,  desc = "Screen Brightness" },
    { "XF86KbdBrightnessUp",   "brightnessctl -q -d '*kbd_backlight*' set 10%+",                         true,  desc = "Keyboard Brightness" },
    { "XF86KbdBrightnessDown", "brightnessctl -q -d '*kbd_backlight*' set 10%-",                         true,  desc = "Keyboard Brightness" },
    { "XF86AudioPlay",         "playerctl play-pause",                                                   false, desc = "Play or Pause" },
    { "XF86AudioPause",        "playerctl pause",                                                        false, desc = "Play or Pause" },
    { "XF86AudioNext",         "playerctl next",                                                         false, desc = "Next or Previous Track" },
    { "XF86AudioPrev",         "playerctl previous",                                                     false, desc = "Next or Previous Track" },
}
for _, k in ipairs(hwkeys) do
    pcall(hl.unbind, k[1])
    bind(k[1], hl.dsp.exec_cmd(k[2]), k.desc, { locked = true, repeating = k[3], fixed = true })
end

section("System")

-- locked: works while the session is locked too, so a crashed lock screen can be brought back (allow_session_lock_restore)
bind("SUPER + L",       hl.dsp.exec_cmd("sh ~/.config/quickshell/YukiLock/lock-via-ipc.sh"), "Lock Screen", { locked = true })

keys.flush()
