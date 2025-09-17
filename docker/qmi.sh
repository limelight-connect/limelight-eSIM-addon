#!/bin/bash
#set -euo pipefail

CMD="${1:-}"
MODE="${2:-}"
IFNAME="${3:-}"

if [ "x${MODE}" = "xECM" ]; then
  echo "${MODE}" > /data/esim/mode.txt
  sync
elif [ "x${MODE}" = "xQ_WWAN" ]; then
  echo "${MODE}" > /data/esim/mode.txt
  sync
elif [ "x${MODE}" != "x" ]; then
  exit 1
fi

if [ "x${IFNAME}" != "x" ]; then
  ip link show dev "${IFNAME}" 1>/dev/null 2>&1 && {
    echo "${IFNAME}" > /data/esim/ifname.txt
    sync
  }
fi

if [ "x${CMD}" = "xstop" ]; then
  echo N > /data/esim/qmi.txt
  sync
  [ "x${MODE}" = "xQ_WWAN" ] && {
    QMI_PID=$(ps -ef | grep 'quectel-CM' | grep -v grep | awk '{print $2}')
    [ "x${QMI_PID}" = "x" ] && exit 0
    kill ${QMI_PID}
    exit $?
  }
  [ "x${MODE}" = "xECM" ] && {
    [ "x${IFNAME}" = "x" ] && exit 1
    pkill -f "udhcpc -i ${IFNAME}" 2>/dev/null
    ip link set dev "${IFNAME}" down && \
    ip addr flush dev "${IFNAME}" && \
    ip route flush dev "${IFNAME}"
    exit $?
  }
  exit 0
fi

if [ "x${CMD}" = "xstart" ]; then
  echo Y > /data/esim/qmi.txt
  sync
  sleep 5
  exit 0
fi

while [ 1 ];do
  ESIM_MODE=$(cat /data/esim/mode.txt 2>/dev/null)
  ESIM_IFNAME=$(cat /data/esim/ifname.txt 2>/dev/null)

  [ "x${ESIM_MODE}" = "x" ] && {
    sleep 5
    continue
  }
  FLAG=$(cat /data/esim/qmi.txt 2>/dev/null)
  [ "x${FLAG}" = "xY" ] && {
    if [ "x${ESIM_MODE}" = "xQ_WWAN" ]; then
      QMI_PID=$(ps -ef | grep 'quectel-CM' | grep -v grep | awk '{print $2}')
      [ "x${QMI_PID}" != "x" ] && kill ${QMI_PID}
        grep -qE '^Y$' /sys/class/net/wwan0/qmi/raw_ip || echo Y > /sys/class/net/wwan0/qmi/raw_ip
        /usr/bin/quectel-CM 1>/dev/null 2>&1
    elif [ "x${ESIM_MODE}" = "xECM" ]; then
      if [ "x${ESIM_IFNAME}" != "x" ]; then
        ip link show dev "${ESIM_IFNAME}" 2>/dev/null | grep -qw "UP" || {
          ip link set dev "${ESIM_IFNAME}" up
        }
        pkill -f "udhcpc -i ${IFNAME}" 2>/dev/null
        udhcpc -i "${IFNAME}"
        echo "" > /data/esim/qmi.txt
      fi
    fi
  }
  sleep 3
done
exit 0