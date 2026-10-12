#!/usr/bin/env bash
# Check the direct board Ethernet link from the host (no sudo).
# Exit status is the number of failed checks.
set -uo pipefail
IFACE=enp0s31f6
CON=dk2-shared
BOARD_IP=${BOARD_IP:-10.42.0.2}
LEASE_CONF=/etc/NetworkManager/dnsmasq-shared.d/astro-board.conf
fails=0
check() {  # description, command...
    local desc=$1; shift
    if out=$("$@" 2>&1); then printf 'PASS  %s%s\n' "$desc" "${out:+: $out}"
    else printf 'FAIL  %s%s\n' "$desc" "${out:+: $out}"; fails=$((fails + 1)); fi
}
check "link $IFACE carrier" sh -c "[ \"\$(cat /sys/class/net/$IFACE/carrier 2>/dev/null)\" = 1 ] && echo up"
check "NM connection $CON active" sh -c "nmcli -t -f GENERAL.CONNECTION device show $IFACE | grep -q ':$CON\$' && echo active"
check "host address 10.42.0.1/24" sh -c "ip -4 -o addr show dev $IFACE | grep -q ' 10.42.0.1/24 ' && echo present"
check "NM dnsmasq running" sh -c "pgrep -f 'dnsmasq.*listen-address=10.42.0.1' >/dev/null && echo running"
check "fixed lease configured" sh -c "grep -h '^dhcp-host=' $LEASE_CONF"
check "board MAC in neighbour table" sh -c "ip neigh show $BOARD_IP dev $IFACE | grep -o 'lladdr [0-9a-f:]*' || { ip neigh show dev $IFACE; false; }"
check "ping $BOARD_IP" sh -c "ping -c 2 -W 2 $BOARD_IP | tail -1"
check "board SSH port 22" sh -c "timeout 3 bash -c '</dev/tcp/$BOARD_IP/22' && echo open"
if docker inspect -f '{{.State.Running}}' astro-clock-dev 2>/dev/null | grep -q true; then
    check "container -> board ping" sh -c "docker exec astro-clock-dev ping -c 2 -W 2 $BOARD_IP | tail -1"
fi
echo "failed checks: $fails"
exit "$fails"
