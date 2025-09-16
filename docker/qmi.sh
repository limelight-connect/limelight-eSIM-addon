#!/bin/bash

CMD="$1"

killall quectel-CM || exit 1

[ "x${CMD}" = "xstop" ] && {
    exit 0
}

/usr/bin/quectel-CM &

sleep 5

exit 0