> **Historical (C-DK2 era, 2026-09).** Kept as a record and not updated since. Checksums, paths and
> board names may not match the current STM32MP157F-DK2 tree. See the top-level README.md for the current state.

# STM32MP157C-DK2 build validation — 2026-09-22

## Source and environment

- Buildroot 2025.02.18 LTS, submodule commit
  `d030e36bbc9669230c015be971b14b6e062cfdde`, annotated tag object
  `b611e07ef088c70c1e21f77c30872bce97a1f1c2`.
- Release archive SHA-256 documented before configuration/build in README:
  `e38ad1df6ea0479fff6419a87a64535d02131674d463be154a763ef725b55321`.
- Dev Container: Debian 12, `/.dockerenv` present, uid/gid 1000 (`developer`),
  expected ASTRO cache paths set. Container has 12 CPUs, about 30 GiB RAM,
  and 401 GiB free on the output filesystem. No host packages installed.
- Output: `/var/cache/astro-clock/output`; downloads:
  `/var/cache/astro-clock/downloads`; ccache: `/var/cache/astro-clock/ccache`.
- Defconfig: `external/configs/astro_clock_defconfig`, derived from pinned
  upstream `configs/stm32mp157c_dk2_defconfig`. Differences: ccache,
  ttySTM0/115200 getty, eth0 DHCP, external Linux fragment disabling graphics,
  audio, wireless and touchscreen. No application, GUI or SSH server added.
- Upstream board files, patch/hash directory and post-image script reused.
  Source versions remain Linux 6.9.8, TF-A v2.9 and U-Boot 2024.07.
  Buildroot LTS status does not establish maintenance of those board versions.

## Commands and results

All shell commands ran from `/workspaces/astro-clock` as `developer`.
The execution sandbox failed with a bwrap namespace error before executing
initial inspection commands. Retrying with sandbox escalation still ran as
uid 1000; it did not run Buildroot as root.

Repository/environment inspection (read-only):

```sh
pwd
id
git status --short
git diff
git diff --cached
cat AGENTS.md README.md .codex/config.toml
rg --files .codex .devcontainer external scripts
cat .codex/agents/buildroot-engineer.toml test.md external/Config.in external/external.desc external/external.mk
cat scripts/buildroot Makefile external/configs/astro_clock_defconfig .devcontainer/Dockerfile
cat .devcontainer/devcontainer.json
git submodule status
git -C third_party/buildroot status --short
git -C third_party/buildroot rev-parse HEAD
git ls-files --stage third_party/buildroot
git -C third_party/buildroot cat-file -p refs/tags/2025.02.18
cat /etc/os-release
test -f /.dockerenv
printenv ASTRO_OUTPUT_DIR ASTRO_DOWNLOAD_DIR ASTRO_CCACHE_DIR
findmnt -T /var/cache/astro-clock/output -o TARGET,FSTYPE,OPTIONS
df -h /var/cache/astro-clock/output
getconf _NPROCESSORS_ONLN
cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max
cat /proc/meminfo | head -n 3
./scripts/buildroot status
diff -u third_party/buildroot/configs/stm32mp157c_dk2_defconfig external/configs/astro_clock_defconfig
```

Initial worktree had only untracked `test.md`; the agents did not modify it.
It was absent when work resumed on 2026-09-22. Submodule
was clean and its gitlink and tag matched the documented pin. Initial defconfig
comparison differed only by ccache (expected `diff` exit 1). A read attempt used
`.codex/agents/buildroot_engineer.toml` instead of the hyphenated filename and
failed; corrected immediately. An optional `free -h` diagnostic failed because
procps is absent; `/proc/meminfo` supplied the information. This is not a missing
Buildroot dependency.

Configuration and checks:

```sh
make configure
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache dependencies
make savedefconfig
shellcheck scripts/buildroot .devcontainer/init-cache.sh
bash -n scripts/buildroot
sh -n .devcontainer/init-cache.sh
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
git diff --check
git diff --cached --check
git -C third_party/buildroot status --short
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache source > /var/cache/astro-clock/output/source.log 2>&1
```

`make configure` passed first against the original defconfig and again after
minimality changes, creating `/var/cache/astro-clock/output/.config`.
Dependency preflight and all static checks passed; `savedefconfig` passed.
No Dev Container changes or rebuild were needed. The prior source download log
ends with successful fakeroot checksum verification and make completion; its
complete log is outside the worktree at the path above.

## Continued build validation (2026-09-21)

The continuation preserved the existing README, defconfig, Linux fragment,
this report and unrelated `test.md` changes. UID 1000 (`developer`) and
`/.dockerenv` were verified again. The submodule remains clean; its gitlink,
HEAD and peeled `2025.02.18` tag all match the documented commit.

`make configure` and the explicit `dependencies` command above passed again.
ShellCheck, shell syntax, Dev Container JSON and staged/unstaged whitespace
checks passed. No missing host dependency or need to rebuild the container
has been found.

While image-generation authorization was unresolved, the following command
compiled all selected packages and prepared the target directory. Inspection
of the pinned Buildroot Makefile confirmed that `target-finalize` does not
depend on root filesystem or post-image targets. No post-build script is
configured.

