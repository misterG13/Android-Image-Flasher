# shellcheck shell=bash
# arb.sh — Anti-Rollback (ARB) detection and warning functions.
# Warning only: never blocks the user, always returns 0.

# Global ARB levels (populated by detect functions)
DEVICE_ARB=""
FIRMWARE_ARB=""

# Detect device ARB level via fastboot (best-effort).
# OnePlus may hide this; returns empty string if unavailable.
detect_device_arb() {
    DEVICE_ARB=""
    if [ "$DEVICE_SOURCE" != "fastboot" ]; then
        return 0
    fi

    # Try 'fastboot getvar anti' (works on some Qualcomm devices).
    # Wrapped in timeout so a disconnected device cannot hang the menu.
    local anti_output
    anti_output=$(timeout 10 fastboot getvar anti 2>&1)
    local anti_value
    anti_value=$(echo "$anti_output" | grep -oP 'anti:\K[0-9]+' | head -1)

    if [[ "$anti_value" =~ ^[0-9]+$ ]]; then
        DEVICE_ARB="$anti_value"
    fi
}

# Detect firmware ARB level from xbl_config* in flash-files/ (requires otaripper).
detect_firmware_arb() {
    FIRMWARE_ARB=""
    if ! command -v otaripper >/dev/null 2>&1; then
        return 0
    fi

    # Find xbl_config* files in flash-files/
    local xbl_files=()
    for file in "$FLASH_FILES"/xbl_config*; do
        if [[ -f "$file" ]]; then
            xbl_files+=("$file")
        fi
    done

    if [ ${#xbl_files[@]} -eq 0 ]; then
        return 0
    fi

    # Use first xbl_config file found
    local arb_output
    arb_output=$(otaripper arb -n "${xbl_files[0]}" 2>/dev/null)
    local arb_value
    arb_value=$(echo "$arb_output" | grep -i 'ARB Index' | grep -oP '[0-9]+' | head -1)

    if [[ "$arb_value" =~ ^[0-9]+$ ]]; then
        FIRMWARE_ARB="$arb_value"
    fi
}

# Warn if ARB levels indicate dangerous downgrade.
# Always returns 0 (non-blocking).
warn_arb_if_needed() {
    # Attempt detection
    detect_device_arb
    detect_firmware_arb

    # If we couldn't detect either level, warn about uncertainty
    if [ -z "$DEVICE_ARB" ] && [ -z "$FIRMWARE_ARB" ]; then
        echo "[WARNING] Cannot verify ARB levels. Install 'otaripper' and ensure device is in fastboot mode for ARB detection."
        echo "[WARNING] Download: https://github.com/syedinsaf/otaripper"
        echo "[WARNING] Flashing older firmware on a device with higher ARB may brick the device."
        echo "" # Spacer
        return 0
    fi

    # If we have device ARB but not firmware ARB
    if [ -n "$DEVICE_ARB" ] && [ -z "$FIRMWARE_ARB" ]; then
        echo "[INFO] Device ARB level: $DEVICE_ARB"
        echo "[WARNING] Cannot determine firmware ARB level. Install 'otaripper' and place xbl_config* in flash-files/."
        echo "[WARNING] Download: https://github.com/syedinsaf/otaripper"
        echo "[WARNING] Flashing firmware with ARB < $DEVICE_ARB may brick the device."
        echo "" # Spacer
        return 0
    fi

    # If we have firmware ARB but not device ARB
    if [ -z "$DEVICE_ARB" ] && [ -n "$FIRMWARE_ARB" ]; then
        echo "[INFO] Firmware ARB level: $FIRMWARE_ARB"
        echo "[WARNING] Cannot determine device ARB level. Device may not expose ARB via fastboot."
        echo "[WARNING] Ensure device ARB <= $FIRMWARE_ARB before flashing."
        echo "" # Spacer
        return 0
    fi

    # Both levels detected - compare
    if [ "$DEVICE_ARB" -gt "$FIRMWARE_ARB" ]; then
        echo "[WARNING] ARB VIOLATION: Device ARB ($DEVICE_ARB) > Firmware ARB ($FIRMWARE_ARB)"
        echo "[WARNING] Flashing this firmware may permanently brick the device!"
        echo "[WARNING] Consider using MSM Download Tool (EDL mode) for safe downgrade."
    else
        echo "[INFO] ARB check passed (device: $DEVICE_ARB, firmware: $FIRMWARE_ARB)"
    fi
    echo "" # Spacer
}