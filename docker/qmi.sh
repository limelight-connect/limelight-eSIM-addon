#!/bin/bash
#set -euo pipefail

CMD="${1:-}"

grep -qE '^Y$' /sys/class/net/wwan0/qmi/raw_ip || echo Y > /sys/class/net/wwan0/qmi/raw_ip #|| exit 1

QMI_PID=$(ps -ef | grep 'quectel-CM' | awk '{print $2}')

if [ "x${CMD}" = "xstop" ]; then
  [ -z "${QMI_PID}" ] && exit 0
  kill "${QMI_PID}"
  exit $?
fi

[ -n "${QMI_PID}" ] && kill "${QMI_PID}" || true
sleep 2

nohup setsid /usr/bin/quectel-CM </dev/null >/dev/null 2>&1 &
sleep 5
exit 0