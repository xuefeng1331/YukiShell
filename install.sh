#!/usr/bin/env bash
# YukiShell installer. Two steps, on any Arch-based system:
#   curl -LO https://github.com/xuefeng1331/YukiShell/raw/main/install.sh
#   bash install.sh
# It installs every package, links the configs and sets the themes. Safe to run again; it only asks for your password when it has something to install.
set -euo pipefail

[ "$(id -u)" != 0 ] || { echo "Run this as your normal user, not root (it asks for your password when it needs it)." >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ ! -d "$here/shell/YukiShell" ]; then
    # downloaded on its own: fetch the rest and carry on from there
    repo="$HOME/hypr-yukishell"
    command -v git >/dev/null || sudo pacman -S --needed --noconfirm git
    if [ -d "$repo/.git" ]; then git -C "$repo" pull --ff-only || true
    elif [ -e "$repo" ]; then echo "$repo exists and is not a YukiShell checkout. Move it away and run this again." >&2; exit 1
    else git clone https://github.com/xuefeng1331/YukiShell.git "$repo"
    fi
    exec bash "$repo/install.sh" "$@"
fi
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

[ "${1:-}" = "--doctor" ] && exec "$here/tools/doctor"

if [ "${1:-}" = "--uninstall" ]; then
    # only links that point into this checkout are removed; packages and your settings stay
    find "$cfg" "$HOME/.local/bin" "$HOME/.local/share/color-schemes" -maxdepth 4 -type l -lname "$here/*" -delete 2>/dev/null || true
    find "$cfg" -maxdepth 4 -name '*.pre-rice' 2>/dev/null | while read -r f; do
        if [ -s "$f" ] || [ -d "$f" ]; then mv -f "$f" "${f%.pre-rice}"; else rm -f "$f" "${f%.pre-rice}"; fi
    done
    echo "YukiShell's links are gone and your old files are back. Log out to leave the session."
    exit 0
fi

pkgs=(
    # the desktop
    hyprland quickshell kitty fish xdg-desktop-portal-hyprland polkit-kde-agent libnotify hypridle
    # the look
    adw-gtk-theme papirus-icon-theme qt6ct breeze bibata-cursor-theme ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
    # Qt modules, the video plugin and the helpers
    qt6-multimedia qt6-multimedia-ffmpeg cmake git curl python python-numpy python-gobject
    # one feature each: Settings and the menu bar switch off what is missing
    grim slurp wf-recorder hyprpicker imagemagick awww mpvpaper ffmpeg jq wl-clipboard cliphist
    playerctl cava mpv mpv-mpris swayimg networkmanager bluez bluez-utils wireplumber pipewire libpulse
    brightnessctl ddcutil hyprsunset power-profiles-daemon upower inotify-tools wtype
    fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-bamboo fcitx5-chinese-addons
    dolphin chromium fastfetch btop tty-clock
)
failed=()

aur_install() {
    local helper="" tmp
    if command -v paru >/dev/null; then helper=paru
    elif command -v yay >/dev/null; then helper=yay
    else
        echo "Building yay to install the packages that are only in the AUR…"
        sudo pacman -S --needed --noconfirm base-devel git || true
        tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
            && (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || true
        rm -rf "$tmp"
        command -v yay >/dev/null && helper=yay
    fi
    [ -n "$helper" ] || { failed+=("$@"); return; }
    local p name
    for p in "$@"; do
        name="$p"; [ "$p" = bibata-cursor-theme ] && name=bibata-cursor-theme-bin   # prebuilt, the source package takes minutes to render
        case "$helper" in
            paru) paru -S --needed --noconfirm --skipreview --sudoloop "$name" || failed+=("$p") ;;
            yay)  yay -S --needed --noconfirm --answerclean None --answerdiff None --removemake --sudoloop "$name" || failed+=("$p") ;;
        esac
    done
}

