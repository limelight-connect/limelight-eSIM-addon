#!/bin/bash
#set -euo pipefail

CMD="${1:-}"

if [ "x${CMD}" = "xstop" ]; then
  echo N > /data/esim/qmi.txt
  sync
  QMI_PID=$(ps -ef | grep 'quectel-CM' | grep -v grep | awk '{print $2}')
  [ "x${QMI_PID}" = "x" ] && exit 0
  kill ${QMI_PID}
  exit $?
fi

if [ "x${CMD}" = "xstart" ]; then
  echo Y > /data/esim/qmi.txt
  sync
  exit 0
fi

while [ 1 ];do
  FLAG=$(cat /data/esim/qmi.txt 2>/dev/null)
  [ "x${FLAG}" = "xY" ] && {
    QMI_PID=$(ps -ef | grep 'quectel-CM' | grep -v grep | awk '{print $2}')
    [ "x${QMI_PID}" != "x" ] && kill ${QMI_PID}
    grep -qE '^Y$' /sys/class/net/wwan0/qmi/raw_ip || echo Y > /sys/class/net/wwan0/qmi/raw_ip
    /usr/bin/quectel-CM 1>/dev/null 2>&1
  }
  sleep 5
done
exit 0