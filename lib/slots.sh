# shellcheck shell=bash
# Detect the device's current active slot letter ('a' or 'b') on the given
# transport (default: the transport the target was pinned on). Prints the
# letter (empty when the device has no slot scheme).
detect_current_slot() {
	local transport="${1:-$DEVICE_SOURCE}" slot=""

	if [ "$transport" = "adb" ]; then
		slot=$(adb_read shell getprop ro.boot.slot_suffix 2>/dev/null | LC_ALL=C tr -d '[:cntrl:]' | tr -d '_')
	else
		slot=$(fb_read getvar current-slot 2>&1 | grep -oP 'current-slot:\s*\K[ab]' | head -n 1)
	fi

	printf '%s' "$slot"
}

# Detect and display the active slot.
get_active_slot() {
	local active_slot

	echo "[ACTION] Checking for active slot A/B ..."

	active_slot=$(detect_current_slot)

	# Verify slot
	if [[ "$active_slot" == "a" || "$active_slot" == "b" ]]; then
		ACTIVE_PARTITION="_$active_slot"
		echo "[INFO] Active slot: $active_slot"
		echo "[INFO] Active partition suffix: $ACTIVE_PARTITION"
	else
		ACTIVE_PARTITION=""
		echo "[INFO] Non A/B slot scheme found."
	fi

	return 0
}

# Switch the active partition slot (handles both ADB and fastboot sources).
swap_active_slot() {
	local current_slot new_slot

	if [ "$DEVICE_SOURCE" = "adb" ]; then
		echo "[INFO] Device detected in ADB mode."

		current_slot=$(detect_current_slot)
		echo "[INFO] Current active slot: $current_slot"

		if ! ask_yn "Do you want to switch to the other slot? (y/n): "; then
			echo "[INFO] Aborted by user."
			if ask_yn "Reboot the device back to its OS? (y/n): "; then
				send_reboot adb reboot || return 1
			fi
			return
		fi

		# Switch to fastboot mode
		echo "[ACTION] Rebooting into bootloader..."
		send_reboot adb reboot bootloader || return 1
		if ! wait_for_fastboot; then
			return 1
		fi
	elif [ "$DEVICE_SOURCE" != "fastboot" ]; then
		echo "[ERROR] No device detected in ADB or Fastboot mode." >&2
		return 1
	fi

	# The device is now in fastboot mode (pinned that way, or rebooted into it
	# from ADB above), so query the slot over fastboot.
	echo "[INFO] Device detected in Fastboot mode."
	current_slot=$(detect_current_slot fastboot)
	echo "[INFO] Current active slot: $current_slot"

	# Determine the new slot
	if [[ $current_slot == "a" ]]; then
		new_slot="b"
	elif [[ $current_slot == "b" ]]; then
		new_slot="a"
	else
		echo "[ERROR] Could not determine current slot." >&2
		return 1
	fi

	if ! ask_yn "Switch from slot $current_slot to slot $new_slot? (y/n): "; then
		echo "[INFO] Aborted by user."
		if ask_yn "Reboot the device back to its OS? (y/n): "; then
			send_reboot fastboot reboot || return 1
		fi
		return
	fi

	echo "[ACTION] Switching to slot $new_slot..."
	if ! fb_cmd --set-active="$new_slot"; then
		echo "[ERROR] Failed to set active slot to $new_slot." >&2
		return 1
	fi

	echo "[SUCCESS] Active slot set to $new_slot."

	if ask_yn "Reboot the device now? (y/n): "; then
		if ! send_reboot fastboot reboot-bootloader; then
			return 1
		fi
	else
		echo "[INFO] Reboot skipped."
	fi
}

# Function to allow the user to select which partition they want as 'active'
select_active_slot() {
	local choice
	echo "Select the active slot:"
	echo "1. _a"
	echo "2. _b"
	echo "3. Clear active slot"

	read -rp "Enter your choice (1/2/3): " choice

	case $choice in
	1) ACTIVE_PARTITION="_a" ;;
	2) ACTIVE_PARTITION="_b" ;;
	3)
		echo "Clearing active slot."
		ACTIVE_PARTITION=""
		;;
	*)
		echo "Invalid choice. No slot selected"
		;;
	esac

	clear

	if [ -z "$ACTIVE_PARTITION" ]; then
		echo "Active slot cleared."
	else
		echo "Active slot set to: $ACTIVE_PARTITION"
	fi
}
