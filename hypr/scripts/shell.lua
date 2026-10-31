-- YukiShell: this repo's own fork of MacShell (independent of MacShell's install.sh / updates).
-- autostart: yuki-start waits for the compositor and restarts the shell if it crashes.
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    -- the password prompt for apps that need admin rights (GParted, Dolphin's root actions, installers, `systemctl start` ...);
    -- without an agent those requests fail silently
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    -- Install/update Hypridle's before_sleep_cmd hook (lid close is covered when it suspends).
    hl.exec_cmd("sh ~/.config/quickshell/YukiLock/enable-sleep-lock.sh")
    -- a YukiLock waiting in the background (warmed up), so Super+L locks at once with the animated wallpaper playing
    hl.exec_cmd("env YUKILOCK_DAEMON=1 qs -c YukiLock")
    hl.exec_cmd("sh ~/.local/bin/yuki-start")
end)
-- The Settings window floats and centres itself when it opens, so it needs no window rule.

-- keybinds (the name after -c is the config folder name, case-sensitive)
local qs = "qs -c YukiShell ipc call "
local bind = require("scripts.keys").bind    -- rebindable from Settings -> Keyboard (see keys.lua)

bind("SUPER + Z",       hl.dsp.exec_cmd(qs .. "settings toggle"), "System Settings")
bind("SUPER + V",       hl.dsp.exec_cmd(qs .. "spotlight clipboard"), "Clipboard History")
bind("SUPER + period",  hl.dsp.exec_cmd(qs .. "spotlight emoji"), "Emoji Picker")
bind("SUPER + Space",   hl.dsp.exec_cmd(qs .. "spotlight toggle"), "Spotlight")
bind("ALT + TAB",       hl.dsp.exec_cmd(qs .. "switcher next"), "Switch Windows", { fixed = true })   -- fixed: the switcher commits when Alt is let go
bind("CTRL + ALT + W",  hl.dsp.exec_cmd(qs .. "wallpapers toggle"), "Wallpapers")
bind("PRINT",           hl.dsp.exec_cmd(qs .. "screenshot region"), "Screenshot a Region")
bind("SHIFT + PRINT",   hl.dsp.exec_cmd(qs .. "screenshot screen"), "Screenshot the Screen")
bind("CTRL + PRINT",    hl.dsp.exec_cmd(qs .. "screenshot window"), "Screenshot a Window")
bind("SUPER + G",       hl.dsp.exec_cmd(qs .. "gaming toggle"), "Game Mode")          -- Game Mode: the shell stops its effects while you play
bind("SUPER + comma",   hl.dsp.exec_cmd(qs .. "notifications open"), "Notifications")
bind("SUPER + A",       hl.dsp.exec_cmd(qs .. "controlcenter toggle"), "Control Center")
bind("SUPER + ALT + R", hl.dsp.exec_cmd(qs .. "actions recording"), "Start or Stop Screen Recording")
bind("SUPER + ALT + C", hl.dsp.exec_cmd(qs .. "actions pickColor"), "Pick Color")

-- Hardware keys (laptop buttons too): volume, mute, brightness, media. YukiShell handles them itself and shows its
-- on-screen display. If the shell is not running, wpctl / brightnessctl do the work instead.
-- "locked" keeps the keys working on the lock screen. Any earlier bind on the same key is dropped first, so a key never fires twice.
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

-- YukiLock (lock screen)
bind("SUPER + L",       hl.dsp.exec_cmd("sh ~/.config/quickshell/YukiLock/lock-via-ipc.sh"), "Lock Screen")

-- the list of shortcuts that System Settings -> Keyboard edits (every bind() above and in binds.lua has been recorded by now)
require("scripts.keys").flush()
