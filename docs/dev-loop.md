# Development loop

All development (builds, agents, board access) happens **inside the Dev
Container** `astro-clock-dev`. The container reads the board's serial console,
runs commands on the board over serial or SSH, and deploys files without
reflashing. Only the steps marked **(host, sudo)** or **(physical)** need the user.

```text
 iPad ──Tailscale/SSH──▶ Debian host (dan, 100.119.43.19)
                           │  docker exec
                           ▼
                 Dev Container astro-clock-dev (unprivileged, bridge network)
                   │ /dev/host/serial/by-id/*STLink*      │ 172.17.0.x ─NAT─▶ 10.42.0.1
                   ▼ (ST-LINK VCP, USB)                    ▼ (enp0s31f6, NM shared)
                 STM32MP157F-DK2  ttySTM0 115200 8N1      eth0 10.42.0.2 (fixed lease)
                                                          dropbear, key-only, root
```

## Scripts

Run from `/workspaces/astro-clock` in the container (`scripts/board/*`) or from
the repository on the host (`scripts/host/*`).

| Script | Where | What |
| --- | --- | --- |
| `scripts/board/console [-d\|-k]` | container | Start/attach tmux session `board` running picocom 115200 8N1; log in `logs/serial/<UTC>.log`, `current.log` points to it. Detach `C-b d`; quit picocom `C-a C-x`. Reconnects after USB replug. |
| `scripts/board/serial-run [-c] "<cmd>" [timeout]` | container | Run one command over serial between unique markers; prints only its output, exits with its status (124 timeout). Logs in as root if needed. Fallback when SSH is down. |
| `scripts/board/serial-tail [-f] [n]` | container | Last *n* lines of the current serial log. |
| `scripts/board/ssh-setup` | container | Once: dev key `~/.ssh/astro_board_ed25519` (persistent volume), `external/board/stm32mp157f-dk2/local/authorized_keys` (git-ignored), `Host board` in `~/.ssh/config`. |
| `scripts/board/ssh [args]` | container | SSH to `root@10.42.0.2`. |
| `scripts/board/run "<cmd>"` | container | One command over SSH, exits with its status. |
| `scripts/board/deploy <local> <remote>` | container | rsync over SSH (scp `-O` fallback). |
| `scripts/board/health` | container | uname, uptime, date (EET/EEST), NTP, RTC, df, ip a, dmesg rtc/eth/remoteproc, PASS/FAIL summary. |
| `scripts/host/dev [console\|claude\|rc\|up\|rebuild\|<cmd>]` | host | `docker exec` into the container (starts it if needed). |
| `scripts/host/check-board-net.sh` | host | Link, NM connection, lease, ping, SSH port, container→board ping. |
| `scripts/host/fetch-image` | host | Copy `sdcard.img` + `.sha256` from the output volume to `.build/artifacts/`. |
| `scripts/host/setup-board-net.sh <MAC>` | **host, sudo** | NM shared connection on `enp0s31f6`, fixed lease, forwarding rules. |
| `scripts/host/flash-sd.sh [image]` | **host, sudo** | Write the image to the SD card over U-Boot UMS, with safety checks. |

Only the `board-operator` agent uses `scripts/board/*`. See `.claude/agents/`.

## One-time setup

1. **Board network (host, sudo).** The board MAC was read over serial:
   `10:e7:7a:e5:5f:b0`.

   ```sh
   sudo scripts/host/setup-board-net.sh 10:e7:7a:e5:5f:b0
   scripts/host/check-board-net.sh
   ```

   Why the forwarding helper exists: Docker on this host already runs with
   `"ip-forward-no-drop": true`, and the board reaches the internet through NM's
   NAT. But NetworkManager's own `table ip nm-shared-enp0s31f6`, chain
   `filter_forward`, ends with `oifname "enp0s31f6" reject`, so NEW connections
   from the container (`docker0`) to the board are rejected (seen as ICMP
   "port unreachable" / ECONNREFUSED). `/usr/local/sbin/astro-board-fw` inserts
   a tagged `iifname docker0 oifname enp0s31f6 ip daddr 10.42.0.0/24 accept`
   ahead of it, and adds `DOCKER-USER` accepts for board traffic. NM recreates its
   table on every activation, so an NM dispatcher hook
   (`/etc/NetworkManager/dispatcher.d/90-astro-board-fw`) and a systemd unit
   (`astro-board-fw.service`, after boot and Docker restarts) re-apply it.
   The host uses the iptables-nft backend; nothing flushes existing rulesets.

