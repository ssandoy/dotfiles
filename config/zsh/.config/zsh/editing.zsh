autoload -Uz select-word-style
select-word-style bash

# Treat / as a boundary so Meta deletions stop at directory components.
typeset -g WORDCHARS="${WORDCHARS//\/}"
