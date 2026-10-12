> **Historical (C-DK2 era, 2026-09).** Kept as a record and not updated since. Checksums, paths and
> board names may not match the current STM32MP157F-DK2 tree. See the top-level README.md for the current state.

**PASS — offline validation. Hardware boot and UMS operation remain unverified.** No rebuild, flashing, source/generated-file edits, commits or pushes were performed during validation.

The fixed root cause was DRM removal disabling its implicit I2C selection. This excluded the STM32 I2C controller and STPMIC1 drivers, leaving SDMMC waiting for buck4. The fragment now explicitly enables I2C.

**PASS — effective kernel configuration and source provenance**

| Option | Effective value | Source |
|---|---|---|
| `CONFIG_I2C` | `y` | External minimal fragment |
| `CONFIG_I2C_STM32F7` | `y` | Pinned upstream Linux configuration |
| `CONFIG_MFD_STPMIC1` | `y` | Same |
| `CONFIG_REGULATOR` | `y` | Same |
| `CONFIG_REGULATOR_STPMIC1` | `y` | Same |
| `CONFIG_MMC` | `y` | Same |
| `CONFIG_MMC_ARMMMCI` | `y` | Same |
| `CONFIG_MMC_STM32_SDMMC` | `y` | Pinned Linux Kconfig `default y` |
| `CONFIG_EXT4_FS` | `y` | Pinned upstream Linux configuration |

None relies solely on a manual generated `.config` change. SDMMC is enabled through its pinned default rather than an explicit fragment entry. The kernel’s embedded configuration matches the effective `.config` exactly.

**PASS with limitations — board selection**

- Linux selects the external `stm32mp157f-dk2.dtb`.
- U-Boot uses `stm32mp15_trusted`, with `DEFAULT_DEVICE_TREE`, `OF_LIST` and `DEVICE_TREE` selecting `stm32mp157f-dk2`.
- TF-A selects `stm32mp157f-dk2.dtb`, SP_MIN and the F-DK2 firmware configuration. FIP payload comparisons passed.

Remaining C-DK2 references:

| References | Assessment |
|---|---|
| Upstream Linux config and existing fragment directory | Intentional reuse |
| C-DK2 DTS/DTSI includes | Intentional compatibility implementation |
| U-Boot secondary C-DK2 compatible | Intentional; preserves pinned DK2 board setup |
| README baseline and historical reports | Historical references |
| Old C-DK2 image files | Unused incremental-build leftovers |
| `AGENTS.md` and `.codex/agents/` board descriptions | Stale documentation; incorrect for the physical board |

This remains a **local compatibility target**, not native F-DK2 support. **650 MHz is retained**; 800 MHz operation is not established.

**PASS — SD image**

Path: `/var/cache/astro-clock/output/images/sdcard.img`  
Size: **128,380,928 bytes**  
SHA-256:

```text
6606104e4ab1d492431212a4f0928eac55d165a6a40c98d7f74e1419f8f892f1
```

GPT uses 512-byte sectors; primary/backup header and partition-array checksums passed.

| Partition | Name | Start–end LBA |
|---|---|---|
| 1 | fsbl1 | 34–442 |
| 2 | fsbl2 | 443–851 |
| 3 | fip | 852–4947 |
| 4 | rootfs | 4948–250707 |

Partition 4 matches `rootfs.ext4` and passes read-only filesystem checking. Its `/boot/extlinux/extlinux.conf` contains:

```text
label stm32mp157f-dk2-buildroot
  kernel /boot/zImage
  devicetree /boot/stm32mp157f-dk2.dtb
  append console=ttySTM0,115200 root=/dev/mmcblk0p4 rootwait
```

Both referenced files exist and match the generated artifacts byte-for-byte. The DTB identifies STM32MP157F-DK2.

**PASS — U-Boot UMS compiled in**

These are all `y`:

```text
CONFIG_CMD_USB_MASS_STORAGE
CONFIG_USB_GADGET
CONFIG_DM_USB_GADGET
CONFIG_USB_GADGET_DWC2_OTG
CONFIG_USB_GADGET_DOWNLOAD
CONFIG_USB_FUNCTION_MASS_STORAGE
```

The U-Boot USB OTG DT node is enabled. Actual USB enumeration and SD export require hardware testing.

**PASS — logs and static checks**

No fatal errors were found in the final configure/Linux/U-Boot/TF-A/image logs. Nonfatal diagnostics concern jobserver fallback, deprecated `pkg_resources`, missing TF-A bookkeeping snapshots and optional `/usr/libexec`. No boot-blocking build diagnostic was identified.

These checks passed:

```sh
python3 /tmp/astro-verify.py
bash -n scripts/buildroot
sh -n .devcontainer/init-cache.sh
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
shellcheck scripts/buildroot .devcontainer/init-cache.sh
./scripts/buildroot status
git diff --check
git diff --cached --check
git -C third_party/buildroot status --short
```

The documented kernel milestone assertions also passed. Buildroot remains clean and correctly pinned.

**PASS — change scope**

Reviewed the complete tracked diff, empty staged diff and all untracked files. Intended commit candidates are:

- `README.md`
- `external/configs/astro_clock_defconfig`
- `external/board/stm32mp157c-dk2/linux-minimal.fragment`
- All five source/configuration files under `external/board/stm32mp157f-dk2/`
- `docs/boot-fix-2026-09-26.md`

The pre-existing `docs/build-report.md` and `docs/build-validation.md` describe the older build; keep them separate from this fix pending documentation review. No unrelated code modifications were found.

Generated images, configurations, caches, downloads and build logs under `/var/cache/astro-clock/`, plus `/tmp/astro-*`, must remain outside version control. None appears in the proposed source changes.

**Hardware test still required:** boot this exact image on the STM32MP157F-DK2 MB1272 Var4.0 Rev.C-03, capture serial at 115200 8N1, confirm PMIC/SDMMC probing, `/dev/mmcblk0p4` root mount and login. Separately confirm U-Boot UMS enumerates and exports the intended SD card before attempting any write.

**Final conclusion: PASS for offline validation; hardware boot and UMS operation remain unverified.**
