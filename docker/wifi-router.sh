#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"

AP_IF="${AP_IF:-wlp0s20f3}"

WAN_IF="${WAN_IF:-enp3s0}"
WAN_CANDIDATES="${WAN_CANDIDATES:-enp3s0 wwan0}"
WAN_TEST_HOST="${WAN_TEST_HOST:-1.1.1.1}"
WAN_TEST_TIMEOUT="${WAN_TEST_TIMEOUT:-2}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-10}"

LAN_CIDR="${LAN_CIDR:-192.168.50.1/24}"
LAN_GW="${LAN_GW:-192.168.50.1}"
DHCP_START="${DHCP_START:-192.168.50.10}"
DHCP_END="${DHCP_END:-192.168.50.200}"
DHCP_LEASE="${DHCP_LEASE:-12h}"

SSID="${SSID:-limelight}"
PASSPHRASE="${PASSPHRASE:-limelight}"
CHANNEL="${CHANNEL:-6}"
HW_MODE="${HW_MODE:-g}"

RUNDIR="${RUNDIR:-/data/esim}"
PID_HOSTAPD="${RUNDIR}/hostapd.pid"
PID_DNSMASQ="${RUNDIR}/dnsmasq.pid"
CONF_HOSTAPD="${RUNDIR}/hostapd.conf"
CONF_DNSMASQ="${RUNDIR}/dnsmasq.conf"

CONTROL_FILE="${CONTROL_FILE:-${RUNDIR}/control.state}"
WAN_STATE_FILE="${WAN_STATE_FILE:-${RUNDIR}/wan.if}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1"; exit 1; }; }

iptables_add_once() {
  local table="$1"; shift
  if iptables -t "$table" -C "$@" 2>/dev/null; then
    return 0
  fi
  iptables -t "$table" -A "$@"
}

iptables_del_if_present() {
  local table="$1"; shift
  while iptables -t "$table" -C "$@" 2>/dev/null; do
    iptables -t "$table" -D "$@"
  done
}

die() { echo "$*"; exit 1; }

ensure_dirs() {
  mkdir -p "$RUNDIR"
  chmod 700 "$RUNDIR" 2>/dev/null || true
}

load_saved_wan() {
  if [[ -f "$WAN_STATE_FILE" ]]; then
    local saved
    saved="$(cat "$WAN_STATE_FILE" 2>/dev/null || true)"
    if [[ -n "${saved:-}" ]]; then
      WAN_IF="$saved"
    fi
  fi
}

save_wan() {
  printf '%s\n' "$WAN_IF" >"$WAN_STATE_FILE"
}

check_ifaces() {
  ip link show "$AP_IF" >/dev/null 2>&1 || die "AP interface not found: $AP_IF"

  local ok=0 ifc
  for ifc in $WAN_CANDIDATES; do
    if ip link show "$ifc" >/dev/null 2>&1; then
      ok=1
      break
    fi
  done
  [[ "$ok" -eq 1 ]] || die "No WAN candidate interface exists: $WAN_CANDIDATES"
}

check_forwarding() {
  local v
  v="$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)"
  if [[ "$v" != "1" ]]; then
    die "IPv4 forwarding is disabled (/proc/sys/net/ipv4/ip_forward=$v). Enable it on host."
  fi
}

is_if_up() {
  local ifc="$1"
  ip link show "$ifc" >/dev/null 2>&1 || return 1
  ip -o link show "$ifc" | grep -q "state UP"
}

has_ipv4_addr() {
  local ifc="$1"
  ip -4 -o addr show dev "$ifc" | grep -q "inet "
}

wan_reachable() {
  local ifc="$1"
  is_if_up "$ifc" || return 1
  has_ipv4_addr "$ifc" || return 1
  ping -I "$ifc" -c 1 -W "$WAN_TEST_TIMEOUT" "$WAN_TEST_HOST" >/dev/null 2>&1
}

pick_wan() {
  local ifc
  for ifc in $WAN_CANDIDATES; do
    if wan_reachable "$ifc"; then
      echo "$ifc"
      return 0
    fi
  done
  return 1
}

