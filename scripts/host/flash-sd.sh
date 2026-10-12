#!/usr/bin/env bash
# Write an SD card image to the board's SD card exposed over U-Boot UMS
# (USB mass storage). Run by the user only:
#   sudo scripts/host/flash-sd.sh [image]      (default: .build/artifacts/astroclock-sdcard-latest.img)
# The image must have <image>.sha256 next to it (scripts/host/fetch-image makes it).
#
# Safety: verifies the image checksum first; lists all disks with model, serial,
# size and transport; only offers removable or USB disks of at most 64 GB that
# are larger than the image; requires typing the device name; unmounts only
# that device's partitions; re-checks its identity right before writing; then
# dd conv=fsync, sync, and a read-back checksum comparison.
set -euo pipefail

max_bytes=$((64 * 1000 * 1000 * 1000))
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
image=${1:-$project_root/.build/artifacts/astroclock-sdcard-latest.img}

die() { printf 'flash-sd: %s\n' "$*" >&2; exit 1; }
(( EUID == 0 )) || die "run with sudo"
[[ -f $image ]] || die "image not found: $image (run scripts/host/fetch-image first)"
sumfile=$image.sha256
[[ -f $sumfile ]] || die "checksum file not found: $sumfile"
image=$(realpath -- "$image")
expected=$(awk 'NR==1 {print $1}' "$sumfile")
[[ $expected =~ ^[0-9a-f]{64}$ ]] || die "no SHA-256 in $sumfile"
image_bytes=$(stat -c %s -- "$image")

echo "== Image"
echo "file:     $image"
echo "size:     $image_bytes bytes"
echo "expected: $expected"
actual=$(sha256sum -- "$image" | awk '{print $1}')
echo "actual:   $actual"
[[ $actual == "$expected" ]] || die "image checksum mismatch; refusing to write"

echo
echo "== Block devices (whole disks)"
declare -A eligible=()
printf '%-8s %-5s %-3s %14s  %-24s %-24s %s\n' NAME TRAN RM BYTES MODEL SERIAL VERDICT
# Parse lsblk JSON without eval: model/serial strings come from the device.
list_disks() {
    lsblk -d -b -J -o NAME,TRAN,RM,SIZE,TYPE,MODEL,SERIAL | python3 -I -c '
import json, sys
for d in json.load(sys.stdin)["blockdevices"]:
    f = [d.get(k) for k in ("name", "tran", "rm", "size", "type", "model", "serial")]
    f[2] = "1" if f[2] in (True, "1", 1) else "0"
    print("|".join(str(x or "-").replace("|", "/").replace("\n", " ").strip() for x in f))'
}
while IFS='|' read -r NAME TRAN RM SIZE TYPE MODEL SERIAL; do
    [[ $TYPE == disk && $SIZE =~ ^[0-9]+$ ]] || continue
    verdict=ok
    if [[ $RM != 1 && $TRAN != usb ]]; then verdict="no: not removable/USB"
    elif (( SIZE > max_bytes )); then verdict="no: larger than 64 GB"
    elif (( SIZE < image_bytes )); then verdict="no: smaller than image"
    elif lsblk -n -o MOUNTPOINT "/dev/$NAME" | grep -qE '^(/|/boot.*|/home|/usr|/var|\[SWAP\])$'; then verdict="no: holds a system mount"
    fi
    [[ $verdict == ok ]] && eligible[$NAME]="$SIZE|$MODEL|$SERIAL"
    printf '%-8s %-5s %-3s %14s  %-24.24s %-24.24s %s\n' "$NAME" "$TRAN" "$RM" "$SIZE" "$MODEL" "$SERIAL" "$verdict"
done < <(list_disks)

(( ${#eligible[@]} > 0 )) || die "no eligible device. Is the board in U-Boot 'ums 0 mmc 0' with the USB OTG cable connected?"
echo
echo "Eligible: ${!eligible[*]}"
echo "The U-Boot UMS disk usually shows model 'UMS disk 0' or similar (vendor Linux)."
read -r -p "Type the device name to OVERWRITE (e.g. sdb), anything else aborts: " answer
[[ -n $answer && -n ${eligible[$answer]:-} ]] || die "aborted (no matching eligible device)"
dev=/dev/$answer

# Desktop automount may have mounted the card's partitions: unmount those only.
while read -r part mnt; do
    [[ -n $mnt ]] || continue
    echo "unmounting /dev/$part ($mnt)"
    umount -A "/dev/$part"
done < <(lsblk -n -l -o NAME,MOUNTPOINT "$dev")

# Re-check identity immediately before writing.
now=$(list_disks | awk -F'|' -v n="$answer" '$1 == n {print $4 "|" $6 "|" $7}')
[[ $now == "${eligible[$answer]}" ]] || die "device $dev changed since listing (${eligible[$answer]} -> ${now:-gone})"

echo
echo "== Writing $image -> $dev"
dd if="$image" of="$dev" bs=4M conv=fsync status=progress
sync
echo "== Verifying read-back"
readback=$(head -c "$image_bytes" "$dev" | sha256sum | awk '{print $1}')
echo "read-back: $readback"
[[ $readback == "$expected" ]] || die "READ-BACK MISMATCH: do not boot this card; re-run"
echo
echo "Done. In the U-Boot console press Ctrl-C to stop UMS, then type: reset"
