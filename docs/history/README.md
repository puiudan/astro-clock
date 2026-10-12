# Historical reports

These reports date from the STM32MP157C-DK2 era (2026-09-18 to 2026-09-28),
before the project moved to the STM32MP157F-DK2 compatibility target. They are
kept unchanged, apart from a header note, as a record of how the platform was
built and validated.

| File | Content |
| --- | --- |
| `build-report.md` | First full Buildroot build of the C-DK2 image (2026-09-22, sdcard.img `2fa1f128…`) |
| `build-validation.md` | Commands and results behind that build |
| `boot-fix-validation.md` | Offline validation of the I2C/PMIC boot fix (hardware unverified at the time) |

The current boot fix and hardware result are in
[`../boot-fix-2026-09-26.md`](../boot-fix-2026-09-26.md).
