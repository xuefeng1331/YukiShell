function cl --wraps=clear --description 'Clear the terminal'
    printf '\033[2J\033[3J\033[1;1H'
end
