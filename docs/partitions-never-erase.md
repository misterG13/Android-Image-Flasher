# Partitions That Must Never Be Erased (OnePlus 9 Pro / LE2127)

Partitions that hold **per-device unique data**: keys, calibration, NV storage,
board/factory data, and user content. Erasing or flashing these with a foreign
image permanently breaks the phone (IMEI-region NV, Widevine L1, sensors,
fingerprint, encryption keys) or bricks it. Only EDL/MSM ("Group 4") tools are
allowed to rewrite them — and even then only with the same-device's own
backups / the correct factory package.

This is the denylist the script's erase features enforce (see
`lib/erase.sh` → `PROTECTED_PARTITIONS`). All entries are matched
case-insensitively with any `_a`/`_b` suffix stripped, so protection holds even
if some device firmware ever names a copy per-slot (e.g. `oplusstanvbk_a`).

## Table of Contents

- [Critical — never touch](#critical-never-touch)
- [High — never touch](#high-never-touch)
- [Notes](#notes)
- [Related](#related)

## Critical — never touch

| Partition | Why |
|-----------|-----|
| `persist` | Sensor/fingerprint calibration, panel data, Widevine L1, WiFi/BT — factory-written; not in any OTA |
| `persist_bkp` | Live backup of `persist` |
| `modemst1`, `modemst2` | Runtime modem NV (IMEI-adjacent); the device writes these itself; no firmware image exists |
| `fsg`, `fsc` | Modem FSG/FSC configuration/calibration NV |
| `oplusdycnvbk` | OnePlus dynamic NVRAM backup (modem NV) |
| `oplusstanvbk` | OnePlus static NVRAM baseline (per-device; has slot copy) |
| `devinfo` | Bootloader state: active slot, unlock status, rollback; killing it bricks slot switching |
| `cdt`, `engineering_cdt` | Board Configuration Data Table (factory chipset config) |
| `storsec` | Storage security / SSG key material |
| `secdata` | Secure data (anti-rollback counters area) |
| `spunvm` | Secure per-device NV data |
| `ddr` | DDR memory training/calibration for this specific chip |

## High — never touch

| Partition | Why |
|-----------|-----|
| `userdata` | Entire user storage |
| `metadata` | File-based-encryption keys for `userdata`; wiping = permanent data loss |
| `frp` | Factory Reset Protection state |
| `misc` | Bootloader message / recovery flags |
| `param` | Device parameters (region/serial-adjacent) |
| `keystore` | Android keystore blob (per-device keys) |
| `dip` | Device Identification Parameters |
| `dinfo` | Device information NV |
| `ocdt` | OEM board/config data |
| `uefivarstore` | UEFI variables incl. boot-chain state; wiping can kill slot handoff |
| `carrier` | Carrier configuration (device provisioning) |
| `limits`, `limits-cdsp` | Thermal/power limits for this SKU |
| `apdp`, `apdp_full` | Platform debug/security policy |
| `ssd` | Storage-secure record (small, keyed) |
| `sda`–`sdf` | Storage subsystem records/unknown content — keep, not worth the risk |
| `qmcs` | Unsigned/uncertain content — keep |
| `rtice` | Real-time integrity check / attestation data |
| `tzsc` | TrustZone storage config |

## Notes

- All of the above are **unslotted** (`has-slot: no`), so the script's normal
  erase flows (which only target `_a`/`_b` slot-firmware partitions) never
  select them anyway — the denylist is defense-in-depth.
- Slotted firmware partitions (`xbl*`, `abl`, `aop`, `hyp`, `tz`, `modem`,
  `boot`, `dtbo`, `vendor_boot`, `keymaster`, `devcfg`, `bluetooth`, `dsp`,
  `cpucp`, `qupfw`, `qweslicstore`, `shrm`, `splash`, `uefisecapp`, `imagefv`,
  `multiimgoem`, `oplus_sec`, `featenabler`, `mdtp`, `mdtpsecapp`, `vbmeta*`,
  `vm-bootsys`) are **identical across the fleet** and re-flashable — but only
  from a same-or-newer ARB firmware image.
- Debug/log partitions (`android_log`, `kernel_log16M`, `hyp_log`, `abl_log`,
  `qsee_log`, `logdump`, `rawdump`, `modemdump`, `opluslog`, `logfs`) are
  throwaway and safe to erase, but there's no reason to.

## Related

- [Image Files From the Extracted OPS Package](image-files-by-purpose.md) —
  "Never Flash Casually" table lists the OPS-side equivalents.
- [MSM Download Tool Version Mismatch](msm-version-mismatch.md) — the only tool
  allowed to touch the Critical/High partitions.