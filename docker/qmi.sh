#!/bin/bash
#set -euo pipefail

CMD="${1:-}"

QMI_PID=$(ps -ef | grep 'quectel-CM' | awk '{print $2}')

if [ "x${CMD}" = "xstop" ]; then
  [ "x${QMI_PID}" = "x" ] && exit 0
  kill ${QMI_PID}
  exit $?
fi

[ "x${QMI_PID}" != "x" ] && kill ${QMI_PID}
sleep 2

grep -qE '^Y$' /sys/class/net/wwan0/qmi/raw_ip || echo Y > /sys/class/net/wwan0/qmi/raw_ip #|| exit 1
nohup setsid /usr/bin/quectel-CM </dev/null >/dev/null 2>&1 &
sleep 5
exit 0