2. **Serial access.** The container needs no host group change: `developer`
   is in `dialout` (gid 20) inside the image and the device cgroup rule allows
   char major 166 (ttyACM). Add `dan` to `dialout` only if you also want
   picocom directly on the host: `sudo usermod -aG dialout dan` (re-login).

3. **Container agents.** Log in once; the login persists in the
   `astro-clock-claude-*` volume. Codex keeps its login in the container home,
   which is lost when the container is recreated: run `codex` and sign in again.

   ```sh
   scripts/host/dev claude auth login   # one-time claude.ai login (needed for Remote Control too)
   ```

## Flashing the SD card over U-Boot UMS (physical + host, sudo)

Cables on the DK2 (MB1272; confirm on the silkscreen):
- **CN6** USB Type-C: 5 V power input. Keep it connected.
- **CN11** micro-USB: ST-LINK. Serial console to the host. Keep it connected.
- **CN7** USB Type-C: USB OTG. Connect it to a host USB port for UMS.
- Boot switches **SW1**: BOOT0 = ON, BOOT2 = ON (SD card). This is unchanged from normal boot.

Steps:

1. In the container, build and on the host copy the image out:
   `scripts/host/dev make build` then `scripts/host/fetch-image`.
2. Attach the console: `scripts/host/dev console`.
3. Reboot the board (`reboot` at the shell, or the reset button) and press a key
   when U-Boot prints `Hit any key to stop autoboot`.
4. At the `STM32MP>` prompt: `ums 0 mmc 0`. The SD card appears on the host
   as a USB disk, usually with model `UMS disk 0`.
5. In a second host terminal:
   `sudo scripts/host/flash-sd.sh` (defaults to `.build/artifacts/astroclock-sdcard-latest.img`).
   It verifies the checksum, lists disks, offers only removable/USB disks of at most
   64 GB, asks you to type the device name, then writes and verifies by reading it back.
6. Back in the console: `Ctrl-C` stops UMS; then `reset` boots the new image.
7. In the container: `scripts/board/serial-tail 80`, then `scripts/board/health`.

Flashing replaces the root filesystem, including the dropbear host key. The
first SSH connection after a reflash then fails the host-key check. Run
`ssh-keygen -f ~/.ssh/known_hosts.board -R 10.42.0.2` in the container once.

## Reaching the board from the iPad

- **Through the container (no extra keys):** `ssh dan@<host>` then
  `~/astro-clock/scripts/host/dev scripts/board/ssh`, or the serial console with
  `~/astro-clock/scripts/host/dev console`.
- **Direct SSH with ProxyJump:** add the iPad's public key to
  `external/board/stm32mp157f-dk2/local/authorized_keys`. Rebuild and flash, or
  append it on the running board:
  `scripts/board/run 'cat >> /root/.ssh/authorized_keys' < ipad.pub`. Then from the iPad:

  ```sh
  ssh -J dan@100.119.43.19 root@10.42.0.2
  ```

  With an SSH config on the iPad:

  ```text
  Host astroclock
      HostName 10.42.0.2
      User root
      ProxyJump dan@100.119.43.19
  ```

- **Tailscale subnet route (documented, not enabled):**
  `sudo tailscale set --advertise-routes=10.42.0.0/24`. Approve the route in the
  Tailscale admin console and turn on "use Tailscale subnets" on the iPad.
  NM's shared table would also reject `tailscale0 → enp0s31f6`. That needs a second
  accept rule in `astro-board-fw` (`iifname "tailscale0"`), which is not installed.
  Prefer ProxyJump.

## Daily workflow (from the iPad)

```sh
ssh dan@100.119.43.19
cd ~/astro-clock
scripts/host/dev console                 # serial console (C-b d to detach)
scripts/host/dev claude                  # Claude Code with project agents
scripts/host/dev rc                      # or: Remote Control, then use the Claude app on the iPad
scripts/host/dev scripts/board/health    # board PASS/FAIL summary
scripts/host/dev                         # plain shell in the container
```

## Time on the board

- `/etc/localtime` → `Europe/Bucharest` (tzdata). `date` shows EET/EEST.
- BusyBox `ntpd` (`/etc/init.d/S48ntpd`, peers `0-2.pool.ntp.org`). Its `-S`
  hook `/usr/libexec/astroclock/ntpd-event` writes the STM32 RTC (`hwclock -w -u`)
  after sync and publishes `/run/ntp.status`.
- `/etc/init.d/S05hwclock`: `hwclock -s -u` at boot, `hwclock -w -u` at
  shutdown. No RTC backup battery is assumed. After power loss the RTC restarts at
  2000-01-01, and the boot script then restores the last known good time
  (`/var/lib/astroclock/last-time`), so the clock never goes back to 2000.
  NTP corrects it once the network is up.
