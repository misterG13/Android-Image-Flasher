# Image Files From the Extracted OPS Package (OnePlus 9 Pro)

Extracting an `.ops` file (MSM Download Tool package) yields ~75 files with unfamiliar names. Only a subset is meant for fastboot flashing with this script; everything else is MSM-only or device-written data. This doc maps every file to its purpose.

The groups below answer the common questions: *which files for a ROM update*, *which files repair cellular/WiFi/Bluetooth*, and *which files make up a full OTA-style firmware update*.

## OPS Filename → Flasher Filename

Names differ between the OPS extract (`ops-extract/`) and this repo's `flash-files/`:

| OPS extract | flash-files | What it is |
|-------------|-------------|------------|
| `xbl.elf` | `xbl.img` | Primary bootloader (XBL) |
| `xbl_config.elf` | `xbl_config.img` | XBL configuration |
| `abl.elf` | `abl.img` | Android Boot Loader (hosts fastboot) |
| `aop.mbn` | `aop.img` | Always On Processor firmware |
| `BTFM.bin` | `bluetooth.img` | Bluetooth firmware |
| `cpucp.elf` | `cpucp.img` | CPU control processor firmware |
| `devcfg.mbn` | `devcfg.img` | Device configuration |
| `dspso.bin` | `dsp.img` | Audio/sensor signal processor (ADSP/CDSP) |
| `featenabler.mbn` | `featenabler.img` | OnePlus feature-enabler TrustZone app |
| `hypvm.mbn` | `hyp.img` | Qualcomm hypervisor |
| `imagefv.elf` | `imagefv.img` | UEFI firmware volume |
| `km41.mbn` | `keymaster.img` | Keymaster TEE app |
| `multi_image.mbn` | `multiimgoem.img` | OEM TrustZone app bundle |
| `NON-HLOS.bin` | `modem.img` | Modem/baseband (MPSS) |
| `oem_stanvbk.bin` | `oplusstanvbk.img` | OEM NVRAM backup → flashed to `oplusstanvbk_a/b` (verified in the package's `settings.xml`; no partition named `oem_stanvbk` is ever written by it) |
| `oplus_sec.mbn` | `oplus_sec.img` | OnePlus security TrustZone app |
| `qupv3fw.elf` | `qupfw.img` | QUP peripheral firmware (USB, I2C, SPI) |
| `qweslicstore.bin` | `qweslicstore.img` | Qualcomm licensing store |
| `shrm.elf` | `shrm.img` | Shared memory firmware |
| `tz.mbn` | `tz.img` | TrustZone OS |
| `uefi_sec.mbn` | `uefisecapp.img` | UEFI secure app (TrustZone app) |
| `super.img` | `system.img`, `system_ext.img`, `vendor.img`, `product.img`, `odm.img` | Dynamic-partition container, split before flashing |

Unchanged names: `boot.img`, `dtbo.img`, `splash.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`, `vendor_boot.img`, `vm-bootsys.img`.

## Group 1 — ROM / OS Update Only

The minimum set for updating just the OS (custom-ROM style), no firmware touched:

| Files | Notes |
|-------|-------|
| `system`, `system_ext`, `vendor`, `product`, `odm` | Dynamic partitions — **fastbootd required** |
| `vbmeta*` | Flash first with disable-verity flags (the script does this automatically) |

## Group 2 — Radio / Connectivity Repair (Cellular, WiFi, Bluetooth)

Single-partition repairs; no full re-flash needed. All are safe in bootloader mode except where noted.

| Symptom | Flash |
|---------|-------|
| No cellular signal, missing bands (e.g. after cross-variant flash) | `modem.img` + `oplusstanvbk.img` |
| Bluetooth won't pair / missing | `bluetooth.img` |
| WiFi flaky or missing | `vendor.img` (WLAN firmware lives inside vendor) + `modem.img` — fastbootd |
| Audio crackle, mic/DSP issues | `dsp.img` |

## Group 3 — Full Firmware Update (OTA-Equivalent)

Everything OxygenOS full OTAs ship: Group 1 + Group 2 plus the bootloader/firmware chain:

`xbl`, `xbl_config`, `abl`, `aop`, `boot`, `cpucp`, `devcfg`, `dtbo`, `featenabler`, `hyp`, `imagefv`, `keymaster`, `multiimgoem`, `oplus_sec`, `qupfw`, `qweslicstore`, `shrm`, `splash`, `tz`, `uefisecapp`, `vendor_boot`, `vm-bootsys`

## Group 4 — Full Restore / Unbrick

All files from Groups 1–3 combined (i.e. everything in `flash-files/`). Covers any state where the bootloader still runs. For damage below the bootloader (corrupted GPT, wiped persist), use the MSM Download Tool in EDL mode — see [MSM Download Tool Version Mismatch](msm-version-mismatch.md).

## Never Flash Casually (MSM-Only / Device-Written)

These appear in the OPS extract but must **not** be pushed via fastboot:

| File | Why not |
|------|---------|
| `persist.img` | Sensor/fingerprint calibration + Widevine L1 keys — written to both `persist` and `persist_bkp`; reflashing on another device permanently breaks them |
| `userdata.img` | Wipes all user data |
| `metadata.img` | File-based encryption metadata |
| `frp.bin` | Factory Reset Protection lockout state |
| `misc.bin` | Bootloader commands/recovery flags |
| `devinfo.bin` | Bootloader unlock state |
| `param.bin` | Device parameters |
| `carrier.img` | Carrier configuration (64 MB) |
| `spunvm.bin` | Secure per-device NV data |
| `engineering_cdt.img`, `ocdt.bin`, `apdp.mbn` | Engineering/debug board data |
| `modemst1`, `modemst2`, `oplusdycnvbk` | Runtime modem NV partitions — no image exists in the package at all; the device writes these itself (IMEI-adjacent data) |
| `gpt_main*.bin`, `gpt_backup*.bin` | Encrypted partition tables — MSM-only |
| `prog_firehose_*.elf`, `provision_*.xml`, `DRIVER.ISO` | EDL programmers/provisioning configs for the MSM tool itself |
| `*.log.bin` (android_log, kernel_log16M, hyp_log, ...) | Debug logs, never flashed |

## Related Docs

- [Partitions Inside the Super Image](super-image-partitions.md) — what Group 1's dynamic partitions contain
- [Repairing Modem After a New Variant Flash](repair-modem-after-variant-flash.md) — the cross-variant scenario behind Group 2
- [MSM Download Tool Version Mismatch](msm-version-mismatch.md) — when to fall back to EDL flashing (Group 4)

## Sources

- `settings.xml` inside the local OPS extract (partition labels, source-file mapping, sizes)
- Byte-level comparison of `oem_stanvbk.bin` vs `oplusstanvbk.img` (identical `OEMNVBK` header; content matches modulo zero-padding)
