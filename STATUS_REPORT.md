# astro-clock — Status Report

## Display milestone — reached 2026-10-17

The LCD, backlight and touchscreen work on the real STM32MP157F-DK2 (HARDWARE),
with kernel 6.9.8 and image `c3fe9e69…`.

| Area | Result |
|---|---|
| Display | DSI-1 480x800 portrait, OTM8009A panel. Both modes work: 50 Hz (preferred) and 60 Hz, which measured 60.00 Hz. The modetest pattern is clean, and fbcon comes back afterwards. |
| Backlight | `/sys/class/backlight/5a000000.dsi.0`, 0–255. It dims visibly at each step and goes dark at 0. |
| Touch range | `/dev/input/event0` reports X 0–479, Y 0–799. The corner test gave X 9..479, Y 34..772: TL (9,44), TR (479,34), BR (456,756), BL (27,772). |
| Touch orientation | X grows to the right and Y grows downward, matching the display's pixels. Not swapped, not mirrored, no calibration needed. |
| Multi-touch | 2 slots. Two fingers were held together for 2.7 s and 2.0 s with no drop-outs, and reports come at ~100 Hz while moving. Track contacts by `ABS_MT_TRACKING_ID`, not by slot. |
| Touch chip ID | Register 0xA3 reads `0x64`, the **FT6336** family. The DT (upstream C-DK2) says `focaltech,ft6236` (FT6236 = 0x36). This is harmless: the edt-ft5x06 driver handles both as M09 ("EP0110M09"). A DT fix is optional, for accuracy only. |

Details, commands and the corrected touch history follow below.

## Update 2026-10-17 — Step 4 (display, backlight, touch) on hardware

Branch `feat/display`, on top of WIP commit `830cc75`. Labels: STATIC /
HOST-TEST / BUILD / HARDWARE. The board tests ran through the board-operator
agent over SSH (`scripts/board/run`, `scripts/board/deploy`). The user
watched the LCD and touched the screen.

**Board state:**
- Image `sdcard.img` sha256 `c3fe9e69…`, flashed and verified by read-back (user).
- Linux 6.9.8 `#3` built 2026-10-15. Cmdline: `console=ttySTM0,115200 root=/dev/mmcblk0p4 rootwait`.
- The reflash changed the SSH host key. The old entry was removed from `~/.ssh/known_hosts.board`, as dev-loop.md describes.