setup_nat() {
  iptables_add_once nat POSTROUTING -o "$WAN_IF" -j MASQUERADE
  iptables_add_once filter FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT
  iptables_add_once filter FORWARD -i "$WAN_IF" -o "$AP_IF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
}

clear_nat() {
  iptables_del_if_present nat POSTROUTING -o "$WAN_IF" -j MASQUERADE
  iptables_del_if_present filter FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT
  iptables_del_if_present filter FORWARD -i "$WAN_IF" -o "$AP_IF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
}

apply_wan() {
  local new_wan="$1"
  [[ -n "${new_wan:-}" ]] || die "No WAN interface selected"

  if [[ "${WAN_IF:-}" == "$new_wan" ]]; then
    return 0
  fi

  clear_nat || true

  WAN_IF="$new_wan"
  save_wan
  setup_nat
}

write_confs() {
  cat >"$CONF_DNSMASQ" <<EOF
interface=${AP_IF}
bind-interfaces
dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,${DHCP_LEASE}
dhcp-option=option:router,${LAN_GW}
dhcp-option=option:dns-server,${LAN_GW}
domain-needed
bogus-priv
no-resolv
server=1.1.1.1
server=8.8.8.8
log-dhcp
EOF

  cat >"$CONF_HOSTAPD" <<EOF
interface=${AP_IF}
driver=nl80211
ssid=${SSID}
hw_mode=${HW_MODE}
channel=${CHANNEL}
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=${PASSPHRASE}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
}

start_dnsmasq() {
  if [[ -f "$PID_DNSMASQ" ]] && kill -0 "$(cat "$PID_DNSMASQ")" 2>/dev/null; then
    return 0
  fi
  dnsmasq --conf-file="$CONF_DNSMASQ" --pid-file="$PID_DNSMASQ" --keep-in-foreground >/dev/null 2>&1 &
  sleep 0.2
  if [[ ! -f "$PID_DNSMASQ" ]] || ! kill -0 "$(cat "$PID_DNSMASQ")" 2>/dev/null; then
    die "dnsmasq failed to start"
  fi
}

stop_dnsmasq() {
  if [[ -f "$PID_DNSMASQ" ]]; then
    kill "$(cat "$PID_DNSMASQ")" 2>/dev/null || true
    rm -f "$PID_DNSMASQ"
  fi
  pkill -x dnsmasq 2>/dev/null || true
}

start_hostapd() {
  if [[ -f "$PID_HOSTAPD" ]] && kill -0 "$(cat "$PID_HOSTAPD")" 2>/dev/null; then
    return 0
  fi
  hostapd -B -P "$PID_HOSTAPD" "$CONF_HOSTAPD" >/dev/null 2>&1 || die "hostapd failed to start"
  sleep 0.2
  if [[ ! -f "$PID_HOSTAPD" ]] || ! kill -0 "$(cat "$PID_HOSTAPD")" 2>/dev/null; then
    die "hostapd failed to start"
  fi
}

stop_hostapd() {
  if [[ -f "$PID_HOSTAPD" ]]; then
    kill "$(cat "$PID_HOSTAPD")" 2>/dev/null || true
    rm -f "$PID_HOSTAPD"
  fi
  pkill -x hostapd 2>/dev/null || true
}

setup_ap_ip() {
  ip link set "$AP_IF" up || true
  ip addr flush dev "$AP_IF" || true
  ip addr add "$LAN_CIDR" dev "$AP_IF"
}

clear_ap_ip() {
  ip addr flush dev "$AP_IF" 2>/dev/null || true
}

read_control() {
  if [[ ! -f "$CONTROL_FILE" ]]; then
    printf '%s\n' "run" >"$CONTROL_FILE"
  fi
  local raw
  raw="$(cat "$CONTROL_FILE" 2>/dev/null || true)"
  raw="$(printf '%s' "$raw" | tr -d '\r' | tr '[:upper:]' '[:lower:]' | awk '{print $1}')"
  case "$raw" in
    run|pause|stop) printf '%s\n' "$raw" ;;
    *) printf '%s\n' "run" ;;
  esac
}

set_control() {
  local v="${1:-}"
  case "$v" in
    run|pause|stop) ;;
    *) die "Invalid control value: $v (use run|pause|stop)" ;;
  esac
  ensure_dirs
  printf '%s\n' "$v" >"$CONTROL_FILE"
  echo "OK"
}

