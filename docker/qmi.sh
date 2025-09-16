#!/bin/bash

CMD="$1"

killall quectel-CM_x86_64 || exit 1

[ "x${CMD}" = "xstop" ] && {
    exit 0
}

/usr/bin/quectel-CM_x86_64 &

sleep 5

exit 0