function pipes --wraps=pipes.sh --description 'Run pipes.sh with vibrant colors and rounded pipes'
    command pipes.sh -p 2 -t 1 -c 4 -c 5 -c 6 -c 3 -R -K $argv
end
