function sysup --description 'Update the entire machine (system, AUR, and Flatpak)'
    sudo pacman -Syu $argv
    and yay -Syu $argv
    if command -q flatpak
        flatpak update
    end
end