install_packages() {
    if ! command -v pacman >/dev/null; then
        echo "No pacman here, so the packages are up to you: tools/doctor lists what is missing."
        return
    fi
    local missing=() repo=() aur=() p
    mapfile -t missing < <(pacman -T "${pkgs[@]}" || true)
    if [ "${#missing[@]}" = 0 ]; then echo "All packages are installed."; return; fi

    echo "Installing ${#missing[@]} packages: ${missing[*]}"
    if ! sudo -v; then
        echo "No sudo access, skipping the packages. tools/doctor lists what is missing." >&2
        return
    fi
    # Arch only supports installing on an up-to-date system
    sudo pacman -Syu --noconfirm || echo "The system update failed, trying the packages anyway." >&2
    for p in "${missing[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done
    if [ "${#repo[@]}" -gt 0 ] && ! sudo pacman -S --needed --noconfirm "${repo[@]}"; then
        # one conflict (tlp and power-profiles-daemon, say) fails the whole batch
        for p in "${repo[@]}"; do sudo pacman -S --needed --noconfirm "$p" || failed+=("$p"); done
    fi
    if [ "${#aur[@]}" -gt 0 ]; then aur_install "${aur[@]}"; fi

    local svc
    for svc in bluez:bluetooth power-profiles-daemon:power-profiles-daemon; do
        if printf '%s\n' "${missing[@]}" | grep -qx "${svc%:*}"; then sudo systemctl enable --now "${svc#*:}" || true; fi
    done
    # NetworkManager only when nothing else runs the network, or this could cut off the connection
    if printf '%s\n' "${missing[@]}" | grep -qx networkmanager && ! systemctl is-active -q systemd-networkd dhcpcd iwd netctl 2>/dev/null; then
        sudo systemctl enable --now NetworkManager || true
    fi
    # external monitor brightness needs the i2c-dev module
    if command -v ddcutil >/dev/null && [ ! -e /etc/modules-load.d/i2c-dev.conf ] && printf '%s\n' "${missing[@]}" | grep -qx ddcutil; then
        echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null || true
        sudo modprobe i2c-dev || true
    fi
}

link() {
    mkdir -p "$(dirname "$2")"
    if [ -e "$2" ] && [ ! -L "$2" ]; then
        local keep="$2.pre-rice"
        [ ! -e "$keep" ] || keep="$keep.$(date +%s)"
        mv "$2" "$keep"
    fi
    ln -sfn "$1" "$2"
}

install_packages

first=0
[ -f "$cfg/hypr-yukishell/env" ] || first=1

link "$here/hypr/scripts"                       "$cfg/hypr/scripts"
link "$here/hypr/bin"                           "$cfg/hypr/bin"
link "$here/kitty/kitty.conf"                   "$cfg/kitty/kitty.conf"
link "$here/fastfetch/config.jsonc"             "$cfg/fastfetch/config.jsonc"
link "$here/btop/themes/mocha-glass.theme"      "$cfg/btop/themes/mocha-glass.theme"
link "$here/cava/config"                        "$cfg/cava/config"
link "$here/cava/dashboard.conf"               "$cfg/cava/dashboard.conf"
link "$here/fish/config.fish"                   "$cfg/fish/config.fish"
for f in "$here"/fish/functions/*.fish; do link "$f" "$cfg/fish/functions/${f##*/}"; done
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
link "$here/shell/bin/fff"                     "$HOME/.local/bin/fff"
link "$here/shell/scripts"                     "$cfg/hypr-yukishell/scripts"
[ -f "$cfg/hypr-yukishell/env" ] || { mkdir -p "$cfg/hypr-yukishell"; cp "$here/shell/env.example" "$cfg/hypr-yukishell/env"; }
link "$here/qt/CatppuccinMauve.colors" "$HOME/.local/share/color-schemes/CatppuccinMauve.colors"
link "$here/chromium/chromium-flags.conf" "$cfg/chromium-flags.conf"
link "$here/xdg/menus/applications.menu" "$cfg/menus/applications.menu"
link "$here/swayimg/init.lua"              "$cfg/swayimg/init.lua"

[ -e "$cfg/fastfetch/logo.png" ] || cp "$here/shell/YukiShell/assets/yukishell-logo.png" "$cfg/fastfetch/logo.png"

"$here/tools/build-plugins" >/dev/null 2>&1 || echo "note: YukiVideo plugin not built (install cmake and the Qt 6 dev packages, then run tools/build-plugins)."

if [ ! -d "$HOME/.local/share/sounds/yukishell" ]; then
    python3 "$here/shell/scripts/yukishell-make-sounds.py" >/dev/null 2>&1 || echo "note: UI sounds not generated (install python-numpy and re-run)."
fi

