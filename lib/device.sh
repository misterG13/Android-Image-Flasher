# shellcheck shell=bash
# Target device identity, populated once per action by acquire_target_device:
#   TARGET_SERIAL - USB serial of the confirmed device ('' when unpinned)
#   DEVICE_MODEL  - human-readable model name ('' when unknown)
#   DEVICE_SOURCE - transport the target was found on ('adb' or 'fastboot')
TARGET_SERIAL=""
DEVICE_MODEL=""
DEVICE_SOURCE=""

# Count devices in the given mode ('adb' or 'fastboot')
count_devices() {
	local mode="$1"
	case "$mode" in
	adb)
		adb_read devices | awk '$2 == "device" { c++ } END { print c+0 }'
		;;
	fastboot)
		fb_read devices | awk 'NF { c++ } END { print c+0 }'
		;;
	*)
		echo "[ERROR] count_devices: unknown mode '$mode' (expected 'adb' or 'fastboot')." >&2
		return 2
		;;
	esac
}

# Print the USB serials of connected healthy devices, one per line
list_device_serials() {
	local mode="$1"
	if [ "$mode" = "adb" ]; then
		adb_read devices | awk '$2 == "device" { print $1 }'
	else
		fb_read devices | awk 'NF { print $1 }'
	fi
}

# Verify the attached fastboot devices match the confirmed target: abort with
# the standard errors when more than one device is attached, or when the only
# attached device is not the pinned one.
#   $1 = newline-separated fastboot serials
verify_pinned_fastboot() {
	local serials="$1" count serial

	count=$(printf '%s\n' "$serials" | awk 'NF { c++ } END { print c+0 }')

	if [ "$count" -gt 1 ]; then
		echo "[ERROR] More than one device detected in fastboot mode ($count devices). Disconnect all but the confirmed device (${TARGET_SERIAL:-none}) and retry:" >&2
		while IFS= read -r serial; do
			[ -n "$serial" ] && echo "  - $serial" >&2
		done <<<"$serials"
		return 1
	fi

	if [ "$count" -eq 1 ] && [ -n "${TARGET_SERIAL:-}" ] && [ "$serials" != "$TARGET_SERIAL" ]; then
		echo "[ERROR] Different device detected in fastboot mode: expected $TARGET_SERIAL, found $serials. Aborting." >&2
		return 1
	fi

	return 0
}

# Warn when an attached adb device is unusable (unauthorized/offline/etc.), so
# its absence from the healthy count is explained, e.g. a pending RSA prompt.
warn_unready_adb_devices() {
	local serial state
	while read -r serial state; do
		echo "[WARNING] ADB device ${serial:-<unknown>} is '${state:-unknown}' and cannot be used." >&2
		if [ "${state:-}" = "unauthorized" ]; then
			echo "[WARNING] Accept the 'Allow USB debugging?' prompt on the device screen, then retry." >&2
		fi
	done < <(adb_read devices | awk 'NF >= 2 && $2 != "device" { print $1 " " $2 }')
}

# Identify the single target device for the current action. Runs ONCE per menu
# selection, before any device command; flows never re-check midway.
#   $1 = 'prompt' -> show model/serial and require confirmation (destructive actions)
#        'silent' -> pin without asking (benign actions)
# Sets TARGET_SERIAL, DEVICE_MODEL, DEVICE_SOURCE. Returns 1 when no
# unambiguous target exists or the user rejects it; callers return to the menu.
acquire_target_device() {
	local interactive="${1:-}" adb_count fb_count

	case "$interactive" in
	prompt | silent) ;;
	*)
		echo "[ERROR] acquire_target_device: usage: acquire_target_device <prompt|silent>." >&2
		return 2
		;;
	esac

	TARGET_SERIAL=""
	DEVICE_MODEL=""
	DEVICE_SOURCE=""

	adb_count=$(count_devices adb)
	fb_count=$(count_devices fastboot)

	if [ "$adb_count" -gt 1 ] || [ "$fb_count" -gt 1 ]; then
		echo "[ERROR] More than one device detected (adb: $adb_count, fastboot: $fb_count). Disconnect all but one before continuing." >&2
		return 1
	fi

	if [ "$adb_count" -eq 1 ] && [ "$fb_count" -eq 1 ]; then
		echo "[ERROR] One device detected in ADB and another in fastboot; unable to tell which is the target. Disconnect one and retry." >&2
		return 1
	fi

	if [ "$adb_count" -eq 1 ]; then
		DEVICE_SOURCE="adb"
	elif [ "$fb_count" -eq 1 ]; then
		DEVICE_SOURCE="fastboot"
	else
		warn_unready_adb_devices
		echo "[ERROR] No device detected in ADB or fastboot mode. Connect one device and retry." >&2
		return 1
	fi

	TARGET_SERIAL=$(list_device_serials "$DEVICE_SOURCE" | head -n 1)

	if [ "$DEVICE_SOURCE" = "adb" ]; then
		DEVICE_MODEL=$(adb_read shell getprop ro.product.model 2>/dev/null | LC_ALL=C tr -d '[:cntrl:]')
	else
		DEVICE_MODEL=$(fb_read getvar product 2>&1 | grep -oP 'product:\s*\K[^\r\n]+' | head -n 1 | LC_ALL=C tr -d '[:cntrl:]')
	fi

	if [ "$interactive" = "prompt" ]; then
		if [ -n "$DEVICE_MODEL" ]; then
			echo "[INFO] Target device: $DEVICE_MODEL (serial: $TARGET_SERIAL, via $DEVICE_SOURCE)"
		else
			echo "[WARNING] Could not determine the connected device's model."
			echo "[INFO] Target device serial: $TARGET_SERIAL (via $DEVICE_SOURCE)"
		fi
		if ! ask_yn "[ACTION] Is this the correct device? (y/n): "; then
			echo "[ERROR] Aborting. Connect the correct device and retry." >&2
			return 1
		fi
	elif [ -n "$DEVICE_MODEL" ]; then
		echo "[INFO] Using device: $DEVICE_MODEL (serial: $TARGET_SERIAL, via $DEVICE_SOURCE)"
	fi

	return 0
}
