function fish_prompt
    set -l last $status
    set -l col 89b4fa 96b3f2 a2b2eb afb1e4 bcb0dc c8afd4 d5aecd e1adc6 eeacbe  # 89b4fa (Arch icon) to eeacbe (folder)
    set -l yk
    for c in (string split '' YukiShell)
        set -a yk (set_color $col[(math (count $yk) + 1)])$c
    end
    set -l info (set_color 89b4fa) (string join '' $yk) (set_color eeacbe) (prompt_pwd --full-length-dirs 2)
    set -l git (fish_git_prompt '%s')
    test -n "$git"; and set -a info (set_color cba6f7) $git
    test "$CMD_DURATION" -gt 3000 2>/dev/null; and set -a info (set_color f9e2af)󰔟 (math -s1 $CMD_DURATION / 1000)s
    test $last -ne 0; and set -a info (set_color f38ba8) $last
    echo $info
    test $last -eq 0; and set_color cba6f7; or set_color f38ba8
    echo -n '❯ '
    set_color normal
end