lua="$cfg/hypr/hyprland.lua"
if [ -f "$lua" ] && grep -q '"rice\.' "$lua"; then
    cp "$lua" "$lua.pre-scripts"
    sed -i 's/"rice\." \.\. m/"scripts." .. m/; s/'"'"'rice\." \.\. m/'"'"'scripts." .. m/' "$lua"
fi
[ -f "$lua" ] || { mkdir -p "$cfg/hypr"; : > "$lua"; }
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

if [ -f "$lua" ] && grep -q '>>> MacShell module' "$lua"; then
    cp "$lua" "$lua.pre-fork"
    python3 - "$lua" <<'PY'
import re, sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(re.sub(r"\n?-- >>> MacShell module.*?-- <<< MacShell module <<<\n?", "\n", t, flags=re.S))
PY
fi

sed -i 's/^color_theme = .*/color_theme = "mocha-glass"/; s/^theme_background = .*/theme_background = false/' "$cfg/btop/btop.conf" 2>/dev/null || true
if command -v kwriteconfig6 >/dev/null; then
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme CatppuccinMauve
    kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme CatppuccinMauve
    kwriteconfig6 --file kdeglobals --group General --key AccentColor 203,166,247
    kwriteconfig6 --file kdeglobals --group Icons   --key Theme Papirus-Dark
    kwriteconfig6 --file kdeglobals --group KDE     --key widgetStyle Breeze
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
    kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
    python3 "$here/qt/apply-scheme.py" "$here/qt/CatppuccinMauve.colors" || true
fi
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
if command -v swayimg >/dev/null && command -v xdg-mime >/dev/null && [ -f /usr/share/applications/swayimg.desktop ]; then
    case "$(xdg-mime query default image/png 2>/dev/null)" in
        ""|*chromium*|*chrome*|*firefox*|*librewolf*|*brave*|*vivaldi*|*zen*|*floorp*|*waterfox*|*thorium*)
            xdg-mime default swayimg.desktop $(sed -n 's/^MimeType=//p' /usr/share/applications/swayimg.desktop | tr ';' ' ') ;;
    esac
fi
if command -v chromium >/dev/null && command -v xdg-mime >/dev/null; then
    # links opened from other apps get a small floating Chromium window (float-chromium); Super+W still opens a normal one
    mkdir -p "$HOME/.local/share/applications"
    printf '[Desktop Entry]\nType=Application\nName=Chromium (floating window)\nIcon=chromium\nExec=%s %%U\nMimeType=x-scheme-handler/http;x-scheme-handler/https;\nNoDisplay=true\n' \
        "$cfg/hypr/bin/float-chromium" > "$HOME/.local/share/applications/yuki-link.desktop"
    case "$(xdg-mime query default x-scheme-handler/https 2>/dev/null)" in
        ""|chromium.desktop) xdg-mime default yuki-link.desktop x-scheme-handler/http x-scheme-handler/https ;;
    esac
fi
mkdir -p "$cfg/qt6ct/colors"
link "$here/qt/qt6ct/YukiShell.conf" "$cfg/qt6ct/colors/YukiShell.conf"
printf '[Appearance]\ncolor_scheme_path=%s\ncustom_palette=true\nicon_theme=Papirus-Dark\nstandard_dialogs=default\nstyle=Breeze\n\n[Fonts]\ngeneral="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\nfixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\n' \
    "$cfg/qt6ct/colors/YukiShell.conf" > "$cfg/qt6ct/qt6ct.conf"
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
fi
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
# a new install gets fish as its shell; someone already on zsh or another shell chose it, so it stays
if [ "$first" = 1 ] && command -v fish >/dev/null; then
    case "$(getent passwd "$(id -un)" | cut -d: -f7)" in
        */bash|*/sh|"") sudo chsh -s "$(command -v fish)" "$(id -un)" || true ;;
    esac
fi

echo
doctor=0
"$here/tools/doctor" || doctor=1
if [ "${#failed[@]}" -gt 0 ]; then
    echo
    echo "These packages could not be installed: ${failed[*]}"
    echo "Install them by hand if you want those features, then run this again."
fi
echo
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    setsid -f "$HOME/.local/bin/yuki-start" >/dev/null 2>&1 </dev/null || true
    echo "YukiShell is installed and starting. Log out and back in once so the lock screen and wallpaper start too."
else
    echo "YukiShell is installed. Choose Hyprland at your login screen, or type start-hyprland on a text console."
fi
exit "$doctor"
