# Fixing "Invalid sparse file format at header magic" (OnePlus 9 Pro)

## The Problem

`fastboot flash` rejects some partition images with:

```
Invalid sparse file format at header magic
```

The image is a valid **raw** image, but fastboot expects an Android **sparse** image. Converting the raw image to a sparse one fixes the failure.

## The Fix

### 1. Install the conversion tools (one-time)

```bash
sudo apt install android-sdk-libsparse-utils
```

### 2. Convert the raw image to sparse

```bash
img2simg odm.img odm_sparse.img
```

### 3. Rename so the flasher picks up the right file

| File | What it is | Rename to |
|------|------------|-----------|
| `odm.img` | Raw image | `odm_raw.img` |
| `odm_sparse.img` | Android flashable (sparse) image | `odm.img` |

## Notes

- Complete these steps for **all** flash failures showing this error, not just `odm`.
- Keep the raw image around as `*_raw.img` in case you need to re-convert it.
