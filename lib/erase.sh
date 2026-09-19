# shellcheck shell=bash
# Partitions holding per-device unique data (keys, calibration, NV storage,
# board/factory data, user content). Never erase them. Full rationale and
# grouping: docs/partitions-never-erase.md. Matched with any _a/_b suffix
# stripped, so per-slot copies (e.g. oplusstanvbk_a) are protected too.
readonly -a PROTECTED_PARTITIONS=(
	persist persist_bkp modemst1 modemst2 fsg fsc oplusdycnvbk oplusstanvbk
	devinfo cdt engineering_cdt storsec secdata spunvm ddr
	userdata metadata frp misc param keystore dip dinfo ocdt uefivarstore
	carrier limits limits-cdsp apdp apdp_full ssd qmcs rtice tzsc
)

# Returns 0 (true) if $1 names a protected partition, 1 otherwise.
is_protected_partition() {
	local plain="${1:-}"
	plain="${plain%_a}"
	plain="${plain%_b}"
	for protected in "${PROTECTED_PARTITIONS[@]}"; do
		[[ "$plain" == "$protected" ]] && return 0
	done
	return 1
}

# Ensure the pinned device is reachable over fastboot, and in fastbootd
# (userspace) mode when $1 is "userspace". Applies the same identity checks as
# wait_for_fastboot so an erase never starts against a swapped-in device.
# Returns 1 on failure.
ensure_fastbootd() {
	local require_userspace="${1:-}" serials count

	serials=$(list_device_serials fastboot)
	count=$(printf '%s\n' "$serials" | awk 'NF { c++ } END { print c+0 }')

	if [ "$count" -eq 0 ]; then
		echo "[INFO] Device not in fastboot mode. Rebooting into fastbootd..."
		if ! enter_fastbootd_mode; then
			echo "[ERROR] Could not get device into fastbootd mode." >&2
			return 1
		fi
	else
		verify_pinned_fastboot "$serials" || return 1

		if [ "$require_userspace" = "userspace" ] &&
			! fb_read getvar is-userspace 2>&1 | grep -q "yes"; then
			echo "[INFO] Device is in bootloader mode. Rebooting into fastbootd..."
			if ! enter_fastbootd_mode; then
				echo "[ERROR] Could not get device into fastbootd mode." >&2
				return 1
			fi
		fi
	fi

	return 0
}

# Erase partitions matching files in flash-files/ for the selected slot.
# Prints the erase plan and asks for confirmation BEFORE any device command.
erase_active_partition() {
	local -a erase_plan=() skip_plan=()
	local img_file partition partition_name erase_failed p

	# shellcheck disable=SC2154 # flash_files is set by the main script before sourcing this lib
	for img_file in "${flash_files[@]}"; do
		partition=$(partition_from_file "$img_file")
		partition_name="${partition}${ACTIVE_PARTITION}"
		if is_protected_partition "$partition_name"; then
			skip_plan+=("$partition_name")
		else
			erase_plan+=("$partition_name")
		fi
	done

	if [ ${#erase_plan[@]} -eq 0 ]; then
		echo "Plan: no partitions to erase."
		for p in "${skip_plan[@]}"; do
			echo "  - $p (protected - skipped)"
		done
		return 0
	fi

	if [ -z "$ACTIVE_PARTITION" ]; then
		echo "Plan: will erase ${#erase_plan[@]} partition(s) present in flash-files/:"
	else
		echo "Plan: will erase ${#erase_plan[@]} partition(s) from slot $ACTIVE_PARTITION:"
	fi
	for p in "${erase_plan[@]}"; do
		echo "  - $p"
	done
	for p in "${skip_plan[@]}"; do
		echo "  - $p (protected - skipped)"
	done

	if ! ask_yn "Do you want to continue? (y/n): "; then
		return
	fi

	ensure_fastbootd userspace || return 1

	echo "" # Spacer

	erase_failed=0
	for partition_name in "${erase_plan[@]}"; do
		echo "Erasing $partition_name..."
		if ! fb_cmd erase "$partition_name"; then
			echo "Failed to erase $partition_name." >&2
			erase_failed=1
		fi
	done

	if [ "$erase_failed" -eq 0 ]; then
		echo "[INFO] All ${#erase_plan[@]} planned partition(s) erased successfully"
	else
		echo "[ERROR] One or more partitions failed to erase. Check the output above." >&2
	fi
}
