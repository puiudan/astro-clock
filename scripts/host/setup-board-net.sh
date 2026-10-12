#!/usr/bin/env bash
# One-time (idempotent) host setup for the direct board Ethernet link.
# Run by the user as root:   sudo scripts/host/setup-board-net.sh <board-eth0-MAC>
#
# What it does (Debian 13, NetworkManager 1.52, iptables-nft backend):
#  1. NM connection "dk2-shared" on enp0s31f6: ipv4.method=shared, 10.42.0.1/24
#     (NM runs dnsmasq for DHCP/DNS and NATs 10.42.0.0/24 out of the default route).
#  2. Fixed DHCP lease MAC -> 10.42.0.2 (hostname astroclock) in
#     /etc/NetworkManager/dnsmasq-shared.d/astro-board.conf.
#  3. Forwarding fixes, installed as /usr/local/sbin/astro-board-fw and re-applied
#     by an NM dispatcher hook (link up) and a systemd unit (boot, docker start):
#     - NM's own nm-shared-<iface> nft table rejects NEW forwarded connections
#       into the interface, so containers (docker0) cannot open connections to
#       the board. Insert an accept for docker0 -> 10.42.0.0/24 ahead of it.
#     - DOCKER-USER rules so Docker's FORWARD handling never drops board traffic
#       (protects against Docker's DROP policy if ip-forward-no-drop is removed).
#  4. Re-activates the connection only if its settings changed, applies the rules
#     and prints a diagnostic of the resulting state.
# It removes nothing outside the files it owns and never flushes rulesets.
set -euo pipefail

IFACE=enp0s31f6
CON=dk2-shared
HOST_CIDR=10.42.0.1/24
SUBNET=10.42.0.0/24
BOARD_IP=10.42.0.2
BOARD_NAME=astroclock
LEASE_CONF=/etc/NetworkManager/dnsmasq-shared.d/astro-board.conf
FW_HELPER=/usr/local/sbin/astro-board-fw
DISPATCHER=/etc/NetworkManager/dispatcher.d/90-astro-board-fw
UNIT=/etc/systemd/system/astro-board-fw.service

