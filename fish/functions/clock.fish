function clock --wraps='tty-clock -scb -C 5' --description 'alias clock tty-clock -scb -C 5'
    tty-clock -scb -C 5 $argv
end
