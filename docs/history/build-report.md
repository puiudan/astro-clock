> **Historical (C-DK2 era, 2026-09).** Kept as a record and not updated since. Checksums, paths and
> board names may not match the current STM32MP157F-DK2 tree. See the top-level README.md for the current state.

# STM32MP157C-DK2 Buildroot Build Report

## 1. Executive summary

The milestone establishes a minimal STM32MP157C-DK2 platform with a serial
login console and Ethernet DHCP, using pinned Buildroot sources and a Dev
Container. The astronomical clock application and graphical UI are not included.

The complete build succeeded, including an ext4 root filesystem and GPT SD-card
image. The recorded build exit status is 0; current artifacts and the completion
log corroborate that result. **Successful compilation and image generation do
not prove successful booting on real hardware.** No board test is recorded.

Evidence below distinguishes current read-only observations from historical
results recorded in [build-validation.md](build-validation.md). This reporting
task did not rebuild, clean, reconfigure, flash, commit, or push.

## 2. Build environment

| Item | Evidence / value |
| --- | --- |
| Reporting observation time | 2026-09-23T18:12:55Z (UTC) |
| Build completion date | 2026-09-22, per the validation record; exact completion time: Not recorded |
| Configured base image | `debian:bookworm-20260824@sha256:6ebd97fa83deb272194a2cf015b3d26a4d538e9ad3a7a79d544c8af5b0a01443` in `.devcontainer/Dockerfile`; running image digest not independently inspected |
| Container | Debian GNU/Linux 12 (bookworm); `/.dockerenv` present |
| User | `developer`, UID/GID 1000:1000; non-root |
| Container architecture | `amd64` from dpkg; `x86_64` from uname |
| Host architecture | Shared kernel reports `x86_64`; physical host architecture: Unknown (not independently inspected) |
| Package sources | Dockerfile pins Debian and Debian-security snapshots to `20260910T000000Z` |
| Parallelism | Final build requested 12 jobs via `ASTRO_JOBS=12`; wrapper passes `-j12` and `BR2_JLEVEL=12`. Saved `.config` has default `BR2_JLEVEL=0`, overridden by the command line |

Observed tool versions: GNU Make **4.3**, host GCC **12.2.0**
(`12.2.0-14+deb12u1`), host GNU Binutils **2.40**, Git **2.39.5**,
Python **3.11.2**, ShellCheck **0.9.0**, generated ARM GCC **13.4.0**,
Buildroot-built ccache **4.10.2**, and genimage **18**. Docker and Dev Container
CLI versions on the host: **Unknown**. No container rebuild or host package
installation was required for this milestone, according to the validation record.

## 3. Source revisions

| Source | Revision / state |
| --- | --- |
| Main repository | Branch `main`, commit `e1c1f324696c0bad674274964ee4358201867dfd` |
| Buildroot | Release **2025.02.18**, commit `d030e36bbc9669230c015be971b14b6e062cfdde` |
| Submodule | `third_party/buildroot`; initialized, clean, and matching the indexed gitlink; `git submodule status` identifies tag `2025.02.18` |
| External tree | `external/`, name `ASTRO_CLOCK`; `BR2_EXTERNAL` resolves to this tree inside the container |

The main repository had uncommitted changes during reporting: modified
`README.md`, `external/configs/astro_clock_defconfig`, and `scripts/buildroot`;
untracked `docs/build-validation.md` and
`external/board/stm32mp157c-dk2/linux-minimal.fragment`. Nothing was staged.
This report adds `docs/build-report.md`; therefore the commit alone does not
capture the complete milestone state.

The release archive SHA-256 was documented before building in `README.md`:
`e38ad1df6ea0479fff6419a87a64535d02131674d463be154a763ef725b55321`.
Archive download/signature verification was not repeated for this report.

## 4. Build configuration

- Project defconfig: `external/configs/astro_clock_defconfig`.
- Upstream baseline: `third_party/buildroot/configs/stm32mp157c_dk2_defconfig`.
  Current comparison shows only ccache, serial getty, DHCP, and the external
  Linux fragment added; upstream board overlays, hashes and image scripts are reused.
