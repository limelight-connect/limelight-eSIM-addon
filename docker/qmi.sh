#!/bin/bash

CMD="$1"

grep -E "^Y$" /sys/class/net/wwan0/qmi/raw_ip || {
    echo Y > /sys/class/net/wwan0/qmi/raw_ip || exit 1
}

QMI_PID=$(ps -ef | grep quectel-CM | grep -v grep | awk '{print $2}')

[ "x${CMD}" = "xstop" ] && {
    [ "x${QMI_PID}" = "x" ] && exit 0
    kill ${QMI_PID}
    exit $?
}

[ "x${QMI_PID}" != "x" ] && kill ${QMI_PID}
sleep 2
/usr/bin/quectel-CM &
sleep 5
exit 0