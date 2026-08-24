# Partitions Inside the Super Image (OnePlus 9 Pro)

The `super` partition is a container for the device's **dynamic (logical) partitions**. These cannot be flashed from bootloader mode — fastboot must be running in **fastbootd** mode to flash them.

## Dynamic Partitions

| Partition | Purpose |
|-----------|---------|
| `system` | Android OS |
| `vendor` | Vendor HALs / device-specific blobs |
| `system_ext` | System extensions |
| `product` | OEM product layer |
| `odm` | ODM (original design manufacturer) customizations |

## Related Docs

- [Repairing Modem After a New Variant Flash](repair-modem-after-variant-flash.md) — cross-variant `super.img` flashes and their fallout
- [Image Files From the Extracted OPS Package](image-files-by-purpose.md) — which files to flash for a ROM-only update vs full firmware