- Absolute build output: `/var/cache/astro-clock/output`.
- Downloads: `/var/cache/astro-clock/downloads`; compiler cache:
  `/var/cache/astro-clock/ccache`. The wrapper supplies these paths explicitly,
  overriding saved configuration defaults.
- Target: ARM Cortex-A7; Buildroot internal toolchain, GCC 13.4.0 and
  Binutils 2.43.1. C library: glibc source version
  `2.41-161-g5dd252cf1d113644b3679f5a158e9ef20217865e` from the pinned package recipe.
- Linux **6.9.8**, board DT `st/stm32mp157c-dk2`; U-Boot **2024.07**, board
  defconfig `stm32mp15_trusted`; TF-A **v2.9**, platform `stm32mp1`, FIP enabled.
- BusyBox **1.37.0** provides init and basic userspace. Getty is installed on
  `ttySTM0` at **115200 baud**; `eth0` is configured for DHCP. Neither Dropbear
  nor OpenSSH is enabled. The documented development serial root login has no password.
- Root filesystem: **ext4**, label `rootfs`, configured size `120M`, no tar
  image. `rootfs.ext4` links to the ext4-formatted file named `rootfs.ext2`.
  The GPT layout is `fsbl1`, `fsbl2`, `fip`, `rootfs`; extlinux specifies
  `root=/dev/mmcblk0p4 rootwait`.
- Resolved kernel settings retain STM32 UART/console, STMMAC/DWMAC Ethernet,
  MMC/SD and ext4. The external fragment disables DRM, framebuffer, sound,
  wireless, Bluetooth and touchscreen support. LCD output is outside this milestone.

## 5. Repository structure created

The existing scaffold contains:

| Paths | Role |
| --- | --- |
| `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json` | Pinned development image, non-root user, persistent output/download/ccache volumes |
| `.devcontainer/init-cache.sh`, `.devcontainer/.dockerignore` | Fixed cache-ownership helper; restricted image-build context |
| `external/external.desc`, `external/Config.in`, `external/external.mk` | Named `BR2_EXTERNAL` tree and future package integration; no application package yet |
| `external/configs/astro_clock_defconfig`, `external/board/stm32mp157c-dk2/linux-minimal.fragment` | Board configuration and minimal kernel overrides |
| `scripts/buildroot`, `Makefile` | `help`, `status`, `configure`, `menuconfig`, `savedefconfig`, `build`; enforce source pin/cleanliness, absolute output paths and non-root builds |
| `.gitmodules`, `third_party/buildroot` gitlink | Pinned upstream source registration |
| `.gitignore` | Ignores `.build/`, default Buildroot output/download locations, `.env` files and other listed local artifacts |

The scaffold files above are already tracked, except the new fragment. The
current milestone change set is `README.md`, `scripts/buildroot`,
`external/configs/astro_clock_defconfig`, the new Linux fragment, and
`docs/build-validation.md`. This task adds only `docs/build-report.md`.

## 6. Commands executed

The significant historical commands below are recorded in `docs/build-validation.md`;
they were **not rerun** while preparing this report. Absolute container paths
are retained here for exact historical commands and out-of-tree state;
repository file references elsewhere are relative.

```sh
make configure
make savedefconfig
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache dependencies
shellcheck scripts/buildroot .devcontainer/init-cache.sh
bash -n scripts/buildroot
sh -n .devcontainer/init-cache.sh
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache -j12 target-finalize > /var/cache/astro-clock/output/component-build.log 2>&1
make -C /workspaces/astro-clock/third_party/buildroot O=/var/cache/astro-clock/output BR2_EXTERNAL=/workspaces/astro-clock/external BR2_DL_DIR=/var/cache/astro-clock/downloads BR2_CCACHE_DIR=/var/cache/astro-clock/ccache BR2_JLEVEL=12 -j12 target-finalize >> /var/cache/astro-clock/output/component-build.log 2>&1
ASTRO_JOBS=12 make build > /var/cache/astro-clock/output/full-build.log 2>&1
/var/cache/astro-clock/output/host/sbin/e2fsck -fn /var/cache/astro-clock/output/images/rootfs.ext4
```