**Devices found:**
| Item | Value |
|---|---|
| DRM | `/dev/dri/card0`, driver `stm` 1.0.0 |
| DSI-1 connector | id 34, connected, encoder 33 |
| HDMI-A-1 connector | id 32, disconnected |
| CRTC | id 39 |
| Primary plane | id 35. Formats: AR24 XR24 RG24 RG16 AR15 XR15 AR12 XR12 C8 |
| Overlay plane | id 40 |
| Panel modes | 480x800 at 50 Hz (#0, preferred) and at 60 Hz (#1) |
| Backlight | `/sys/class/backlight/5a000000.dsi.0`, type raw, max 255, boots at 240. The panel driver `panel-orisetech-otm8009a` sets brightness over DSI. |
| Touch | `event0` "EP0110M09", edt-ft5x06 driver at i2c-0 0x38, DT `focaltech,ft6236`. Interrupt on PF2, falling edge. X 0–479, Y 0–799, 2 touch slots. |
| Power button | `event1` `pmic_onkey` |

### Verified
| Item | Result | Label |
|---|---|---|
| fbcon on the LCD, echo to `/dev/tty0` shows on screen | user-reported before this session | HARDWARE |
| `modetest -M stm -s 34@39:480x800`, 90 s and a 5 min run stopped early | The log shows the 480x800 50 Hz mode set. The user saw a clean, full-screen pattern with no edge or colour faults. fbcon came back after both runs and no processes were left. | HARDWARE |
| 60 Hz mode: `modetest -M stm -s 34@39:480x800-60 -v` (page flipping), 60 s | The log shows the 480x800 60 Hz mode set on connector 34 / CRTC 39. Of 59 refresh-rate readings, 57 were 60.00 Hz, one 59.99 Hz and the first 60.30 Hz. The user saw a stable, clean picture, and fbcon came back. | HARDWARE |
| Stopping modetest early | Killing the `sleep` that feeds modetest's stdin makes modetest exit normally | HARDWARE |
| Backlight over the pattern: 255, 128, 64, 32, 8, 0, then 240, 10 s per step (`/tmp/bltest.sh`) | `actual_brightness` followed each value. The user saw the screen dim at each step and go dark at 0. Brightness was restored to 240. | HARDWARE |
| Same backlight steps over fbcon | Writes OK, but the change is hard to see on a mostly black console | HARDWARE |
| OTM8009A driver writes brightness over DSI and warns `mipi dsi dcs write buffer failed` on error; no such warning was in dmesg | read from the kernel source, `panel-orisetech-otm8009a.c:382` | STATIC |

### Touch — PASS (corrected; an earlier version of this report said FAIL)
- The earlier "FAIL" was a test error. The user did not touch the screen during the first capture (20:34:26–20:35:26), so zero events were expected. The interrupt count was still 0 at 20:42:03, so the register-sampling probe after it (20:40:14–20:41:14) saw no touches either. That FAIL and the causes listed for it are withdrawn.
- Corner test, `sh /tmp/corners.sh` (evtest on `event0` for 60 s, then an awk summary). It was copied with `scripts/board/deploy` and started by the user at 20:51:51 board time:

| Corner | Expected | First coordinate |
|---|---|---|
| top-left | (0, 0) | (9, 44) |
| top-right | (479, 0) | (479, 34) |
| bottom-right | (479, 799) | (456, 756) |
| bottom-left | (0, 799) | (27, 772) |

- Exactly 4 touches; X range 9..479, Y range 34..772. The axes are neither swapped nor mirrored, and match the 480x800 portrait mode. The ft6236 interrupt count went from 37 to 84. Label: HARDWARE.
- The 30–45 px gaps from the edges fit fingertip touches. No calibration is needed (INFERRED).
- Side findings (HARDWARE, reads only):
  - The controller reports chip ID `0xA3 = 0x64`, an FT6336 family part, while the DT says `focaltech,ft6236`. The edt-ft5x06 driver handles both as M09 ("EP0110M09"), so this is harmless.
  - Its registers show working mode, trigger (interrupt) mode, threshold 0x1c and rate 0x0a.
- STATIC: our F-DK2 DT includes `stm32mp157c-dk2.dts` unchanged, so the touch and panel nodes are exactly upstream C-DK2.
- Two-finger test, `sh /tmp/mt.sh` (evtest for 30 s, started by the user at 20:57:33). Label: HARDWARE.
  - Results:

    | Contact | Slot | Tracking ID | Duration | Position |
    |---|---|---|---|---|
    | 1 | 0 | 12 | 2.74 s | 267,215 |
    | 2 | 1 | 13 | 2.73 s | 223,563 |
    | 3 | 0 | 14 | 3.34 s | 258,573 → 259,570 |
    | 4 | 1 | 15 | 2.02 s | 323,274 → 306,251 |

  - Both fingers were down together twice, for 2.73 s and 2.02 s. At most 2 contacts were active at once, matching the controller limit.
  - No drop-outs: no contact ended and restarted in the same slot within 0.1 s.
  - Frames come about 9.6 ms apart (~100 Hz) while a finger moves. The input layer sends no frame when nothing changed, so a still finger produces almost no events. 15 two-finger frames over about 4.8 s of two-finger holds is therefore normal.
  - The slot a finger gets is not fixed: slot 0 was the upper finger in the first touch and the lower finger in the second. The application must track contacts by `ABS_MT_TRACKING_ID`, not by slot.
- The kernel has no `CONFIG_DEBUG_FS` and the board has no libgpiod. `devmem`, `i2cget` and `i2cdump` are present.

### Findings on the dev loop
- **The earlier "failed reflash" was a stale image:** `flash-sd.sh` wrote `.build/artifacts/astroclock-sdcard-latest.img`, which was still the old image because `scripts/host/fetch-image` had not been run. The user found the cause.
- **Fix:** `flash-sd.sh` now compares the image's sha256 with the container's `/var/cache/astro-clock/output/images/sdcard.img` through `docker exec astro-clock-dev`.
  - Same image: it prints `matches`.
  - Different image: it prints both hashes and dates, and you must type `yes` to continue.
  - Container down or file unreadable: it prints a note that the check was skipped.
  - Checked STATIC only. Claude Code's permission rules block every shell command that mentions `flash-sd`, so I could not run shellcheck on it myself. The user ran `shellcheck scripts/host/flash-sd.sh` in the container: clean, no output.
- **Auto mode blocks backlight writes:** the auto-mode classifier blocked board-operator's sysfs brightness write as "Remote Shell Writes". The user ran those writes with `! scripts/board/run …`. Either add a permission rule for such tests or keep running them by hand.
- **Long one-line commands are unreliable:** twice a long `! scripts/board/run '…'` line never reached the board, most likely broken when pasted. Deploying a small script to `/tmp` (`scripts/board/deploy`) and running `sh /tmp/<script>` worked.
- **No `timeout` on the board:** BusyBox has no `timeout` applet. Use `cmd & p=$!; sleep N; kill $p`.

### Not verified
- `flash-sd.sh` warning: shellcheck clean (STATIC), but not yet run on a real flash.

---

## Update 2026-10-15 — Step 5 (dev loop) verification

Ran inside the Dev Container (`/.dockerenv` present), branch `feat/dev-loop`.
Labels: STATIC / HOST-TEST / BUILD / HARDWARE.

**Board state (user-reported, then confirmed over SSH and serial):**
- Image sha256 `831fd86d…` flashed and verified by read-back.
- `hostname astroclock`, Linux 6.9.8, Buildroot 2025.02.18.
- eth0 10.42.0.2/24, link `1Gbps/Full`.
- EEST time, NTP synced (stratum 3), RTC offset 0 s.

### Verified
| Item | Result | Label |
|---|---|---|
| `scripts/board/console -d` | Restarted tmux `board` on the ST-LINK by-id port; log `logs/serial/20261015T174551Z.log` | HARDWARE |
| `scripts/board/serial-run` | hostname/date/ip/dropbear over serial, rc 0 | HARDWARE |
| Container → board ping | 2/2, 0.5–0.8 ms | HARDWARE |
| `scripts/board/run` | SSH works (new host key accepted into `known_hosts.board`); `run 'exit 7'` returns 7 | HARDWARE |
| `scripts/board/deploy` | rsync path: dir with subdir deployed to /tmp, sha256 equal, exec bit kept, script ran on board; cleaned up | HARDWARE |
| scp fallback (`scp -O -r -p`) | Works against dropbear (the board has rsync, so deploy itself takes the rsync path) | HARDWARE |
| `scripts/board/health` | 9/9 PASS (hostname, timezone, clock, ntp, rtc, disk, eth0, dropbear, gateway), rc 0 | HARDWARE |
| Step 5 scripts committed | `d0df407` (run, ssh, deploy, health, health.board.sh) | — |
| shellcheck on board + host scripts, `bash -n`, `git diff --check` | clean | STATIC |

### Agents — PARTIAL, needs a fix
- The four project agents (`app-developer`, `board-operator`, `buildroot-engineer`, `reviewer`) **load**: they are offered as agent types.
- **board-operator could not run `scripts/board/health`.** Its session had only Read/Grep/Glob, so Bash was missing.
- Likely cause (INFERRED, not proven): `Bash(<pattern>)` entries in the agent's `disallowedTools` remove the whole Bash tool. All four agents use this pattern, so `buildroot-engineer`, `app-developer` and `reviewer` are probably also without Bash.
- Fix applied with user approval:
  - `disallowedTools` is now whole tools only in board-operator (`Edit, Write, NotebookEdit`).
  - The line is removed in buildroot-engineer and app-developer.
  - board-operator's prompt now also says "do not run git or make".
  - The `.claude/settings.json` deny rules still block dd, mkfs, sudo, flash-sd, git push and `/dev/host` for every agent.
- **reviewer.md is not changed:** the auto-mode classifier denied the edit (self-modification). It still has the `Bash(...)` patterns, so it probably still has no Bash.
- Re-test in the same session: board-operator **still had no Bash**. Agent definitions are most likely loaded at session start, so the edit takes effect only in a new session. **Not yet re-verified** — restart Claude Code, then ask board-operator to run `scripts/board/health`.

### Fixes made today (uncommitted, for review)
1. **`check-board-net.sh` false PASS on ping** (HOST-TEST with an unreachable IP and a mocked nmcli):
   - Cause: `sh -c "ping … | tail -1"` returned tail's status, so ping always "passed". The container→board ping check had the same bug.
   - Now `bash -o pipefail`, and the host ping is pinned with `-I enp0s31f6`.
   - The neighbour check runs after the ping and only accepts REACHABLE/DELAY/PROBE/PERMANENT, not STALE leftovers.
   - New check: "no competing autoconnect profile on enp0s31f6".
2. **`setup-board-net.sh` competing "Wired connection 1"** (STATIC only; not run, needs sudo on the host):
   - `dk2-shared` gets `connection.autoconnect-priority 100`.
   - Other ethernet profiles bound to `enp0s31f6` get `autoconnect=no`. They are kept, not deleted.
   - Unbound ethernet profiles are only reported.
   - `dk2-shared` is re-activated if another profile holds the port.
   - The settings check now reads each nmcli field on its own. The old colon-joined comparison of multi-field `nmcli -g` output probably never matched, which caused a needless link bounce on every run (INFERRED: nmcli is not available in the container).
   - **The user must re-run it once:** `sudo scripts/host/setup-board-net.sh 10:e7:7a:e5:5f:b0`.
3. **Host timezone:**
   - Not checkable from the container. The container is UTC by design; the board is EEST.
   - 13:25 shown for 20:25 EEST (= 17:25 UTC) means UTC−4, probably `America/New_York`.
   - User to run `timedatectl`, then `sudo timedatectl set-timezone Europe/Bucharest`.
4. **docs/dev-loop.md** now has a Troubleshooting section:
   - No serial output and no ST logo → SW1 BOOT0/BOOT2 both ON, and the SD card seated. Today's outage was a moved boot switch.
   - Plus NM profile, forwarding and host-key entries.

### Not verified
- `setup-board-net.sh` changes on the real host (needs sudo).
- `check-board-net.sh` on the host with the real NM.
- board-operator running health (blocked, see above).
- Survival of a host reboot with "Wired connection 1" present.

---

## Original audit (2026-10-12)

Generated 2026-10-12 by Claude Code (read-only audit; nothing built, flashed, committed or modified except this file).

**Where commands ran:** Claude Code ran on the **Debian host** (`dan`, no `/.dockerenv`). The devcontainer was inspected from the host with `docker inspect` and read-only `docker exec eloquent_liskov …` (shown as **[ctr]**). Everything else is **[host]**.
**Tags:** **V** = VERIFIED (seen directly) · **I** = INFERRED (taken from docs/config, not observed)

---

## 1. Summary

- **V** Buildroot platform works: pinned Buildroot **2025.02.18 LTS** submodule (clean), an out-of-tree build in a non-root devcontainer, a `BR2_EXTERNAL` tree, and a wrapper script. The last built `sdcard.img` has SHA-256 `6606104e…f892f1`, built 2026-09-26.
- **I** Hardware boot **PASS** according to the user report in `docs/boot-fix-2026-09-26.md` (2026-09-28). TF-A, U-Boot and Linux 6.9.8 all run, the root filesystem mounts from `mmcblk0p4`, and the login prompt appears on `ttySTM0`. I did not observe the board.
- **I** **Ethernet is unverified.** On the last boot `eth0` showed `NO-CARRIER`. The host Ethernet port `enp0s31f6` is also DOWN/unavailable (**V**).
- **V** **No application code exists.** There are no app sources, no app Buildroot package, no astronomical libraries and no tests. `external/Config.in` and `external.mk` are empty placeholders.
- **V** The image is minimal: BusyBox init (SysV), glibc, DHCP on eth0, an empty root password, **no SSH**, **no NTP**, **no tzdata/timezone**, **no Python**, and **DRM/FB/touchscreen disabled**. This means **the LCD cannot display anything yet**.
- **I** F-DK2 support is a **local compatibility shim** over C-DK2 DTS files. The CPU stays at **650 MHz**, with no SCMI/OP-TEE. Linux 6.9.8, U-Boot 2024.07 and TF-A v2.9 are all older than native F-DK2 upstream support.
- **V** **The board is not currently connected to the host.** There is no `/dev/ttyACM*`, no ST USB device and no Ethernet link, and the board's IP is unknown. The devcontainer has **no device passthrough**.
- **V** The agents are Codex CLI only (`.codex/agents/`: `buildroot_engineer`, `app_developer`, `reviewer`). There are no board-access tools: no serial, SSH or flash MCP servers or scripts.
- **Biggest risks:**
  1. Display/touch bring-up on old kernel DTs with the shim F-DK2.
  2. No network path to the board, so there is no remote deploy or test loop from the iPad.
  3. No time sync, timezone data or RTC battery strategy, which matters for a clock.
  4. 3 untracked docs and stale docs in the README.

## 2. Environment

### Host [host] — V
| Item | Value |
|---|---|
| OS / kernel | Debian 13 (trixie), `6.12.107+deb13-amd64` |
| CPU / RAM / swap | i7-10850H, 12 threads / 30 GiB / 24 GiB |
| Disk `/` | 444 G total, 386 G free (9 % used) |
| Docker | 29.8.1; user `dan` **is in the `docker` group** (`docker ps` works without sudo) |
| Podman | not installed |
| Dev Container CLI | 0.89.0 (`~/.devcontainers/bin/devcontainer`) |
| sudo | needs a password (non-interactive sudo fails) |
| Host build tools | README says make/GCC/ShellCheck are absent on the host (**I**, not re-checked) |
| Agent CLIs on host | `~/.local/bin/codex`, `~/.local/bin/claude` |

### Devcontainer — V
| Item | Value |
|---|---|
| Definition | `.devcontainer/{devcontainer.json,Dockerfile,init-cache.sh,.dockerignore}` |
| Base image | `debian:bookworm-20260824@sha256:6ebd97fa…1443` |
| Apt sources | snapshot.debian.org `20260910T000000Z` |
| Packages | build-essential, git, python3, ncurses-dev, shellcheck, procps, etc. |
| Extra tooling | Codex CLI pinned to 0.155.0; the installer is checked by SHA-256 |
| User | `developer` 1000:1000, non-root; sudo is allowed only for `/usr/local/bin/init-astro-cache` (postStart) |
| Running? | **Yes**: container `eloquent_liskov`, image `vsc-astro-clock-…-uid`, created 2026-09-26, started 2026-10-12 16:47Z |
| Privileged / devices / caps | `Privileged=false`, `Devices=[]`, `CapAdd=[]`; **no USB/serial passthrough** |
| Network | `bridge` (docker0 172.17.0.0/16) |
| Mounts | bind `/home/dan/astro-clock` → `/workspaces/astro-clock`; volumes `astro-clock-{output,downloads,ccache}-0a9hv1…` → `/var/cache/astro-clock/{output,downloads,ccache}` |
| Volume sizes [ctr] | output 11 G (build 10 G, host 542 M, target 7.9 M), downloads 1.2 G, ccache 301 M |
| Codex in container | `codex-cli 0.155.0`; `~/.codex/auth.json` exists in the container (contents not read) |

### Tailscale [host] — V
- Version 1.102.4, up. Host `dan` = 100.119.43.19.
- Peers: `ipad154` (iOS, active, direct via 192.168.1.30) and `iphone-12` (iOS, idle).
- **The board is not on the tailnet.**

## 3. Repository

### Git state — V
- Remote: `origin git@github.com:puiudan/astro-clock.git` (SSH).
- Branch: `main` only; it tracks `origin/main` at `419831b` (in sync as of the last fetch; no fetch was done during this audit).
- Stash: none.
- Untracked: `docs/boot-fix-validation.md`, `docs/build-report.md`, `docs/build-validation.md`, and now `STATUS_REPORT.md`.
- Submodule: `third_party/buildroot` → `d030e36bbc96…` (tag `2025.02.18`), clean. Upstream is gitlab.com/buildroot.org.

**Commits** (all of them; there are only 6):
```
419831b 2026-09-28 Fix STM32MP157F-DK2 boot and SD/MMC initialization
165f393 2026-09-26 Install procps in dev container
782cdce 2026-09-23 Complete minimal STM32MP157C-DK2 Buildroot milestone
e1c1f32 2026-09-18 Set up pinned Buildroot platform and Codex dev container
0b5be9f 2026-09-18 Configure project-specific Codex agents
7b11462 2026-09-18 Initialize astro-clock project
```

### Tree (depth ≤3, build outputs excluded) — V
```
AGENTS.md                 agent/project rules (pinning, safety, coordination, verification)
README.md                 setup, pin, build and verification documentation (long)
Makefile                  thin wrapper: help/status/configure/menuconfig/savedefconfig/build → scripts/buildroot
scripts/buildroot         bash wrapper: checks the pin and a clean submodule, uses absolute O=/BR2_EXTERNAL/DL/ccache, refuses root
.devcontainer/            pinned dev image and cache-volume ownership helper
.codex/                   Codex config (max 3 concurrent subagents) and 3 agent definitions
external/                 BR2_EXTERNAL "ASTRO_CLOCK"
  configs/astro_clock_defconfig
  board/stm32mp157c-dk2/linux-minimal.fragment     kernel fragment (I2C on; DRM/FB/sound/wifi/BT/touch off)
  board/stm32mp157f-dk2/{firmware-dts,linux-dts,overlay,uboot.fragment}   F-DK2 compatibility shim
  Config.in, external.mk  empty package hooks (no packages)
docs/                     boot-fix report (tracked) and 3 untracked build/validation reports
third_party/buildroot     pinned submodule (vendored, unmodified)
.build/artifacts/         git-ignored host copies of SD images (C-DK2 old, F-DK2 current)
```
There is no CLAUDE.md, TODO, NOTES, `.claude/` or `.mcp.json` in the repo (**V**).

### What the docs say — V (read)
- **AGENTS.md**:
  - Buildroot must be pinned and built out-of-tree with `BR2_EXTERNAL`.
  - Destructive storage commands, push, merge and rebase all need user approval.
  - Only one write agent per subsystem at a time.
  - Domain logic must stay separate from UI/platform code, and astronomy and time-zone logic need tests.
  - Results must say whether they come from static checks, host tests, builds or hardware.
- **README.md**:
  - Current milestone: "minimal serial console and Ethernet platform; application and UI not included."
  - Documents the pin, devcontainer usage (sudo variant), the volumes and static checks.
  - Says no flashing command is provided and no SSH is enabled.
- **docs/boot-fix-2026-09-26.md** (tracked):
  - Root cause: disabling DRM dropped the implicit `CONFIG_I2C`, so no PMIC, so SDMMC never got its vmmc supply, so there was no root device.
  - Fix: `CONFIG_I2C=y`, plus the F-DK2 shim.
  - User-reported hardware PASS on 2026-09-28 (board **MB1272 Var4.0 Rev.C-03**).
  - Flashed via **U-Boot UMS**; eth0 showed NO-CARRIER.
- **docs/boot-fix-validation.md** (untracked): offline validation of the fix (GPT layout, FIP payloads, U-Boot UMS config). It flags AGENTS.md and `.codex` board names as stale; that was later fixed in 419831b.
- **docs/build-report.md, docs/build-validation.md** (untracked): the earlier C-DK2 build from 2026-09-22. Hashes are for the **old** image (`2fa1f128…`). Next steps listed there: flash, serial capture, Ethernet test, LCD milestone.
- **Open tasks stated in the docs:**
  1. Ethernet link/DHCP test.
  2. LCD/display milestone.
  3. Native F-DK2 support and 800 MHz (needs separate validation).
  4. Review the old Linux/U-Boot/TF-A versions before deployment.
  5. Authentication/SSH review.
  6. Independent clean rebuild (never done).

## 4. Linux image & boot chain

| Component | Version / config | Source |
|---|---|---|
| Build system | **Buildroot 2025.02.18 LTS**, commit `d030e36b…`, archive SHA-256 `e38ad1df…5321` | V |
| Defconfig | `external/configs/astro_clock_defconfig` (derived from upstream `stm32mp157c_dk2_defconfig`) | V |
| Toolchain | Buildroot internal, GCC 13.4.0, glibc | V [ctr .config] |
| TF-A | **v2.9**, `PLAT=stm32mp1`, `AARCH32_SP=sp_min`, `STM32MP_SDMMC=1`, DTB `stm32mp157f-dk2.dtb`, FIP; **no OP-TEE** | V (defconfig) |
| U-Boot | **2024.07**, `stm32mp15_trusted` + `uboot.fragment` (DEFAULT_DEVICE_TREE/OF_LIST = stm32mp157f-dk2); UMS enabled | V (defconfig), I (UMS, from docs) |
| Kernel | **Linux 6.9.8**, upstream ST `linux.config` + `linux-minimal.fragment` | V |
| Boot | extlinux: `kernel /boot/zImage`, `devicetree /boot/stm32mp157f-dk2.dtb`, `append console=ttySTM0,115200 root=/dev/mmcblk0p4 rootwait` | V |

### Device tree changes — V
- Three tiny shim files. Linux and TF-A each have a `stm32mp157f-dk2.dts`, and U-Boot has a `-u-boot.dtsi`.
- Each shim `#include`s the C-DK2 DTS and overrides only `model` and `compatible`. U-Boot also keeps a secondary `st,stm32mp157c-dk2` compatible.
- **No custom display, touchscreen, RTC, GPIO, I2C or SPI DT changes.**
- PLL1 is 650 MHz (inherited from the TF-A dkx dtsi).

### Kernel options of interest [ctr, effective .config] — V
| Option | State |
|---|---|
| DRM, FB, backlight, sound, wireless, BT, touchscreen | **disabled** by the fragment |
| I2C / I2C_STM32F7 / STPMIC1 | y |
| RTC_CLASS, RTC_DRV_STM32 | y |
| SPI_STM32, GPIO_CDEV | y |
| REMOTEPROC, STM32_RPROC, RPMSG, RPMSG_TTY | y |
| RPMSG_CHAR | not set |
| USB_GADGET (kernel) | not set (no USB-Ethernet gadget) |

### Build outputs — V
- Path [ctr]: `/var/cache/astro-clock/output/images/`, all dated 2026-09-26 16:33Z:
  - `sdcard.img` 128,380,928 B, SHA-256 `6606104e4ab1d492431212a4f0928eac55d165a6a40c98d7f74e1419f8f892f1` (matches the docs)
  - `fip.bin`
  - `tf-a-stm32mp157f-dk2.stm32`
  - `u-boot-nodtb.bin`, `u-boot.dtb`
  - `zImage` (4.6 MB)
  - `stm32mp157f-dk2.dtb`
  - `rootfs.ext2/.ext4` (120 MiB)
  - Stale C-DK2 leftovers from 2026-09-22.
- Host copies: `.build/artifacts/stm32mp157f-dk2-sdcard.img` (same hash, 2026-09-28) and `stm32mp157c-dk2-sdcard.img` (old, `2fa1f128…`, with a `.sha256` file).
- Logs [ctr]: `build-2026-09-18.log`, `source.log`, `component-build.log` (31 MB), `full-build.log`. The boot-fix logs were in `/tmp/astro-*.log` inside the container and may have been lost when it restarted (**I**).
- GPT layout (**I**, from docs): p1 fsbl1, p2 fsbl2, p3 fip, p4 rootfs (ext4).
- **Flashing:** there is no script. Per the docs, it was done by the user through U-Boot `ums` (the SD card is exposed to the host as USB mass storage, then the image is written manually). STM32CubeProgrammer is not set up (**V**: not installed/found).

### Rootfs contents [ctr target/] — V
| Area | State |
|---|---|
| Init | BusyBox init, SysV scripts: `S01seedrng S01syslogd S02klogd S02sysctl S40network S50crond` |
| Hostname / login | `buildroot`; getty on ttySTM0 115200; **root password empty** |
| Networking | ifupdown, `eth0` DHCP (wait-delay 15) |
| SSH | **none** (no dropbear/openssh) |
| Time sync | **none** (no ntp/chrony; busybox ntpd not confirmed) |
| Timezone | **no `/etc/localtime`, no zoneinfo/tzdata** |
| Graphics | **none** (no DRM in the kernel, no Weston/Qt/LVGL/SDL) |
| Runtimes | no Python; C/C++ (glibc) only |
| Coprocessor (M4) | Kernel remoteproc/RPMsg drivers built in (inherited from upstream). **No `/lib/firmware`, no M4 firmware, no project use.** Whether the M4 DT node is enabled is inherited from the upstream DK2 DTS (**I**). |

## 5. Board connectivity

| Item | Finding |
|---|---|
| Host NICs [host] **V** | `wlp0s20f3` 192.168.1.20/24 (Wi-Fi, default route via 192.168.1.1); `enp0s31f6` **DOWN / "unavailable"** (no cable); `tailscale0` 100.119.43.19; `docker0` 172.17.0.1 |
| Board network design **I** | DHCP on eth0 only. The intent seems to be plugging into a LAN/router with DHCP. There is no USB gadget networking, no NAT/bridge config, no static IP and no documented board IP. |
| Forwarding/NAT **V/–** | `ip_forward=1` (probably Docker's doing). iptables/nft are not in PATH and sudo needs a password, so **the rules could not be read**. |
| Board in ARP table **V** | No obvious board entry. Neighbors are .1 (router), .19 (unknown), .30 (iPad). |
| Serial **V** | **No `/dev/ttyACM*`, `/dev/ttyUSB*` or `/dev/serial/by-id`**, and no STMicro device in USB, so the ST-LINK is not plugged in or the board is off. `picocom` is installed (minicom/screen/tio are not). User is in `dialout`? **No**: groups are `dan cdrom floppy sudo audio dip video plugdev users netdev scanner bluetooth lpadmin docker`. |
| Serial wrappers | None in the repo. Docs say to use the ST-LINK VCP at 115200 8N1 with no flow control. |
| SSH to board | Not possible: there is no SSH server in the image and no `~/.ssh/config` host entries. |
| Ping / remote commands | **Skipped**: board IP unknown and board not connected. `uname`/`os-release`/`df`/services were **not checked on the board**. |

## 6. Agent setup

| Agent / tool | What / how | Access | Functional? |
|---|---|---|---|
| `.codex/config.toml` | `[agents] enabled=true`, `max_concurrent_threads_per_session=3` | — | V present |
| `buildroot_engineer` (`.codex/agents/buildroot-engineer.toml`) | Owns Buildroot, kernel, DT, bootloaders and image. `sandbox_mode=workspace-write` | Workspace files; **forbidden to flash, dd or mkfs** | I: used for past builds (per docs) |
| `app_developer` | Owns the app, astronomy, time handling, LVGL or DRM/KMS UI, and the app's BR package. workspace-write; needs parent approval for kernel/DT/bootloader | Workspace | I: never exercised (no app yet) |
| `reviewer` | Read-only review (pinning, secrets, tests, dangerous commands) | read-only | I: used in past validations |
| Codex CLI in container | 0.155.0. Authenticated (`auth.json` present). Container `~/.codex/config.toml` holds only a project trust entry | Container only; **no serial/USB access** | V installed |
| Codex on host | `~/.codex/config.toml`: model settings, project trust, bundled plugins (browser, computer-use, docs, …), MCP server `node_repl` (a generic Codex app tool, not board-specific) | Host | V config present |
| Claude Code on host | `~/.claude/` exists; no project `.claude/`, no MCP servers (global or project) | Host | V (this session) |
| Board-access agents | **None.** No serial, SSH, deploy or flash scripts, tools or MCP servers | — | — |

The agents follow a parent/subagent ownership model from AGENTS.md. Hardware actions are always handed back to the human.

## 7. Application status

- **V No application code exists.** There are no source files outside Buildroot infrastructure and no `external/package/*`.
- Language, framework and libraries have **not been chosen**. The only hint is `app_developer`'s description: *"LVGL or DRM/KMS user interface"*. No libnova, ERFA/SOFA, astronomy-engine, Skyfield, etc.
- Tests: none. No host test infrastructure. AGENTS.md requires tests for astronomy and timezone logic.
- Deployment: undefined. There is no package, no init script, and no SSH or scp path. Today an app could only go onto the board inside a rebuilt `sdcard.img` and be reflashed via UMS.
- Design notes: none beyond the AGENTS.md rules (keep domain logic separate from UI and platform code; test with reference values, date boundaries and DST transitions).

## 8. Gaps, inconsistencies & technical debt

1. **Display/touch not started.**
   - DRM, FB and touchscreen are explicitly disabled.
   - The DK2 panel (OTM8009A DSI) and its touch controller need DRM_STM, DSI, panel and touch drivers re-enabled, and DT verification on a 6.9 kernel with the shim.
   - Re-enabling DRM no longer pulls in I2C implicitly, but I2C is now explicit, so that particular regression won't come back.
2. **No dev loop.** There is no SSH, no known board IP, no serial passthrough to the container, and no deploy script. Every change needs a full reflash.
3. **Clock essentials are missing:**
   - No NTP client.
   - No tzdata or localtime.
   - RTC driver is present, but whether the DK2 VBAT/backup battery exists, and how the RTC is set (`hwclock`), is unaddressed.
4. **Ethernet unverified** (NO-CARRIER). The host's wired NIC is unused. The board is likely meant to plug into the router.
5. **Old boot stack:** Linux 6.9.8 (EOL), U-Boot 2024.07, TF-A v2.9, F-DK2 by shim, no OP-TEE/SCMI, 650 MHz. The README itself says these need review before deployment.
6. **Security:** root has an empty password and logs in over serial. That is acceptable for the lab, but any SSH added later must not inherit it.
7. **Stale or inconsistent docs:**
   - README says Docker socket access is denied for `dan` and to use sudo. `dan` is now in the `docker` group and `docker ps` works (**V**).
   - `external/external.desc` still says "STM32MP157C-DK2".
   - The kernel fragment lives in `board/stm32mp157c-dk2/` while everything else is under `stm32mp157f-dk2/`.
   - 3 untracked docs describe the old C-DK2 image (`2fa1f128…`). They should be committed with a "historical" note or archived.
   - README calls the 2026-09-26 boot test "pending", but the tracked boot-fix doc records PASS on 2026-09-28. The README intro is half-updated.
8. **Stale build artifacts:** C-DK2 dtb/tf-a files remain in the output and `.build/artifacts`, and an independent clean rebuild has never been done.
9. **Boot-fix logs** were written to `/tmp` inside the container and are probably lost.
10. **AGENTS.md refers to `buildroot_engineer`/`app_developer`/`reviewer`**, which are Codex agents. Claude Code has no equivalents configured, and there is no CLAUDE.md.
11. **M4 coprocessor:** the drivers are on, but there is no firmware and no plan. The same is true of `RPMSG_CHAR`.

## 9. Open questions for the developer

1. **UI stack:** LVGL on DRM/KMS (fbdev-less), or Qt/Weston, SDL, or something else? Native resolution 480×800 DSI panel with touch?
2. **Language and astronomy library:** C/C++ (e.g. libnova or astronomy-engine C) or Python (Skyfield needs numpy and ephemeris files, which is heavy)? Which quantities to show: sun/moon rise/set, phases, planets, sidereal time, equation of time?
3. **Location and timezone:** fixed coordinates/TZ baked in, configurable, or GPS?
4. **Time source:** NTP over Ethernet? Is there an RTC backup battery on your DK2? Expected offline behavior?
5. **Network plan:** board on the home LAN via the router (DHCP reservation?), or direct cable to the host's `enp0s31f6` with NAT? Should the board join Tailscale so you can reach it from the iPad?
6. **Dev access:** OK to add dropbear with key-only auth plus a set root password? Should the ST-LINK serial be passed into the devcontainer, or used from the host (`picocom`; `dan` would need `dialout`)?
7. **Platform upgrade:** stay on the 6.9/2024.07 shim for now, or move to a newer kernel and bootloaders with native F-DK2 support (800 MHz, SCMI, OP-TEE) before the display work?
8. **M4 core:** any planned use (e.g. a precise tick or stepper/LED driving)?
9. **Untracked docs:** commit, archive or delete `docs/build-report.md`, `build-validation.md` and `boot-fix-validation.md`?
10. **Which AI agent tooling is canonical:** Codex (`.codex/agents`) or Claude Code? Should agent configs exist for both?

## 10. Raw facts appendix

```text
Board:            STM32MP157F-DK2, MB1272 Var4.0 Rev.C-03 (user-reported)
Buildroot:        2025.02.18 LTS, commit d030e36bbc9669230c015be971b14b6e062cfdde
                  tag obj b611e07ef088c70c1e21f77c30872bce97a1f1c2
                  archive sha256 e38ad1df6ea0479fff6419a87a64535d02131674d463be154a763ef725b55321
Linux:            6.9.8   | U-Boot 2024.07 (stm32mp15_trusted) | TF-A v2.9 (sp_min, FIP) | GCC 13.4.0 glibc
Container image:  debian:bookworm-20260824@sha256:6ebd97fa83deb272194a2cf015b3d26a4d538e9ad3a7a79d544c8af5b0a01443
Codex CLI:        0.155.0 (container)
Current image:    [ctr] /var/cache/astro-clock/output/images/sdcard.img
                  [host] .build/artifacts/stm32mp157f-dk2-sdcard.img
                  128,380,928 B, sha256 6606104e4ab1d492431212a4f0928eac55d165a6a40c98d7f74e1419f8f892f1
Old C-DK2 image:  sha256 2fa1f12830ac763772c997587e25e123d7ab23410f85afad5ba32b430fec0dc5
Kernel cmdline:   console=ttySTM0,115200 root=/dev/mmcblk0p4 rootwait
Serial:           ST-LINK VCP, 115200 8N1, no flow control (picocom on host)
Host IPs:         wlan 192.168.1.20/24, tailscale 100.119.43.19, docker0 172.17.0.1
Container:        eloquent_liskov (bridge, unprivileged, no devices)
Volumes:          astro-clock-{output,downloads,ccache}-0a9hv1ao7at6iuqun2b8gof9vp7icn7540532tbc74ua5ai3btn2
```

**Enter devcontainer (host):**
```sh
devcontainer up   --workspace-folder /home/dan/astro-clock   # docker group now works; README's sudo variant also documented
devcontainer exec --workspace-folder /home/dan/astro-clock bash
```

**Configure/build (inside container, as developer):**
```sh
./scripts/buildroot status
make configure            # resets .config to external/configs/astro_clock_defconfig
make menuconfig && make savedefconfig
ASTRO_JOBS=12 make build  # → /var/cache/astro-clock/output/images/sdcard.img
```

**Static checks (from README):**
```sh
bash -n scripts/buildroot; sh -n .devcontainer/init-cache.sh
shellcheck scripts/buildroot .devcontainer/init-cache.sh
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
git diff --check; git -C third_party/buildroot status --short
```

**Flash:** no script exists. The documented, user-performed method is: U-Boot `ums` exposes the SD card over USB OTG, the host identifies the block device by model, serial and size, and the user writes `sdcard.img` with explicit approval. The board's boot switches must be set to SD.

**Connect:** `picocom -b 115200 /dev/ttyACM0` on the host once the ST-LINK is attached (device name **I**). Log in as `root` with no password. No SSH.

### Checks not possible in this audit / to do on the other side
- **Board itself:** off or not connected. Run `uname -a`, `cat /etc/os-release`, `uptime`, `date`, `df -h`, `ps`, `ip a` and `dmesg | grep -iE 'rtc|remoteproc|eth'` over serial.
- **Host firewall/NAT rules:** need `sudo nft list ruleset` / `sudo iptables -S`.
- **Host `dialout` membership** will be needed for serial access without sudo.
- **Inside the devcontainer:** `/tmp/astro-*.log` presence was not checked, and neither was the effective DT status of the M4 / `m4_rproc` node (decompile `stm32mp157f-dk2.dtb` with `dtc` to confirm).
