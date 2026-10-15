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
check "no competing autoconnect profile on $IFACE" sh -c "
    for u in \$(nmcli -g UUID,TYPE connection show | awk -F: '\$2 ~ /ethernet/ {print \$1}'); do
        [ \"\$(nmcli -g connection.id connection show \$u)\" = $CON ] && continue
        [ \"\$(nmcli -g connection.interface-name connection show \$u)\" = $IFACE ] || continue
        [ \"\$(nmcli -g connection.autoconnect connection show \$u)\" = yes ] || continue
        echo \"'\$(nmcli -g connection.id connection show \$u)' autoconnects on $IFACE; re-run sudo scripts/host/setup-board-net.sh\"; exit 1
    done; echo none"
# The ping checks use pipefail: without it the exit status is tail's (always 0)
# and a 100% packet loss line passed. -I pins the ping to the board link, so it
# cannot be answered through another route when dk2-shared is down.
check "ping $BOARD_IP via $IFACE" bash -o pipefail -c "ping -c 2 -W 2 -I $IFACE $BOARD_IP | tail -1"
# After the ping, a live board is REACHABLE; STALE/FAILED entries are leftovers.
check "board MAC in neighbour table" sh -c "ip neigh show $BOARD_IP dev $IFACE | grep -E 'REACHABLE|DELAY|PROBE|PERMANENT' | grep -o 'lladdr [0-9a-f:]*' || { ip neigh show $BOARD_IP dev $IFACE; false; }"
check "board SSH port 22" sh -c "timeout 3 bash -c '</dev/tcp/$BOARD_IP/22' && echo open"
if docker inspect -f '{{.State.Running}}' astro-clock-dev 2>/dev/null | grep -q true; then
    check "container -> board ping" bash -o pipefail -c "docker exec astro-clock-dev ping -c 2 -W 2 $BOARD_IP | tail -1"
fi
echo "failed checks: $fails"
exit "$fails"