die() { printf 'setup-board-net: %s\n' "$*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }

[[ $# -eq 1 ]] || die "usage: sudo $0 <board-eth0-MAC>   (read it with: scripts/board/serial-run 'cat /sys/class/net/eth0/address')"
mac=${1,,}
[[ $mac =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] || die "not a MAC address: $1"
(( EUID == 0 )) || die "run as root (sudo)"

say "Preconditions"
dpkg-query -W -f='${Status}\n' dnsmasq-base 2>/dev/null | grep -q 'install ok installed' \
    || die "dnsmasq-base is not installed (apt install dnsmasq-base)"
echo "dnsmasq-base: $(dpkg-query -W -f='${Version}' dnsmasq-base)"
{ command -v nmcli >/dev/null && systemctl is-active --quiet NetworkManager; } || die "NetworkManager is not running"
echo "NetworkManager: $(nmcli -t -f VERSION general 2>/dev/null || nmcli --version)"
ip link show "$IFACE" >/dev/null 2>&1 || die "interface $IFACE not found"
command -v nft >/dev/null || die "nft not found (apt install nftables)"
ipt_version=$(iptables --version)
echo "iptables: $ipt_version"
[[ $ipt_version == *nf_tables* ]] || die "iptables is not the nf_tables backend; review the DOCKER-USER rules before continuing"
echo "firewall backend: nftables (iptables-nft); Docker and NM rules share the forward hook"

say "1. NetworkManager connection $CON"
changed=0
if nmcli -t -f NAME connection show | grep -qx "$CON"; then
    current=$(nmcli -g connection.interface-name,ipv4.method,ipv4.addresses,ipv6.method,connection.autoconnect connection show "$CON")
    if [[ $current != "$IFACE:shared:$HOST_CIDR:disabled:yes" ]]; then
        nmcli connection modify "$CON" connection.interface-name "$IFACE" ipv4.method shared \
            ipv4.addresses "$HOST_CIDR" ipv6.method disabled connection.autoconnect yes
        changed=1; echo "updated (was: $current)"
    else
        echo "already configured"
    fi
else
    nmcli connection add type ethernet con-name "$CON" ifname "$IFACE" ipv4.method shared \
        ipv4.addresses "$HOST_CIDR" ipv6.method disabled connection.autoconnect yes
    changed=1; echo "created"
fi
others=$(nmcli -t -f NAME,DEVICE,TYPE connection show | awk -F: -v c="$CON" '$3=="802-3-ethernet" && $1!=c {print $1}')
[[ -z $others ]] || echo "note: other ethernet profiles exist (${others//$'\n'/, }); $CON is the one to keep active on $IFACE"

say "2. Fixed DHCP lease $mac -> $BOARD_IP"
lease_content="# Managed by astro-clock scripts/host/setup-board-net.sh
dhcp-host=$mac,$BOARD_IP,$BOARD_NAME,infinite"
install -d -m 0755 "$(dirname "$LEASE_CONF")"
if [[ ! -f $LEASE_CONF || "$(cat "$LEASE_CONF")" != "$lease_content" ]]; then
    printf '%s\n' "$lease_content" > "$LEASE_CONF.tmp" && chmod 0644 "$LEASE_CONF.tmp" && mv -f "$LEASE_CONF.tmp" "$LEASE_CONF"
    changed=1; echo "wrote $LEASE_CONF"
else
    echo "unchanged $LEASE_CONF"
fi

say "3. Forwarding helper, dispatcher hook and systemd unit"
write_if_changed() {  # path mode content
    if [[ ! -f $1 || "$(cat "$1")" != "$3" ]]; then
        printf '%s\n' "$3" > "$1.tmp" && chmod "$2" "$1.tmp" && mv -f "$1.tmp" "$1"
        echo "wrote $1"
    else
        echo "unchanged $1"
    fi
}
write_if_changed "$FW_HELPER" 0755 "$(cat <<EOF
#!/bin/sh
# Managed by astro-clock scripts/host/setup-board-net.sh. Idempotent.
# Lets containers on docker0 open connections to the board subnet and keeps
# Docker's FORWARD handling from dropping NM shared-mode traffic.
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
IFACE=$IFACE
SUBNET=$SUBNET
TAG=astro-board
status=0

# NetworkManager shared mode: table ip nm-shared-\$IFACE, chain filter_forward,
# ends with 'oifname \$IFACE reject'. NM recreates it on every activation,
# which is why this also runs from the dispatcher hook.
table=nm-shared-\$IFACE
if nft list chain ip "\$table" filter_forward >/dev/null 2>&1; then
    if ! nft list chain ip "\$table" filter_forward | grep -q "comment \"\$TAG\""; then
        nft insert rule ip "\$table" filter_forward iifname "docker0" oifname "\$IFACE" \\
            ip daddr "\$SUBNET" counter accept comment "\"\$TAG\""
    fi
else
    echo "astro-board-fw: nft table ip \$table not present (connection down?)" >&2
    status=1
fi

# Docker: DOCKER-USER is evaluated first in iptables' FORWARD chain.
if iptables -n -L DOCKER-USER >/dev/null 2>&1; then
    add() { iptables -C DOCKER-USER "\$@" -m comment --comment "\$TAG" -j ACCEPT 2>/dev/null \\
        || iptables -I DOCKER-USER 1 "\$@" -m comment --comment "\$TAG" -j ACCEPT; }
    add -o "\$IFACE" -m conntrack --ctstate RELATED,ESTABLISHED
    add -i "\$IFACE" -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED
    add -i docker0 -o "\$IFACE"
    add -i "\$IFACE" ! -o docker0
else
    echo "astro-board-fw: DOCKER-USER chain not present (docker not running?)" >&2
    status=1
fi
exit \$status
EOF
)"
write_if_changed "$DISPATCHER" 0755 "$(cat <<EOF
#!/bin/sh
# Managed by astro-clock scripts/host/setup-board-net.sh.
# Re-apply board forwarding rules whenever NM (re)creates its shared table.
[ "\$1" = "$IFACE" ] || exit 0
case "\$2" in
    up|reapply) $FW_HELPER || logger -t astro-board-fw "apply failed on \$2" ;;
esac
exit 0
EOF
)"
write_if_changed "$UNIT" 0644 "$(cat <<EOF
# Managed by astro-clock scripts/host/setup-board-net.sh.
[Unit]
Description=astro-clock board forwarding rules (docker0 <-> $IFACE)
After=docker.service NetworkManager.service
Wants=NetworkManager.service
# Stop with docker so a docker restart re-runs it (Docker rebuilds its chains).
PartOf=docker.service

[Service]
Type=oneshot
# Docker may start before NM activates $IFACE; retry briefly, then give up
# quietly (the NM dispatcher hook applies the rules when the link comes up).
ExecStart=/bin/sh -c 'for i in 1 2 3 4 5 6; do $FW_HELPER && exit 0; sleep 5; done; exit 0'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target docker.service
EOF
)"
systemctl daemon-reload
systemctl enable astro-board-fw.service >/dev/null 2>&1
echo "enabled astro-board-fw.service"

say "4. Activate"
if (( changed )); then
    echo "settings changed: re-activating $CON (brief link bounce on $IFACE)"
    nmcli connection up "$CON" >/dev/null || echo "warning: could not activate $CON (cable unplugged?)"
    sleep 2
fi
if "$FW_HELPER"; then echo "forwarding rules applied"; else echo "warning: rules not fully applied (see above)"; fi

say "Resulting state"
nmcli -f GENERAL.STATE,IP4.ADDRESS device show "$IFACE" || true
echo "--- $LEASE_CONF"; cat "$LEASE_CONF"
echo "--- nft table ip nm-shared-$IFACE"; nft list table ip "nm-shared-$IFACE" 2>&1 || true
echo "--- iptables DOCKER-USER"; iptables -S DOCKER-USER 2>&1 || true
echo "--- iptables FORWARD policy"; iptables -S FORWARD | head -1
cat <<EOF

Done. The board gets $BOARD_IP on its next DHCP request; to force it now, reboot
the board (scripts/host/dev scripts/board/serial-run reboot 5) and wait ~30 s.
Then check without sudo: scripts/host/check-board-net.sh
EOF
