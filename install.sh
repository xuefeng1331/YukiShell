#!/usr/bin/env bash
# Standalone installer for this rice. Independent of MacShell's repo/install.sh.
# Symlinks files into ~/.config (existing files are moved to *.pre-rice once), then wires Hyprland and Qt.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

# ./install.sh --doctor: only check what is missing on this machine, change nothing
[ "${1:-}" = "--doctor" ] && exec "$here/tools/doctor"

link() {  # link <src> <dst>
    mkdir -p "$(dirname "$2")"
    if [ -e "$2" ] && [ ! -L "$2" ]; then mv "$2" "$2.pre-rice"; fi
    ln -sfn "$1" "$2"
}

link "$here/hypr/scripts"                       "$cfg/hypr/scripts"
link "$here/hypr/bin"                           "$cfg/hypr/bin"
link "$here/kitty/kitty.conf"                   "$cfg/kitty/kitty.conf"
link "$here/fastfetch/config.jsonc"             "$cfg/fastfetch/config.jsonc"
link "$here/btop/themes/mocha-glass.theme"      "$cfg/btop/themes/mocha-glass.theme"
link "$here/cava/config"                        "$cfg/cava/config"
link "$here/cava/dashboard.conf"               "$cfg/cava/dashboard.conf"
link "$here/fish/config.fish"                   "$cfg/fish/config.fish"
for f in cll ll warp; do link "$here/fish/functions/$f.fish" "$cfg/fish/functions/$f.fish"; done
for v in 3 4; do
    link "$here/gtk-$v.0/gtk.css"      "$cfg/gtk-$v.0/gtk.css"
    link "$here/gtk-$v.0/settings.ini" "$cfg/gtk-$v.0/settings.ini"
done
link "$here/shell/YukiShell"                   "$cfg/quickshell/YukiShell"
link "$here/shell/YukiLock"                    "$cfg/quickshell/YukiLock"
link "$here/shell/bin/yuki-start"              "$HOME/.local/bin/yuki-start"
link "$here/shell/bin/yuki-restart"            "$HOME/.local/bin/yuki-restart"
link "$here/shell/bin/yuki-brightness"         "$HOME/.local/bin/yuki-brightness"
link "$here/shell/bin/yukishell"               "$HOME/.local/bin/yukishell"
link "$here/shell/scripts"                     "$cfg/hypr-yukishell/scripts"   # wallpaper, Game Mode, wallpaper pause, dynamic wallpaper
[ -f "$cfg/hypr-yukishell/env" ] || { mkdir -p "$cfg/hypr-yukishell"; cp "$here/shell/env.example" "$cfg/hypr-yukishell/env"; }
link "$here/qt/CatppuccinMauve.colors" "$HOME/.local/share/color-schemes/CatppuccinMauve.colors"
link "$here/chromium/chromium-flags.conf" "$cfg/chromium-flags.conf"

# the YukiVideo plugin: one video decoder for the animated wallpaper in all the glass (optional; needs cmake + Qt 6 dev files)
"$here/tools/build-plugins" >/dev/null 2>&1 || echo "note: YukiVideo plugin not built (install cmake and the Qt 6 dev packages, then run tools/build-plugins)."

# UI sound effects are synthesized (needs python-numpy); skipped quietly if it is missing
if [ ! -d "$HOME/.local/share/sounds/yukishell" ]; then
    python3 "$here/shell/scripts/yukishell-make-sounds.py" >/dev/null 2>&1 || echo "note: UI sounds not generated (install python-numpy and re-run)."
fi

# Hyprland: one require block, placed above any MacShell block so install.sh updates there never touch the rice.
lua="$cfg/hypr/hyprland.lua"
# installs from before hypr/rice was renamed to hypr/scripts: point the block at the new folder, drop the old link
if [ -f "$lua" ] && grep -q '"rice\.' "$lua"; then
    cp "$lua" "$lua.pre-scripts"
    sed -i 's/"rice\." \.\. m/"scripts." .. m/; s/'"'"'rice\." \.\. m/'"'"'scripts." .. m/' "$lua"
