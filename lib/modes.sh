# shellcheck shell=bash
# Send a reboot command over the given transport ('adb' or 'fastboot').
send_reboot() {
	local tool="$1"
	shift
	if ! run_guarded "${REBOOT_CMD_TIMEOUT:-60}" "$tool" "$@"; then
		echo "[ERROR] Failed to send the reboot command via $tool." >&2
		return 1
	fi
}

# Function to wait for the confirmed device to appear in fastboot mode (with a
# timeout). After waiting, requires exactly one fastboot device AND that it is
# still the device confirmed at the menu, so a different phone swapped in
# during the reboot window is never flashed.
# shellcheck disable=SC2119,SC2120 # Optional $1 timeout defaults to 60s; all current callers use the default
wait_for_fastboot() {
	local timeout="${1:-60}" serials count

	echo "[INFO] Waiting up to ${timeout}s for the device in fastboot mode..."
	timeout "$timeout" fastboot wait-for-device 2>/dev/null

	serials=$(list_device_serials fastboot)
	count=$(printf '%s\n' "$serials" | awk 'NF { c++ } END { print c+0 }')

	if [ "$count" -eq 0 ]; then
		echo "[ERROR] Device not detected in fastboot mode after ${timeout}s." >&2
		return 1
	fi

	verify_pinned_fastboot "$serials" || return 1

	return 0
}

# Function to reboot the device into a given mode (fastbootd/bootloader/recovery)
enter_mode() {
	local mode=$1 reboot_cmd reboot_arg wait_msg_adb wait_msg_fastboot

	case "$mode" in
	fastbootd)
		reboot_cmd="reboot"
		reboot_arg="fastboot"
		wait_msg_adb="Waiting for device in fastboot..."
		wait_msg_fastboot="Waiting for device in fastbootd..."
		;;
	bootloader)
		reboot_cmd="reboot"
		reboot_arg="bootloader"
		wait_msg_adb="Waiting for device in bootloader..."
		wait_msg_fastboot="Waiting for device in bootloader..."
		;;
	recovery)
		reboot_cmd="reboot"
		reboot_arg="recovery"
		wait_msg_adb="Recovery reboot command sent. The device will boot into recovery."
		wait_msg_fastboot="Sent reboot to recovery command via fastboot."
		;;
	*)
		echo "[ERROR] Unknown mode: $mode" >&2
		return 2
		;;
	esac

	echo "[ACTION] Attempting to reboot into <$mode> mode..."

	# The transport was decided once when the target was pinned at menu dispatch
	if [ "$DEVICE_SOURCE" = "adb" ]; then
		echo "[INFO] Device is currently in <adb> mode: $TARGET_SERIAL"
		echo "[ACTION] Rebooting into <$mode> mode..."
		send_reboot adb "$reboot_cmd" "$reboot_arg" || return 1
		echo "[INFO] $wait_msg_adb"
	else
		echo "[INFO] Device is currently in <fastboot> mode: $TARGET_SERIAL"
		echo "[ACTION] Rebooting into <$mode> mode..."
		send_reboot fastboot "$reboot_cmd" "$reboot_arg" || return 1
		echo "[INFO] $wait_msg_fastboot"
	fi

	if [ "$mode" != "recovery" ] && ! wait_for_fastboot; then
		return 1
	fi

	echo "" # Spacer
}

# Wrapper: enter fastbootd (userspace) mode.
enter_fastbootd_mode() {
	enter_mode fastbootd
}

# Wrapper: enter bootloader (fastboot) mode.
enter_bootloader_mode() {
	enter_mode bootloader
}

# Wrapper: enter recovery mode.
enter_recovery_mode() {
	enter_mode recovery
}

# Function to reboot the device back to its OS (works from ADB or fastboot)
reboot_to_os() {
	case "$DEVICE_SOURCE" in
	adb)
		send_reboot adb reboot || return 1
		;;
	fastboot)
		send_reboot fastboot reboot || return 1
		;;
	*)
		echo "[ERROR] No device detected in ADB or Fastboot mode." >&2
		return 1
		;;
	esac
	echo "[INFO] Reboot command sent."
}
