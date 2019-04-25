#!/bin/sh
exec /usr/bin/i3
[[ -f ~/.Xresources ]] && xrdb -merge -I$HOME ~/.Xresources
