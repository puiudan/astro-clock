# shellcheck shell=bash
# Shared helpers for scripts/board/*. Source this file; do not execute it.
# These scripts run inside the Dev Container as the developer user.

board_project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
board_log_dir="$board_project_root/logs/serial"
board_session=${BOARD_TMUX_SESSION:-board}

board_die() {
    printf '%s: %s\n' "$(basename -- "$0")" "$*" >&2
    exit 1
}

# Print the ST-LINK virtual COM port node. The host's /dev is bind-mounted
# read-only at /dev/host, and the by-id link survives USB re-enumeration
# (ttyACM0 -> ttyACM1). BOARD_SERIAL overrides the lookup.
board_serial_device() {
    local candidates=() link
    if [[ -n ${BOARD_SERIAL:-} ]]; then
        printf '%s\n' "$BOARD_SERIAL"
        return
    fi
    shopt -s nullglob nocaseglob
    for link in /dev/host/serial/by-id/*st*link*; do
        candidates+=("$link")
    done
    shopt -u nullglob nocaseglob
    case ${#candidates[@]} in
        0) board_die "no ST-LINK serial port under /dev/host/serial/by-id (board unplugged or powered off?)" ;;
        1) ;;
        *) board_die "several ST-LINK ports found; set BOARD_SERIAL to one of: ${candidates[*]}" ;;
    esac
    # The udev link is relative (../../ttyACMn), so it resolves inside /dev/host.
    printf '%s\n' "${candidates[0]}"
}

board_current_log() {
    local log="$board_log_dir/current.log"
    [[ -e $log ]] || board_die "no serial log yet; start the console with scripts/board/console -d"
    realpath -- "$log"
}

board_session_running() {
    tmux has-session -t "=$board_session" 2>/dev/null
}