```sh
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache -j12 target-finalize > /var/cache/astro-clock/output/component-build.log 2>&1
```

Component compilation started here and completed on 2026-09-22 as recorded
below; image generation followed in the full-build step.
Resolved package inspection confirms BusyBox, glibc, init/network scripts,
kernel and boot chain plus build-host tools; no application or GUI package.

A build reliability fix makes `scripts/buildroot build` pass
`BR2_JLEVEL=$jobs` as well as `-j$jobs`. Previously the documented `ASTRO_JOBS`
limit did not constrain recursive package compilation: the component log
showed `-j13` despite top-level `-j12`. The pinned Buildroot
`package/Makefile.in` computes `PARALLEL_JOBS` from `BR2_JLEVEL`.

```sh
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache -s printvars VARS=PACKAGES
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache BR2_JLEVEL=4 -s printvars 'VARS=BR2_JLEVEL PARALLEL_JOBS'
shellcheck scripts/buildroot .devcontainer/init-cache.sh && bash -n scripts/buildroot && git diff --check
```

The real printvars check returned `BR2_JLEVEL=4` and `PARALLEL_JOBS=4`.
A temporary mock `make` confirmed `ASTRO_JOBS=4` forwards both arguments and
absolute output/external paths, and rejects `ASTRO_JOBS=0` before invoking
make. This check did not invoke firmware or filesystem image generation.
Post-change ShellCheck, Bash syntax and whitespace checks passed.

## Resumed compilation (2026-09-22)

After the session interruption, a read-only `/proc` process inspection found
no running make or compiler processes. The shell was still uid 1000 inside
the Dev Container. Existing source changes were inspected and preserved.
The component log ended during host util-linux compilation, with no recorded
fatal build failure. The build resumed from its existing output directory,
appending to the log and applying the corrected package parallelism limit:

```sh
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache BR2_JLEVEL=12 -j12 target-finalize >> /var/cache/astro-clock/output/component-build.log 2>&1
```

The resumed command completed successfully with exit status 0. It built the
selected packages, Linux, TF-A and U-Boot, finalized the host/target directories,
and copied the upstream board overlay. No build failure required a source fix.
This target stops before root filesystem and SD image generation.
The subsequent full build is recorded below.

Resolved `/var/cache/astro-clock/output/build/linux-6.9.8/.config` assertions
passed: `CONFIG_SERIAL_STM32`, `CONFIG_SERIAL_STM32_CONSOLE`,
`CONFIG_STMMAC_ETH`, `CONFIG_DWMAC_STM32`, `CONFIG_MMC`, `CONFIG_MMC_ARMMMCI`
and `CONFIG_EXT4_FS` are all `y`. `DRM`, `FB`, `SOUND`, `WIRELESS`, `WLAN`,
`BT` and `INPUT_TOUCHSCREEN` are disabled. `BACKLIGHT_LCD_SUPPORT` is absent
because its graphics parents are disabled. These are configuration checks,
not proof of board operation.

The exact read-only kernel check was:

```sh
python3 - <<'PY_CHECK'
from pathlib import Path
p = Path('/var/cache/astro-clock/output/build/linux-6.9.8/.config')
lines = p.read_text().splitlines()
disabled = ['DRM', 'FB', 'BACKLIGHT_LCD_SUPPORT', 'SOUND', 'WIRELESS', 'WLAN', 'BT', 'INPUT_TOUCHSCREEN']
enabled = ['SERIAL_STM32', 'SERIAL_STM32_CONSOLE', 'STMMAC_ETH', 'DWMAC_STM32', 'MMC', 'MMC_ARMMMCI', 'EXT4_FS']
for key in disabled + enabled:
    matches = [l for l in lines if l.startswith('CONFIG_' + key + '=') or l == '# CONFIG_' + key + ' is not set']
    print(key, ':', matches or ['absent'])
    assert ('CONFIG_' + key + '=y' in lines) if key in enabled else not any(l.startswith('CONFIG_' + key + '=') for l in lines), key
print('Kernel milestone assertions passed')
PY_CHECK
```

## Full build and images

The user explicitly authorized regular-file `mkfs.ext4` and genimage operations.
The parent agent then ran the documented build wrapper as uid 1000, preserving
the existing output directory and limiting package compilation to 12 jobs:

```sh
ASTRO_JOBS=12 make build > /var/cache/astro-clock/output/full-build.log 2>&1
```

The complete build passed with exit status 0. Root filesystem generation and
genimage completed successfully. No block device was accessed, and no board
flashing, host package installation or container rebuild was performed.

The following artifacts were generated successfully under
`/var/cache/astro-clock/output/images/` (sizes are bytes):

| File | Size |
| --- | ---: |
| `fip.bin` | 1,190,534 |
| `stm32mp157c-dk2.dtb` | 49,705 |
| `tf-a-stm32mp157c-dk2.stm32` | 209,261 |
| `u-boot-nodtb.bin` | 1,039,556 |
| `u-boot.dtb` | 100,280 |
| `zImage` | 4,544,144 |
| `rootfs.ext2` | 125,829,120 |
| `rootfs.ext4` (symlink to `rootfs.ext2`; referent size) | 125,829,120 |
| `sdcard.img` | 128,380,928 |

