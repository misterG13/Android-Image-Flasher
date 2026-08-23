# MSM Download Tool Version Mismatch (OnePlus 9 Pro)

## The Problem

After using the India MSM tool, the T-Mobile MSM tool shows a version mismatch and refuses to flash.

## Why It Happens

| Step | What Changed |
|------|--------------|
| 1. Used India MSM tool | Device firmware state → India region |
| 2. Tried T-Mobile MSM tool | Tool expects T-Mobile firmware state |
| 3. Version mismatch | Tool detects device has India firmware, not T-Mobile |

The MSM Download Tool reads the device's **persist partition** and **firmware version metadata** to verify compatibility before flashing. When it sees India firmware on a device it expects to have T-Mobile firmware, it rejects the flash to prevent bricking.

## Technical Details

Each MSM package contains:
- Signed firmware images for specific regions
- Version tracking in persist/modem partitions
- Anti-Rollback (ARB) checks

Example version strings:
- India: `LE2121_11_F_XX`
- T-Mobile: `LE2127_11_F_XX`

## How to Fix

### Convert the MSM Tool (Advanced)
Modify the T-Mobile MSM tool's `settings.xml` to accept India firmware:
1. Edit the tool's configuration
2. Re-encrypt the `.ops` file
3. Use a tool like `oppo_decrypt`

Reference: DroidWin MSM Region Conversion Guide
https://droidwin.com/how-to-convert-msm-download-tool-to-a-different-region

## Key Takeaway

The MSM tool's version check is a **safety feature**, not a bug. Cross-flashing regions via MSM can damage:
- Modem/cellular functionality
- Fingerprint sensor calibration
- Device-specific persist data

## OnePlus 9 Pro Model Variants

| Model | Region | MSM Package |
|-------|--------|-------------|
| LE2120 | China | China MSM |
| LE2121 | India | India MSM |
| LE2123 | EU | EU MSM |
| LE2125 | Global/NA | Global MSM |
| LE2127 | US T-Mobile | T-Mobile MSM |

## Sources

- XDA Forums: OnePlus 9 Pro MSM and Fastboot ROM threads
- DroidWin: MSM region conversion guide
- iTechGuides: MSM Download Tool reference