Reporting used read-only Git status/diff/revision/submodule inspection, selected
configuration reads, tool version queries, `git check-ignore -v`, bounded
`tail`/`rg` log excerpts, and Python file metadata/SHA-256 collection. The full
build log was not printed or analyzed in its entirety. Exact original build
start/end timestamps and a timing command: **Not recorded**.

## 7. Build result

**PASS.** The historical record reports exit 0 for resumed component compilation
and the subsequent complete build. The component log ends with target preparation
and overlay installation; `full-build.log` ends with rootfs installation,
genimage writing GPT/protective MBR metadata and Make leaving normally. All
reported images remain present with matching previously recorded SD/rootfs hashes.

Total build duration: **Unknown**. Compilation was interrupted and resumed;
log/file timestamps cannot establish active build duration. This was completion
using existing output, not an independent clean reproducibility build.

The recorded fix makes `ASTRO_JOBS` propagate to `BR2_JLEVEL` for recursive
package builds. No fatal package-build failure requiring a source patch is
recorded. Image generation initially waited for explicit approval, later granted.

Observed diagnostics in `component-build.log` include:

- Line 13693: obsolete Autoconf `AC_HELP_STRING` macro warning.
- Line 22190: initial GCC `stdc-predef.h` include-path error; the validation
  record identifies this as a probe before libc headers existed. Later builds completed.
- Line 25825: jobserver unavailable, falling back to `-j1`.
- Line 57124: nonexistent BusyBox `ASH_SLEEP` configuration symbol warning.
- Lines 60576 and 63428–63429: missing `texi2dvi` and explicitly ignored
  optional documentation error 127.

These excerpts did not prevent completion. No board-operation evidence or
independent clean rebuild is available. The prior final review recorded no
actionable findings. Buildroot's release status does not establish ongoing
maintenance of the separately pinned Linux/bootloader versions.

## 8. Generated artifacts

Paths in this table are relative to **`/var/cache/astro-clock/output/`**;
sizes are bytes and hashes were calculated during reporting. Only observed
image-directory entries are listed. **`images/sdcard.img` is the complete
image expected to be written to the SD card.**

| Artifact path | Purpose | Size (bytes) | SHA-256 |
| --- | --- | ---: | --- |
| `images/fip.bin` | TF-A firmware package | 1,190,534 | `c469640058390fcf4f1e80ef1cbee3b887a1ab74ff054f438089c7238981dd2f` |
| `images/rootfs.ext2` | ext4 root filesystem, despite filename suffix | 125,829,120 | `47c39a669f4113bf189f64ae62ac0e72aae0a31f8dc14a3d283b27e2dd7de4ac` |
| `images/rootfs.ext4` | Symlink to `rootfs.ext2`; size/hash of referent | 125,829,120 | `47c39a669f4113bf189f64ae62ac0e72aae0a31f8dc14a3d283b27e2dd7de4ac` |
| `images/sdcard.img` | Complete GPT SD-card image | 128,380,928 | `2fa1f12830ac763772c997587e25e123d7ab23410f85afad5ba32b430fec0dc5` |
| `images/stm32mp157c-dk2.dtb` | Linux board device tree | 49,705 | `89b7749d8789b7e5e638fbe2e61a7c7b7236a38d2e8b4a82046acd76017d9bed` |
| `images/tf-a-stm32mp157c-dk2.stm32` | First-stage TF-A image | 209,261 | `93e0f52081c3c5a1ff1da66c16a1ffd830272a0ba31729fddd2fe24c288dea81` |
| `images/u-boot-nodtb.bin` | U-Boot executable without appended device tree | 1,039,556 | `ec52c09ba1a328ab75592aff02ecb64defbfc38b217f5642395255ada5a98c57` |
| `images/u-boot.dtb` | U-Boot device tree | 100,280 | `c2cfc8e01bded3516cabd9dc6208a2298075a0cacd33932e82f5ecbb91ee01df` |
| `images/zImage` | Compressed Linux kernel | 4,544,144 | `9657fd7be403e33a78253002833aa63bcc62f8e623fe9702ba833f3ee9ca1c13` |

## 9. Reproduction procedure

The following is a procedure, not commands executed for this report. Prerequisites:
Docker and the Dev Container CLI already installed, authorized Docker access,
network access for pinned dependencies, and the reviewed uncommitted milestone
files preserved or committed. From the repository root on the host:

```sh
git submodule update --init --recursive
devcontainer up --workspace-folder "$PWD"
devcontainer exec --workspace-folder "$PWD" bash
```

Alternatively, use VS Code's **Dev Containers: Reopen in Container**. Host
administrator access, if required, must follow the local Docker policy; no
private host path is assumed here. Inside the non-root container shell:

```sh
./scripts/buildroot status
make configure
ASTRO_JOBS=12 make build
```

For an incremental rebuild with the existing configuration, run only:

```sh
ASTRO_JOBS=12 make build
```

`make configure` resets the configuration to the project defconfig. Optional
configuration editing uses `make menuconfig` followed by `make savedefconfig`.
Images appear in `/var/cache/astro-clock/output/images/`. The wrapper supplies
absolute `O=`, `BR2_EXTERNAL=`, download and ccache arguments. Full builds create
regular image files; writing physical storage is a separate operation.

## 10. Git versioning policy

Commit reviewed source/configuration only: `.devcontainer/`, `external/`,
`scripts/buildroot`, `Makefile`, `.gitignore`, `.gitmodules`, the Buildroot
**gitlink**, project instructions and documentation including this report.
Do not commit the submodule's copied source contents into the parent repository.

Build output, downloaded archives, compiler caches, generated images and logs
must remain untracked, as must credentials, access tokens and private keys.
Current generated state is outside the worktree. Ignore checks confirmed
`.build/output/`, `.build/downloads/`, `.build/ccache/`, `.env`, and the
submodule's default `output/` and `dl/` paths. These rules are scoped: they do
not guarantee that an image, log or secret copied elsewhere will be ignored.
Inspect staged content before any future commit. No commit or push was performed.

## 11. Verification status

Historical results below are attributed to `docs/build-validation.md`; they were
not rerun unless explicitly described as current observations.

| Check | Status | Supporting evidence |
| --- | --- | --- |
| Dev Container configuration | PASS | JSON parses now; Debian 12, container marker and non-root UID observed; prior dependency/static checks recorded |
| Buildroot configuration | PASS | Recorded `make configure` success; current effective configuration and upstream defconfig comparison agree with scoped changes |
| Source pin | PASS | Clean submodule HEAD and gitlink match documented commit |
| Complete compilation | PASS | Recorded exit 0; completion excerpts and current artifacts corroborate |
| Generated image presence | PASS | Nine directory entries inventoried, including one symlink; sizes and SHA-256 recorded above |
| Filesystem/GPT consistency | PASS | Prior read-only e2fsck exit 0, GPT CRC and embedded-payload checks recorded; image hashes unchanged |
| Git ignore behavior | PASS | Current `git check-ignore -v` matches scoped output/cache/download and `.env` rules |
| Static serial/Ethernet settings | PASS | Current target inittab has ttySTM0/115200; interfaces has eth0 DHCP; required kernel drivers enabled |
| Boot on STM32MP157C-DK2 | NOT TESTED | No direct board boot evidence |
| Serial console on hardware | NOT TESTED | Configuration only; no captured serial session |
| Ethernet connectivity | NOT TESTED | Configuration only; no link/DHCP/reachability evidence |
| LCD output | NOT TESTED | No board test; display drivers disabled for this milestone |
| Independent clean reproducibility build | NOT TESTED | Existing output was reused after interruption |

## 12. Next steps

1. Review this report and the complete Git diff, including untracked files.
2. After explicit authorization, commit the reproducible configuration and
   documentation, inspecting staged content and the submodule pin first.
3. Verify the SD image checksum and identify the intended removable card by
   model, serial and capacity. `/dev/sdX` is a **placeholder requiring manual
   verification**, never an assumed destination. Obtain separate writing approval
   and write `images/sdcard.img`; no destructive flashing command is provided here.
4. Set the board for SD boot and capture the complete serial log at 115200 baud,
   8N1, no flow control. Check TF-A, U-Boot, kernel, rootfs mount and login.
5. On an isolated development network, verify Ethernet link, DHCP address,
   routing and reachability; preserve results alongside the boot log.
6. Verify LCD behavior in a separately scoped display milestone after enabling
   appropriate display support. This minimal image is not configured to provide
   graphical LCD output.