Installed configuration has a ttySTM0 getty at 115200 baud and eth0 DHCP.
The upstream extlinux entry uses `root=/dev/mmcblk0p4 rootwait`.

Final image SHA-256 values:

```text
47c39a669f4113bf189f64ae62ac0e72aae0a31f8dc14a3d283b27e2dd7de4ac  rootfs.ext4
2fa1f12830ac763772c997587e25e123d7ab23410f85afad5ba32b430fec0dc5  sdcard.img
```

The parent ran read-only filesystem validation (`e2fsck -fn`, exit 0),
verified primary and backup GPT CRCs, and checked embedded partition payloads
against the generated source artifacts. All passed. The reviewer independently
confirmed the full-build log, image sizes and hashes. These checks establish
image consistency, not a successful hardware boot.

```sh
/var/cache/astro-clock/output/host/sbin/e2fsck -fn /var/cache/astro-clock/output/images/rootfs.ext4
sha256sum /var/cache/astro-clock/output/images/rootfs.ext4 /var/cache/astro-clock/output/images/sdcard.img
stat -Lc '%n %s bytes %F' /var/cache/astro-clock/output/images/rootfs.ext4 /var/cache/astro-clock/output/images/sdcard.img
tail -n 30 /var/cache/astro-clock/output/full-build.log
```

Final read-only artifact/runtime checks and source cleanliness checks:

```sh
stat -c '%n %s bytes' /var/cache/astro-clock/output/images/fip.bin /var/cache/astro-clock/output/images/stm32mp157c-dk2.dtb /var/cache/astro-clock/output/images/tf-a-stm32mp157c-dk2.stm32 /var/cache/astro-clock/output/images/u-boot-nodtb.bin /var/cache/astro-clock/output/images/u-boot.dtb /var/cache/astro-clock/output/images/zImage
rg -n 'ttySTM0|eth0|dhcp|root=' /var/cache/astro-clock/output/target/etc/inittab /var/cache/astro-clock/output/target/etc/network/interfaces /var/cache/astro-clock/output/target/boot/extlinux/extlinux.conf
rg -n -B 8 -A 8 'no include path in which to search for stdc-predef.h|libext2fs.dvi|install-doc-libs.*Error' /var/cache/astro-clock/output/component-build.log
git -C third_party/buildroot status --short
git diff --check
git diff --cached --check
tail -n 5 /var/cache/astro-clock/output/component-build.log
```

All checks passed; the submodule remains clean. Build diagnostics include an
initial-GCC macro-list probe reporting missing `stdc-predef.h` before target
libc headers exist; compilation continued and the final toolchain built the
kernel and boot chain successfully. Host e2fsprogs documentation generation
reported missing makeinfo/texi2dvi and explicitly ignored its documentation
errors. Documentation tools are intentionally omitted from the Dev Container;
they are not required to build this firmware. Other upstream warnings include
compiler diagnostics, obsolete Autoconf macros, ignored configure options,
BusyBox's obsolete `ASH_SLEEP` config symbol, and jobserver messages (some
package submakes use serial execution). These did not prevent component build
success. No undocumented packages were installed and no container rebuild
was required.

No hardware verification has occurred. Linux fragment resolution passed as
recorded above; actual serial/Ethernet behavior remains unverified until board testing.

## Changed files and review

- `external/configs/astro_clock_defconfig`
- `external/board/stm32mp157c-dk2/linux-minimal.fragment` (new)
- `README.md`
- `scripts/buildroot`
- `docs/build-validation.md` (new)

The component-stage read-only reviewer found no actionable issues. The reviewer checked the
pin and vendor cleanliness, external configuration, wrapper parallelism fix,
resolved Linux/runtime settings, build log, artifact sizes and this report.
Final read-only review of all five changed files after full-image validation
completed with no actionable findings. The reviewer independently verified the
clean source pin, successful genimage log, both image sizes and SHA-256 values,
and whitespace checks. An independent clean rebuild/reproducibility check and
hardware boot/networking remain unverified. No astronomical or time-zone logic
exists in this milestone, so domain tests do not apply. Nothing committed or pushed.

## Proposed hardware steps (not executed)

Review the generated SD image size/checksum and obtain explicit approval
for writing that specific image to a positively identified removable SD card.
Identify the card by model, serial and capacity and ensure it is not a host system
disk; prepare the write command only after that identification and approval.
Set the DK2 boot switches for SD according to the board documentation. Connect
the ST-LINK USB serial interface, open its port at 115200 baud, 8N1, no flow
control, and capture a complete power-on log. Confirm TF-A, U-Boot, kernel,
rootfs mount and ttySTM0 login. On an isolated DHCP Ethernet network, check eth0
link, assigned address, route and reachability. Retain the log as the first
hardware evidence; build success alone does not prove boot or networking.
