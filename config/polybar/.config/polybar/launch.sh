#!/usr/bin/env bash

# Terminate already running bar instances
killall -9 -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar1 and bar2
#polybar top &
ln -s /tmp/polybar_mqueue.$! /tmp/ipc-top

~/polybar/build/bin/polybar bottom &
ln -s /tmp/polybar_mqueue.$! /tmp/ipc-bottom


for m in $(~/polybar/build/bin/polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m ~/polybar/build/bin/polybar --reload top &
done

echo "Bars launched..."