show_status() {
  echo "AP_IF=$AP_IF WAN_IF=$WAN_IF"
  echo "WAN_CANDIDATES=$WAN_CANDIDATES"
  echo "RUNDIR=$RUNDIR"
  echo "CONTROL_FILE=$CONTROL_FILE control=$(read_control)"
  echo "WAN_STATE_FILE=$WAN_STATE_FILE"
  echo "LAN_CIDR=$LAN_CIDR SSID=$SSID CHANNEL=$CHANNEL"
  echo "ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo '?')"
  echo

  echo "[Interfaces]"
  ip -o link show "$AP_IF" 2>/dev/null || true
  ip -o addr show dev "$AP_IF" 2>/dev/null || true
  for ifc in $WAN_CANDIDATES; do
    ip -o link show "$ifc" 2>/dev/null || true
    ip -4 -o addr show dev "$ifc" 2>/dev/null || true
  done
  echo

  echo "[WAN reachability]"
  for ifc in $WAN_CANDIDATES; do
    if wan_reachable "$ifc"; then
      echo "$ifc: OK"
    else
      echo "$ifc: NO"
    fi
  done
  echo

  echo "[Processes]"
  if [[ -f "$PID_HOSTAPD" ]] && kill -0 "$(cat "$PID_HOSTAPD")" 2>/dev/null; then
    echo "hostapd: running (pid $(cat "$PID_HOSTAPD"))"
  else
    echo "hostapd: not running"
  fi
  if [[ -f "$PID_DNSMASQ" ]] && kill -0 "$(cat "$PID_DNSMASQ")" 2>/dev/null; then
    echo "dnsmasq: running (pid $(cat "$PID_DNSMASQ"))"
  else
    echo "dnsmasq: not running"
  fi
  echo

  echo "[iptables]"
  iptables -t nat -L POSTROUTING -n -v --line-numbers | head -n 30 || true
  iptables -L FORWARD -n -v --line-numbers | head -n 60 || true
}

start_all() {
  need ip
  need iptables
  need hostapd
  need dnsmasq
  need ping

  ensure_dirs
  load_saved_wan
  check_ifaces
  check_forwarding
  write_confs
  setup_ap_ip

  local chosen
  chosen="$(pick_wan || true)"
  [[ -n "${chosen:-}" ]] || die "No usable WAN found in: $WAN_CANDIDATES"

  WAN_IF="$chosen"
  save_wan
  setup_nat

  start_dnsmasq
  start_hostapd
  echo "OK (WAN=$WAN_IF)"
}

stop_all() {
  ensure_dirs
  stop_hostapd
  stop_dnsmasq
  clear_nat
  clear_ap_ip
  echo "OK"
}

monitor_loop() {
  need ip
  need iptables
  need ping

  ensure_dirs
  load_saved_wan
  check_forwarding
  check_ifaces

  if [[ ! -f "$CONTROL_FILE" ]]; then
    printf '%s\n' "run" >"$CONTROL_FILE"
  fi

  while true; do
    local mode
    mode="$(read_control)"

    if [[ "$mode" == "stop" ]]; then
      exit 0
    fi

    if [[ "$mode" == "run" ]]; then
      local chosen
      chosen="$(pick_wan || true)"
      if [[ -n "${chosen:-}" ]]; then
        apply_wan "$chosen" || true
      fi
    fi

    sleep "$MONITOR_INTERVAL"
  done
}

case "$ACTION" in
  start) start_all ;;
  stop) stop_all ;;
  restart) stop_all; start_all ;;
  status) show_status ;;
  monitor) monitor_loop ;;
  set-control) set_control "${2:-}" ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|monitor|set-control <run|pause|stop>}"
    echo "Env overrides:"
    echo "  AP_IF LAN_CIDR LAN_GW DHCP_START DHCP_END DHCP_LEASE SSID PASSPHRASE CHANNEL HW_MODE"
    echo "  WAN_CANDIDATES WAN_TEST_HOST WAN_TEST_TIMEOUT MONITOR_INTERVAL"
    echo "  RUNDIR CONTROL_FILE WAN_STATE_FILE"
    exit 2
    ;;
esac
