set -g fish_greeting

# --- migrated from ~/.bashrc ---
fish_add_path -g $HOME/.local/bin

set -gx TIME_STYLE '+%-m月%-d日 %H:%M'
for v in LC_TIME LC_NUMERIC LC_MONETARY LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION
    set -gx $v zh_CN.UTF-8
end

alias ls 'ls --color=auto'
alias grep 'grep --color=auto'
alias la 'ls -la'

# --- bash habits that fish lacks ---
# !! and !$ expand to the last command / its last argument
function __last_cmd;  echo $history[1]; end
function __last_arg;  string split ' ' -- $history[1] | tail -n 1; end
abbr -a '!!' --position anywhere --function __last_cmd
abbr -a '!$' --position anywhere --function __last_arg

# `bsource script.sh` runs a bash script and imports the variables it exports (like `source` in bash).
function bsource --description 'Source a bash script into fish (exported vars only)'
    set -l before (env -0 | string split0 | sort)
    set -l after (bash -c 'source "$1" >/dev/null 2>&1; env -0' _ $argv[1] | string split0 | sort)
    for line in (comm -13 (printf '%s\n' $before | psub) (printf '%s\n' $after | psub))
        set -l kv (string split -m1 = -- $line)
        test (count $kv) -eq 2; and set -gx $kv[1] $kv[2]
    end
end

# --- colours: Catppuccin Mocha with the rice's pink accent (the prompt is fish/functions/fish_prompt.fish) ---
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showcolorhints 1
set -g __fish_git_prompt_color_branch cba6f7
set -g __fish_git_prompt_color_dirtystate f9e2af
set -g __fish_git_prompt_color_stagedstate a6e3a1
set -g fish_color_normal cdd6f4
set -g fish_color_command eeacbe
set -g fish_color_keyword cba6f7
set -g fish_color_param f2cdcd
set -g fish_color_option a6e3a1
set -g fish_color_quote a6e3a1
set -g fish_color_redirection f5c2e7
set -g fish_color_operator f5c2e7
set -g fish_color_end fab387
set -g fish_color_escape eba0ac
set -g fish_color_comment 7f849c
set -g fish_color_error f38ba8
set -g fish_color_autosuggestion 6c7086
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=313244
set -g fish_color_search_match --background=313244
set -g fish_color_cancel f38ba8
set -g fish_pager_color_prefix eeacbe --bold
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086
set -g fish_pager_color_progress 6c7086
set -g fish_pager_color_selected_background --background=313244
