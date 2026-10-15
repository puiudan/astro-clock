# Runs ON THE BOARD (BusyBox sh), fed by scripts/board/health over SSH.
fails=0
section() { printf '\n=== %s\n' "$1"; }
check() {  # name, condition result (0 = pass), detail
	if [ "$2" -eq 0 ]; then printf 'PASS  %-10s %s\n' "$1" "$3"
	else printf 'FAIL  %-10s %s\n' "$1" "$3"; fails=$((fails + 1)); fi
	summary="$summary$1=$([ "$2" -eq 0 ] && echo ok || echo FAIL) "
}
summary=

section "system"
uname -a
uptime
date
date -u
section "ntp"
cat /run/ntp.status 2>/dev/null || echo "(no /run/ntp.status)"
pidof ntpd >/dev/null && echo "ntpd running (pid $(pidof ntpd))" || echo "ntpd NOT running"
section "rtc"
hwclock -r -u 2>&1
section "disk"
df -h
section "network"
ip a
section "dmesg (rtc|eth|remoteproc)"
dmesg | grep -iE 'rtc|eth|remoteproc' | tail -n 25

section "checks"
h=$(hostname)
[ "$h" = astroclock ]; check hostname $? "$h"
tz=$(date +%Z)
case $tz in EEST|EET) r=0 ;; *) r=1 ;; esac; check timezone $r "$tz ($(readlink /etc/localtime))"
y=$(date -u +%Y)
[ "$y" -ge 2026 ]; check clock $? "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
grep -q 'synced=yes' /run/ntp.status 2>/dev/null; check ntp $? "$(cat /run/ntp.status 2>/dev/null || echo 'no status')"
if rtc_s=$(cat /sys/class/rtc/rtc0/since_epoch 2>/dev/null); then
	d=$(( $(date -u +%s) - rtc_s )); [ $d -lt 0 ] && d=$(( -d ))
	[ $d -le 5 ]; r=$?; rtc_detail="RTC-system offset ${d}s"
else r=1; rtc_detail="rtc0 unreadable"; fi
check rtc $r "$rtc_detail"
use=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
[ "$use" -lt 90 ]; check disk $? "rootfs ${use}% used"
ip4=$(ip -4 -o addr show dev eth0 | awk '{print $4}')
[ -n "$ip4" ]; check eth0 $? "${ip4:-no IPv4}"
pidof dropbear >/dev/null; check dropbear $? "sshd"
ping -c 1 -W 3 10.42.0.1 >/dev/null 2>&1; check gateway $? "10.42.0.1"

printf '\nSUMMARY: %s\n' "$summary"
[ $fails -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL ($fails)"
exit $fails
