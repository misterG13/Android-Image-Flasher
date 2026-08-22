# Restoring OEM State & Google Integrity (OnePlus 9 Pro)

## The Process

1. Flash stock OxygenOS firmware via fastboot (all partitions)
2. Lock the bootloader with `fastboot oem lock`
3. This wipes all data and restores factory state

## Key Requirements

| Requirement | Why |
|-------------|-----|
| Stock OxygenOS firmware | Custom ROMs will fail integrity even with locked bootloader |
| Correct model variant (LE2127) | Wrong firmware = bricked device |
| Lock bootloader after flashing | This is what actually passes SafetyNet/Play Integrity |
| Anti-Rollback (ARB) check | Flashing firmware with lower ARB than current = permanent brick |

## What Google Integrity Actually Checks

| Check | What it verifies | Passes with locked bootloader + stock ROM? |
|-------|------------------|-------------------------------------------|
| BASIC_INTEGRITY | Genuine Android build | Yes |
| DEVICE_INTEGRITY | Device matches OEM release | Yes |
| STRONG_INTEGRITY | Hardware-backed attestation | Yes (with valid keybox) |

## Confirmed Flow (XDA Forums - LE2127)

1. Flash stock OOS via fastboot ROM scripts
2. `fastboot oem lock` → wipes device
3. Orange state message disappears
4. Google Pay / banking apps work

## Risks

- ARB violation = brick (need to check current ARB index before flashing)
- Wrong firmware variant = potential brick
- Locking with non-stock firmware = bootloop
- Data loss is unavoidable

## Options Comparison

| Option | Complexity | Integrity Pass? | Data Loss? |
|--------|------------|------------------|------------|
| Flash stock OOS + lock bootloader | Medium | Yes | Full wipe |
| Flash stock OOS, leave unlocked | Low | No (BASIC only) | Full wipe |
| Use Play Integrity Fix modules | High (requires root) | Partial (no STRONG) | None |
| MSM Download Tool (EDL mode) | Low (Windows only) | Yes | Full wipe |

## Recommendation

For all three integrity levels (BASIC + DEVICE + STRONG):
1. Stock OxygenOS firmware for LE2127
2. Flash all partitions via fastboot
3. `fastboot oem lock`

## Sources

- XDA Forums: OnePlus 9 Pro Stock Fastboot ROM thread
- XDA Forums: Play Integrity Fix guides (2026)
