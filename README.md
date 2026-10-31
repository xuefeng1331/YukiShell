<p align="center"><img src="shell/YukiShell/assets/yukishell-logo.png" width="128" alt="YukiShell"></p>

<h1 align="center">YukiShell</h1>

<p align="center">
  A Catppuccin Mocha rice for Hyprland, with its own desktop shell built on Quickshell.<br>
  Forked and maintained by <a href="https://github.com/xuefeng1331">雪風 (@xuefeng1331)</a>
</p>

<p align="center">
  <a href="https://github.com/xuefeng1331/YukiShell/wiki"><b>📖 Wiki</b></a> ·
  <a href="https://github.com/xuefeng1331/YukiShell/releases">Releases</a> ·
  <a href="https://github.com/xuefeng1331/YukiShell/issues">Issues</a>
</p>

---

This is the setup I use every day. It started as a fork of [MacShell](https://github.com/0-ss/MacShell) by
[Rickky](https://github.com/0-ss) and [vSuol](https://github.com/vsoultann), and over time it turned into its own thing: a different
name, its own config folders, its own installer and Settings app. It doesn't talk to MacShell at all anymore, so you can't break one
by updating the other.

What you get:

- **YukiShell**: the menu bar, Dock, Spotlight, Control Center, desktop widgets, notifications and a Settings app, all in Liquid Glass
- **YukiLock**: the lock screen
- Matching configs for Hyprland (Lua), kitty, fish, fastfetch, btop, cava, GTK 3/4 and Qt/KDE apps

Mauve and pink accents, a lot of glass, and an animated wallpaper if you want one.

The current version is **v1.5**: windows open floating, focus follows the pointer onto the desktop and after closing a window, the
lock screen locks at once with its video playing, a smarter music widget (mpv support, no lyrics), a calendar that grows out of the
clock, Qt theming without KDE Plasma, and a `yukishell stats` command. See
[what's new](https://github.com/xuefeng1331/YukiShell/releases/tag/v1.5).

## Contents

This README covers the essentials. The **[YukiShell Wiki](https://github.com/xuefeng1331/YukiShell/wiki)** goes further, with a page
for every part of the desktop, every Settings pane, every command, and troubleshooting.

- [Requirements](#requirements)
- [Installing](#installing)
- [Before you log in](#before-you-log-in)
- [Keybinds](#keybinds)
- [What's in it](#whats-in-it)
- [Configuring it](#configuring-it)
- [Things that conflict with it](#things-that-conflict-with-it)
- [Files](#files)
- [Q&A](#qa)
- [Working on it](#working-on-it)
- [Credits and license](#credits-and-license)

## Requirements

I built and test this on **CachyOS** with **Hyprland 0.56.2**, **Quickshell 0.3.2** (Qt 6) and an **NVIDIA** card. Other Arch-based
distros should be fine. Package names below are the Arch ones.

**You need these, nothing works without them:**

| Package | Why |
| --- | --- |
| `hyprland` | 0.56 or newer, using the **Lua config** (`~/.config/hypr/hyprland.lua`). The old `hyprland.conf` format is not supported. |
| `quickshell` | runs YukiShell and YukiLock |
| `kitty`, `fish` | the terminal and the shell the configs are written for |

**Strongly recommended** (the rice looks wrong without them):
`adw-gtk-theme papirus-icon-theme qt6ct breeze ttf-jetbrains-mono-nerd` and the **Bibata-Modern-Classic** cursor.

**Optional.** Each one turns on a feature, and if it's missing that feature just switches itself off:

| Package | What it's for |
| --- | --- |
| `grim`, `slurp` | screenshots, auto-contrast, windows showing through the glass |
| `imagemagick` | auto-contrast, cropping your profile picture |
| `awww`, `mpvpaper`, `ffmpeg`, `jq` | still and animated wallpapers |
| `wl-clipboard`, `cliphist` | copying, clipboard history (`Super+V`) |
| `playerctl`, `cava` | Now Playing widget, media keys, the audio visualizer |
| `mpv-mpris` | mpv in the Now Playing widget and on the media keys (mpv has no MPRIS support of its own) |
| `networkmanager`, `bluez-utils` | Wi-Fi and Bluetooth menus |
| `wireplumber`, `pipewire` | volume, UI sounds |
| `brightnessctl`, `ddcutil` | brightness for laptops / for external monitors over DDC/CI |
| `hyprsunset` | Night Shift |
| `power-profiles-daemon` | power mode |
| `inotify-tools` | wallpaper folders refresh by themselves |
| `wtype` | typing emoji from Spotlight |
| `fcitx5`, `fcitx5-bamboo`, `fcitx5-chinese-addons` | Vietnamese and Chinese typing |
| `dolphin`, `chromium` | the default file manager and browser (`Super+E`, `Super+W`) |
| `python-numpy` | only used once, to generate the UI sound effects |

Don't feel like reading the table? Run `tools/doctor`. It checks your machine and tells you exactly what's missing and what that turns off.

## Installing

```sh
git clone https://github.com/xuefeng1331/YukiShell.git ~/hypr-yukishell
cd ~/hypr-yukishell && ./install.sh
```

What `install.sh` does:

1. **Symlinks** the configs into `~/.config` (and the `yuki-*` commands into `~/.local/bin`). If you already have a file there, it gets moved to
   `<name>.pre-rice` once, so nothing of yours is deleted.
2. Adds **one `require` line** to `~/.config/hypr/hyprland.lua` (a backup goes to `hyprland.lua.pre-rice`).
3. Sets the GTK, Qt and btop themes and generates the UI sounds.
4. Builds the small **YukiVideo** plugin (`tools/build-plugins`), so the animated wallpaper inside all the glass runs on one video
   decoder instead of one per window. It needs `cmake` and the Qt 6 development files; without it the shell still works.
5. Runs `tools/doctor` at the end.

It's safe to run again whenever you pull new changes. Only want to see what's missing without touching anything? `./install.sh --doctor`.

To undo it, delete the symlinks and rename the `*.pre-rice` files back.

### Updating

```sh
cd ~/hypr-yukishell && git pull && hyprctl reload && yuki-restart
```

`hyprctl reload` picks up new shortcuts and the cursor settings, `yuki-restart` the shell. If a release adds new files to link,
run `./install.sh` again too (the release notes say so). After a Qt update, run `tools/build-plugins` again.

## Before you log in

Two things are personal to my machine and you'll probably want to change them:

- **`hypr/scripts/monitor.lua`**: my monitor is pinned to `HDMI-A-1` at 1920x1080@100. Put your own output name in (run `hyprctl monitors`).
- **`fastfetch/config.jsonc`**: `logo.source` points at a picture that isn't in this repo. Change it or delete the line.

Then log out and back into Hyprland. The shell starts by itself (`yuki-start` keeps it running and restarts it if it crashes).

## Keybinds

`Super` is the main key. Every shortcut can be changed in **System Settings → Keyboard → Keyboard Shortcuts**, and the menus in the
menu bar show each item's shortcut next to it.

**Apps and windows**

| Keys | What it does |
| --- | --- |
| `Super+Enter` | terminal |
| `Super+Shift+Enter` | floating terminal |
| `Super+W` / `Super+E` | Chromium / Dolphin (Dolphin opens tiled: full screen on an empty workspace, beside your other windows otherwise) |
| `Super+Shift+W` / `Super+Shift+E` | floating Chromium / Dolphin, centred |
| `Super+Q` | close window |
| `Super+F` | fullscreen (press again to go back) |
| `Super+Shift+F` | maximize, keeping the bar and gaps |
| `Super+Alt+Space` | toggle floating (new windows open floating, centred; Settings → Windows → Open windows floating) |
| `Super+C` | centre a floating window |
| `Super+Shift+P` | pin a floating window to every workspace |
| `Super+M` / `Super+Shift+M` | minimize / show minimized windows |
| `Super+Alt+S` | hide the focused window (again: the next one); with nothing focused, bring them all back |
| `Super+Shift+Tab` | terminal see-through: solid → glass → clear (terminals only) |
| `Super+Alt+D` | dashboard (fastfetch, clock, cava) |

**Moving around**

| Keys | What it does |
| --- | --- |
| `Super+1…0` | go to workspace 1–10 |
| `Super+Shift+1…0` | move the window there and follow it |
| `Super+Alt+1…0` | send the window there and stay where you are |
| `Super+Shift+PgDn` / `PgUp` | move the window to the next / previous workspace |
| `Super+Shift+O` | move the window to the next monitor |
| `Super+Scroll` | next / previous workspace |
| `Super+Arrows` (or `H` `K` `N`) | move focus |
| `Super+Shift+Arrows` | swap with the neighbouring window |
| `Super+Ctrl+Arrows` | resize from the keyboard (hold it) |
| `Super+Left / Right mouse` | drag / resize a window |

**Shell**

| Keys | What it does |
| --- | --- |
| `Super+Space` | Spotlight |
| `Super+V` / `Super+.` | clipboard history / emoji |
| `Super+A` | Control Center |
| `Super+,` | notifications |
| `Super+Z` | System Settings |
| `Alt+Tab` | window switcher |
| `Ctrl+Alt+W` | wallpaper picker |
| `Print` / `Shift+Print` / `Ctrl+Print` | screenshot a region / the screen / a window |
| `Super+Alt+R` | start / stop screen recording |
| `Super+Alt+C` | colour picker |
| `Super+G` | Game Mode (the shell drops its effects while you play) |
| `Super+L` | lock |
| `Super+Shift+R` | restart the shell |
| `Super+Shift+C` | reload the Hyprland config |

There's no key to quit Hyprland, reboot, shut down or force-quit an app. I've hit those by accident before. They're in the menus and need a second click.

## What's in it

**Liquid Glass everywhere.** The menus, Dock, widgets and Settings are glass that bends and blurs whatever is behind them. If your
wallpaper is a video, it plays *inside* the glass too, in sync with the desktop. Windows behind the Dock show through at 60 fps, and
see-through terminals stay see-through in the glass instead of turning into a dark block.

**Animated wallpapers.** Any video works (mpvpaper, hardware decoding). It plays at the clip's own frame rate, up to 60 fps, and is
smoothed up to your monitor's refresh rate so it doesn't stutter on a 100 or 144 Hz screen. The picture-frame button in the menu bar
pauses it. Game Mode stops it on its own, and *Settings → Wallpaper → Pause behind windows* saves power on a laptop.

**A Dock that gets out of the way.** In *Settings → Desktop & Dock* you pick how it hides:

- **Smart**: hides while a tiled window needs the space
- **Windows**: hides whenever there's any window on the workspace, floating ones too
- **Always**: hidden until you touch the bottom edge
- **Never**: always there, and windows leave room for it

You can pin your own apps, or make a custom one with your own name, command and icon.

**Widgets in any size you like.** Weather, Calendar, Clock, Now Playing and pictures sit on the desktop. In edit mode
(*Settings → Widgets → Edit on Desktop*) drag them around, and drag a corner to resize them in grid cells, from 1×1 up to 4×4. Every
shape gets its own design, not just a bigger copy: a tall card, a 4×1 strip and a wide 4×2 card each show the information their own way.
For example, the clock becomes flip tiles, a sweeping seconds bar or an analog face, and the weather an hourly list, the week with
range bars or a big "now" panel.

**A music widget that looks the part.** The album art lights the card in its own colours, the cover crossfades between songs, and the
title slides over when the track changes. With *Living artwork* the cover settles back when you pause and springs forward when the music
starts. The audio visualizer (needs `cava`) has up to 128 columns. It glows along the bottom of the card or sits behind the
controls, and it stays frozen while a song is paused. All of it is in *Settings → Widgets*.

**Your accent colour, everywhere.** Turn on *Settings → Appearance → Tint the interface* and the panels, Control Center, Settings and
widgets take your accent colour with white text. The icons, sliders and the widgets' Liquid Glass follow it too. One *Blur* slider sets
how frosted all the glass is.

**Your own cursor.** *Settings → Cursor* shows a preview of every installed cursor theme. You can add one you downloaded, change the size,
and choose whether it hides while you type or when idle. There are also focus-follows-mouse, jump-to-window and magnifier switches. GTK,
Qt/KDE and X apps follow along.

**A Control Center you can rearrange.** Hit *Edit Controls*, drag things wherever you like on the grid and drag the corner to resize them.
Besides the usual switches there are Lock Screen, Screenshot, Color Picker, Wallpapers, System Settings, a Microphone slider and Power Mode.

**Small things I care about:**

- Links you click in the shell (About, Help, Spotlight) take you to the browser window they opened in, even when it's on another workspace.
- Any accent colour you want: presets, a palette, or type a hex / RGB code.
- Workspace numbers your way: Han (一 二 三), Japanese (イチ ニ サン), Korean (일 이 삼), Roman (I II III), plain 1 2 3, or matching the interface language (*Settings → Menu Bar*).
- Mouse settings including **acceleration on/off**.
- Hardware you don't have isn't offered. No Wi-Fi card means no Wi-Fi tile.
- Wallpapers from as many folders as you like, and new files show up by themselves.
- Its own picture chooser with big thumbnails, so you don't need zenity or kdialog.
- `Super+Alt+S` hides the focused window; press it again to hide the next one too. With no window focused (everything hidden, an empty workspace, or the pointer resting on the empty desktop), it brings all hidden windows back exactly how they were: their workspace, floating or tiled, size and position, full screen.

**Seven languages.** *Settings → General → Language* switches everything live: English, 简体中文, 繁體中文, 日本語, 한국어, Tiếng Việt and
Русский. Dates follow the language too, including on the lock screen.

**Typing in other languages.** fcitx5 starts with the session. `Ctrl+Space` turns Vietnamese (Telex, `chaof` → `chào`) or Pinyin on and off.

## Configuring it

Most things are in **System Settings** (`Super+Z`). Here are the bits that live in files instead.

### Your monitor

`hypr/scripts/monitor.lua`:

```lua
hl.monitor({
    output   = "DP-1",            -- from `hyprctl monitors`
    mode     = "2560x1440@144",
    position = "0x0",
    scale    = 1,
})
```

### Environment variables

Copy `shell/env.example` to `~/.config/hypr-yukishell/env` and uncomment what you need. `yuki-start` reads it before starting the shell:

```sh
# icons for the Dock and Spotlight
export QS_ICON_THEME=Papirus-Dark

# old or weak GPU and the shell feels slow? try these one at a time
export QSG_RHI_BACKEND=opengl
#export QT_QUICK_BACKEND=software   # last resort, turns off Liquid Glass
```

Run `yuki-restart` afterwards.

### Your own keybinds

Settings is the easy way. If you'd rather write them, add them to `hypr/scripts/binds.lua` with the `bind` helper so they show up in Settings
too:

```lua
local bind = require("scripts.keys").bind

bind("SUPER + B", hl.dsp.exec_cmd("firefox"), "Open Firefox")
bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("firefox --private-window"), "Private Firefox")
```

Changes you make in Settings are saved in `~/.config/yukishell/keybinds.tsv`, one line per shortcut, with the name and the keys
separated by a tab. Leave the keys empty to turn a shortcut off:

```
Open Browser	SUPER + O
Dashboard	
```

### Terminal, launcher and file manager the shell uses

`~/.config/yukibar/settings.json`:

```json
{
  "terminal": "kitty",
  "launcher": "",
  "filesCmd": "xdg-open \"$HOME\""
}
```

Leave `launcher` empty to use Spotlight, or put in `fuzzel`, `rofi -show drun` and so on.

### How see-through the terminal is

`kitty/kitty.conf`:

```
background_opacity 0.55
dynamic_background_opacity yes
```

The glass setting of `Super+Shift+Tab` uses this number too.

### Widgets from a script

The desktop widgets answer to `qs -c YukiShell ipc call widgets …`:

```sh
qs -c YukiShell ipc call widgets edit true             # start / stop editing
qs -c YukiShell ipc call widgets span 0 4 2            # make widget 0 (the first one placed) cover 4 x 2 cells
qs -c YukiShell ipc call widgets move 0 40 60          # move it to the free spot nearest x 40, y 60
qs -c YukiShell ipc call widgets add clock liquid small
qs -c YukiShell ipc call widgets remove 2
```

### Colours

The whole palette is in `hypr/scripts/theme.lua`. The accent colour of the shell itself is in *Settings → Appearance*.

## Things that conflict with it

YukiShell does the jobs that a lot of separate tools usually do, so don't run those alongside it:

| Don't run alongside it | Why |
| --- | --- |
| **waybar**, eww, ags, another Quickshell config | YukiShell is already the bar, and two of them fight over the space and the tray |
| **mako**, dunst, swaync, fnott | YukiShell is the notification server. Only one program can be, so whichever starts first wins. |
| **MacShell** | same idea as YukiShell, with its own bar, Dock and notifications. Pick one. |
| hyprpaper, swww | wallpapers go through `awww` and `mpvpaper` |
| hyprlock | use YukiLock (`Super+L`). hypridle can stay: the rice points its sleep hook at YukiLock when Hyprland starts. |
| an old `hyprland.conf` | the rice is written for the Lua config only |

If something's autostarting one of these (an old `exec-once`, a systemd user service), turn it off.

## Files

```
hypr-yukishell/
├── install.sh                 symlinks everything into place
├── hypr/
│   ├── scripts/               Hyprland, in Lua
│   │   ├── theme.lua          palette
│   │   ├── monitor.lua        your screen (change this)
│   │   ├── look.lua           gaps, borders, blur, animations
│   │   ├── input.lua          keyboard, mouse, touchpad
│   │   ├── ime.lua            fcitx5
│   │   ├── keys.lua           the bind() helper behind Settings → Keyboard Shortcuts
│   │   ├── binds.lua          window and workspace keys
│   │   ├── rules.lua          window rules
│   │   └── shell.lua          starts YukiShell, its keys, the lock key
│   └── bin/                   dashboard, toggle-opacity, float-chromium, hide-window
├── shell/
│   ├── YukiShell/             the shell (Quickshell / QML)
│   │   ├── shell.qml          entry point
│   │   ├── YukiBar.qml        menu bar, menus, Spotlight, Control Center
│   │   ├── YukiDock.qml       Dock and the Settings app
│   │   ├── YukiWidgets.qml    desktop widgets
│   │   ├── lang/              translations
│   │   └── assets/            logo, credit pictures, small helpers
│   ├── YukiLock/              the lock screen
│   ├── bin/                   yuki-start, yuki-restart, yuki-brightness, yukishell (yukishell stats)
│   ├── scripts/               wallpaper, Game Mode and sound helpers
│   └── env.example
├── kitty/  fish/  fastfetch/  btop/  cava/
├── gtk-3.0/  gtk-4.0/  qt/  chromium/
└── tools/                     doctor, check, i18n-check.py, make-logo.py
```

Where things end up on your system:

| Path | What |
| --- | --- |
| `~/.config/quickshell/YukiShell`, `YukiLock` | symlinks to `shell/` |
| `~/.config/yukibar`, `yukidock`, `yukishell`, `yukilock`, `yukiwidgets` | your settings |
| `~/.config/hypr-yukishell/env` | your environment variables |
| `~/.config/yukishell/cursor` | the cursor theme and size from *Settings → Cursor*, read by `hypr/scripts/look.lua` at login |
| `~/.local/share/icons` | cursor themes you added in *Settings → Cursor* |
| `~/.local/state/hypr-yukishell/YukiShell.log` | the shell's log |

## Q&A

**The bar and Dock didn't show up after logging in.**
Run `yuki-start` in a terminal and read `~/.local/state/hypr-yukishell/YukiShell.log`. Usually it's a missing `quickshell`, or Hyprland
isn't using the Lua config. `tools/doctor` checks both.

**I got a "keeps crashing" notification.**
`yuki-start` gives up after a few crashes in a row so it doesn't loop forever. Check the log, fix what it complains about, then `yuki-restart`.

**How do I restart the shell?**
`Super+Shift+R`, or `yuki-restart` in a terminal. Please don't use `qs kill`. Quickshell can crash on the way out, and then you end up with two shells.

**Dolphin's terminal.** *Open Terminal* (`Shift+F4`, or right-click a folder) opens kitty in that folder. The terminal panel inside
Dolphin (`F4`) can only be Konsole: Dolphin embeds Konsole's terminal component there, and no other terminal can be embedded. Install
`konsole` if you want that panel.

**How much does YukiShell use?**
`yukishell stats` lists every YukiShell process (the shell, the waiting lock screen, the wallpaper player) and the helpers it
started, with CPU, RAM, GPU load and video memory each, the shell's CPU split into rendering / QML / video decoding, the programs
it launches in the background, cache sizes and any helpers an earlier session left behind. `-i 5` samples for 5 seconds,
`-w` keeps refreshing, `--json` is for scripts.

**It's using a lot of CPU / it's slow on my GPU.**
Try Game Mode (`Super+G`) to see whether the effects are the cause. If it's an older GPU, see the environment variables above.
The animated wallpaper costs the most, so try a still wallpaper too.

**The wallpaper inside the glass is a little behind the desktop.**
It catches up within a couple of seconds after it starts, because it syncs to the desktop player's clock. If it stays behind, `yuki-restart`.

**My notifications from mako/dunst stopped working.**
That's on purpose: YukiShell is the notification server now. See [Things that conflict with it](#things-that-conflict-with-it).

**Terminals opened from the shell use the wrong shell.**
They use your login shell (`chsh -s /usr/bin/fish` to change it). `yuki-start` reads it from your account, so restart the shell after changing it.

**Can I use this without NVIDIA?**
Yes. Nothing depends on NVIDIA. AMD and Intel should be fine, and there are fallbacks in `env.example` for older chips.

**Does it work on multiple monitors?**
The bar, Dock and wallpaper run per monitor. I only have one screen though, so tell me if something's off.

**How do I add a language?**
Copy `shell/YukiShell/lang/vi.js`, translate the right-hand side, register it in `shell/YukiShell/I18n.js` and add a small block to
`shell/YukiLock/I18n.js`. `tools/i18n-check.py` lists anything you missed.

**Will updating MacShell break this?**
No. YukiShell doesn't read MacShell's folders and never runs its installer or updater.

## Working on it

QML changes reload as soon as you save. The language files are cached, so restart the shell after editing those.

The shaders (`*.frag`) ship ready-built as `*.frag.qsb`, so you don't need anything extra to get Liquid Glass. If you edit one, rebuild
it with `qsb` from `qt6-shadertools` and commit both files:

```sh
/usr/lib/qt6/bin/qsb --qt6 -o shell/YukiShell/liquidglass.frag.qsb shell/YukiShell/liquidglass.frag
```

Before committing, run:

```sh
tools/check
```

It syntax-checks the Lua, fish, shell, Python, JSON, JS and QML, and lists any interface text that a language is missing. It takes about ten seconds.

If you're wondering what the shell is spending CPU on: `top -p $(pgrep -f '^qs -c YukiShell')`.

Issues and pull requests are welcome.

## Credits and license

MIT, see [LICENSE](LICENSE).

- **[雪風 (@xuefeng1331)](https://github.com/xuefeng1331)**: YukiShell, YukiLock and the rice
- **[Rickky (@0-ss)](https://github.com/0-ss)**: original author of [MacShell](https://github.com/0-ss/MacShell), where the menu bar, Dock, Liquid Glass and widgets come from
- **[vSuol (@vsoultann)](https://github.com/vsoultann)**: MacShell contributor, the Settings app

Their copyright notice is kept in the license. The bundled Open Runde fonts, GitHub's gemoji data and the icons keep their own licenses.
