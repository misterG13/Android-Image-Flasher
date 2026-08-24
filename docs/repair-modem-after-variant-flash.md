# Repairing Modem After a New Variant Flash (OnePlus 9 Pro)

## When This Happens

Flashing `super.img` from a different model variant (e.g. LE2123/EU firmware onto a LE2127/T-Mobile device) can change the modem configuration stored on the device.

## Symptoms and Fixes

| Symptom | Fix |
|---------|-----|
| Carrier / cellular bands stop working after the flash | Reflash the `modem.img` for your own variant (e.g. LE2127) afterward |
| Fingerprint or Widevine L1 stops working | Flash `persist.img` (LE2123 in the observed case) |

## Key Takeaway

The variant mismatch lives inside the dynamic partitions (`super.img`), so repairing it is done by reflashing the affected single partition images for the correct variant — no full re-flash required.

## Related Docs

- [Image Files From the Extracted OPS Package](image-files-by-purpose.md) — full radio-repair file set and other purpose groups
