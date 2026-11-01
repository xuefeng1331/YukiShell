function ll --wraps=ls --description 'ls -la: folders blue, programs pink, the rest a blue-to-pink gradient'
    if not isatty stdout
        command ls -la $argv
        return
    end
    command ls -la --color=never $argv | awk '
        { line[NR] = $0; if (length($0) > w) w = length($0) }
        END {
            for (i = 1; i <= NR; i++) {
                s = line[i]
                if (s ~ /^d/) { printf "\033[38;2;137;180;250m%s\033[0m\n", s; continue }
                if (s ~ /^-/ && substr(s, 2, 9) ~ /x/) { printf "\033[38;2;238;172;190m%s\033[0m\n", s; continue }
                o = ""
                for (j = 1; j <= length(s); j++) {
                    ch = substr(s, j, 1); t = w > 1 ? (j - 1) / (w - 1) : 0
                    o = o (ch == " " ? ch : sprintf("\033[38;2;%d;%d;%dm%s", 137 + 101 * t + .5, 180 - 8 * t + .5, 250 - 60 * t + .5, ch))
                }
                print o "\033[0m"
            }
        }'
end