fi
[ -L "$cfg/hypr/rice" ] && case "$(readlink "$cfg/hypr/rice")" in "$here"/*) rm -f "$cfg/hypr/rice" ;; esac
if [ -f "$lua" ] && ! grep -q '"scripts\.' "$lua"; then
    cp "$lua" "$lua.pre-rice"
    { cat <<'LUA'
-- Rice (managed by ~/hypr-yukishell)
for _, m in ipairs({ "monitor", "look", "input", "ime", "binds", "rules", "shell" }) do
    local ok, err = pcall(require, "scripts." .. m)
    if not ok then hl.exec_cmd("notify-send 'Hyprland rice' 'scripts." .. m .. " failed: " .. tostring(err):gsub("'", "") .. "'") end
end

LUA
      cat "$lua.pre-rice"; } > "$lua"
fi

# Drop MacShell's own block from hyprland.lua; YukiShell is wired in scripts/shell.lua instead.
if [ -f "$lua" ] && grep -q '>>> MacShell module' "$lua"; then
    cp "$lua" "$lua.pre-fork"
    python3 - "$lua" <<'PY'
import re, sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(re.sub(r"\n?-- >>> MacShell module.*?-- <<< MacShell module <<<\n?", "\n", t, flags=re.S))
PY
fi

# btop / Qt / GTK settings that live in other files
sed -i 's/^color_theme = .*/color_theme = "mocha-glass"/; s/^theme_background = .*/theme_background = false/' "$cfg/btop/btop.conf" 2>/dev/null || true
if command -v kwriteconfig6 >/dev/null; then
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme CatppuccinMauve
    # outside Plasma, KDE apps (Dolphin) choose their own scheme and fall back to light Breeze unless told which one
    kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme CatppuccinMauve
    kwriteconfig6 --file kdeglobals --group General --key AccentColor 203,166,247
    kwriteconfig6 --file kdeglobals --group Icons   --key Theme Papirus-Dark
    kwriteconfig6 --file kdeglobals --group KDE     --key widgetStyle Breeze
    # "Open Terminal" in Dolphin (Shift+F4, right-click a folder) and other KDE apps opens kitty. Dolphin's built-in terminal
    # panel (F4) is a different thing: it can only embed Konsole (konsolepart), no other terminal can live inside its window
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
    kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
    # KDE apps (Dolphin's file view) read colours from kdeglobals itself, so the scheme's groups have to be copied in
    python3 "$here/qt/apply-scheme.py" "$here/qt/CatppuccinMauve.colors" || true
fi
# VLC keeps the size the window rule gives it (hypr/scripts/rules.lua, float-video-players) instead of growing to the video's own
# size once it plays ("Resize interface to video size" off). Only that one key is touched; a missing vlcrc gets a one-line one.
if command -v vlc >/dev/null; then
    mkdir -p "$cfg/vlc"
    if [ -f "$cfg/vlc/vlcrc" ]; then
        if grep -q '^#\?qt-video-autoresize=' "$cfg/vlc/vlcrc"; then
            sed -i 's/^#\?qt-video-autoresize=.*/qt-video-autoresize=0/' "$cfg/vlc/vlcrc"
        else
            printf '\n[qt] # Qt interface\nqt-video-autoresize=0\n' >> "$cfg/vlc/vlcrc"
        fi
    else
        printf '[qt] # Qt interface\nqt-video-autoresize=0\n' > "$cfg/vlc/vlcrc"
    fi
fi
# Qt apps' theme without Plasma (QT_QPA_PLATFORMTHEME=qt6ct in hypr/scripts/look.lua): the same colours, Breeze style, Papirus icons
mkdir -p "$cfg/qt6ct/colors"
link "$here/qt/qt6ct/YukiShell.conf" "$cfg/qt6ct/colors/YukiShell.conf"
printf '[Appearance]\ncolor_scheme_path=%s\ncustom_palette=true\nicon_theme=Papirus-Dark\nstandard_dialogs=default\nstyle=Breeze\n\n[Fonts]\ngeneral="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\nfixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\n' \
    "$cfg/qt6ct/colors/YukiShell.conf" > "$cfg/qt6ct/qt6ct.conf"
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
fi
command -v hyprctl >/dev/null && hyprctl reload || true
echo "Rice installed. Needs: adw-gtk-theme, papirus-icon-theme, bibata cursor, JetBrainsMono Nerd Font, qt6ct, breeze."
echo
"$here/tools/doctor" || echo "Install the MISSING packages above, then re-run ./install.sh."
