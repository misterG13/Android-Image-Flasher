# shellcheck shell=bash
# Function to verify with the user the slot they did or did not select
verify_flash_slot() {
	# If active_partition is not set remind user
	if [ -z "$ACTIVE_PARTITION" ]; then
		echo "[WARNING] You have not selected a partition slot (_a/_b)."
		echo "[WARNING] On A/B devices, flashing without a slot suffix may fail or target the wrong slot."
	else
		echo "[INFO] You have selected slot $ACTIVE_PARTITION"
	fi

	# Check ARB levels and warn if dangerous downgrade (non-blocking)
	warn_arb_if_needed

	# Ask user to continue to flashing
	if ! ask_yn "[ACTION] Start flashing partitions? (y/n): "; then
		echo "[ACTION] Returning to main menu..."
		return 1
	fi

	echo "" # Spacer
}

# Function to flash a partition
flash_image() {
	local partition=$1
	local image=$2
	local -a flash_cmd=(flash)

	if [[ $partition == vbmeta* ]]; then
		flash_cmd+=(--disable-verity --disable-verification)
	fi
	flash_cmd+=("$partition" "$image")

	echo "Flashing ${partition} with ${image}..."
	if is_protected_partition "$partition"; then
		echo "[WARNING] $partition holds per-device unique data (protect list). Consider skipping this flash."
	fi
	if ! fb_cmd "${flash_cmd[@]}"; then
		echo "[ERROR] Flashing ${partition} failed!" >&2
		failed_files+=("$image") # Add failed file to the failed array
		return 1
	fi
	echo "${partition} flashed successfully!"

	echo "" # Spacer
}

# Enter the given mode and verify the flash slot. The device itself was
# already confirmed once at menu dispatch.
# Usage: prepare_flash <mode>   where <mode> is "bootloader" or "fastbootd"
prepare_flash() {
	local mode=$1
	if ! "enter_${mode}_mode"; then
		return 1
	fi
	if ! verify_flash_slot; then
		return 1
	fi
}

# Flash vbmeta partitions first (with disable-verity).
flash_vbmeta_partitions() {
	local vbmeta_files=() img filename partition

	echo "" # Spacer

	# shellcheck disable=SC2154 # flash_files is set by the main script before sourcing this lib
	for img in "${flash_files[@]}"; do
		# Remove .img or .bin from the end of the filename
		filename=$(partition_from_file "$img")
		if [[ $filename == vbmeta* ]]; then
			vbmeta_files+=("$img")
		fi
	done

	if [ ${#vbmeta_files[@]} -eq 0 ]; then
		echo "[INFO] No vbmeta files found in $FLASH_FILES. Nothing to flash."
		return 0
	fi

	prepare_flash bootloader || return 1

	# Loop through filenames found in 'flash-files/'; attempt every file so all
	# failures are tracked and retried together by menu 6.
	for img in "${vbmeta_files[@]}"; do
		partition=$(partition_from_file "$img") # Get partition name from filename

		# Flash the partition of filenames found in 'flash-files/'
		flash_image "${partition}${ACTIVE_PARTITION}" "$img"
	done
}

# Flash non-vbmeta partitions from fastbootd mode.
flash_fastbootd_partitions() {
	prepare_flash fastbootd || return 1

	# Reset failure tracking for this pass, but keep any vbmeta failures from the
	# preceding menu-4 flash so menu-6 retry still picks them up.
	local prev_failures=() prev_file file partition
	for prev_file in "${failed_files[@]}"; do
		if [[ $(partition_from_file "$prev_file") == vbmeta* ]]; then
			prev_failures+=("$prev_file")
		fi
	done
	failed_files=("${prev_failures[@]}")

	# Loop through filenames found in 'flash-files/'; attempt every file so all
	# failures are tracked and retried together by menu 6.
	for file in "${flash_files[@]}"; do
		# Remove .img or .bin from the end of the filename
		partition=$(partition_from_file "$file")

		# Skip flashing vbmeta-related images
		if [[ $partition == vbmeta* ]]; then
			echo "Skipping $partition image..."
			continue
		fi

		# Flash the partition of filenames found in 'flash-files/'
		flash_image "${partition}${ACTIVE_PARTITION}" "$file"
	done
}

# Function to reboot into bootloader mode and finish flashing files
flash_bootloader_partitions() {
	if [ ${#failed_files[@]} -gt 0 ]; then
		prepare_flash bootloader || return 1

		echo "[ACTION] Retrying failed flashes in bootloader mode..."
		echo "" # Spacer

		# Snapshot the pending files so retries can be tracked fresh
		local pending_files=("${failed_files[@]}")
		local skipped_dynamic=()
		local probe_type ptype partition failed_file dyn_file
		failed_files=()

		# Probe whether 'partition-type' getvar is supported; only then can we
		# distinguish a missing (logical) partition from an unsupported command.
		probe_type=$(fb_read getvar "partition-type:boot${ACTIVE_PARTITION}" 2>&1 | grep -oP 'partition-type:\s*\K[^\r\n]+' | head -1)

		for failed_file in "${pending_files[@]}"; do
			# Remove .img or .bin from the end of the filename
			partition=$(partition_from_file "$failed_file")

			# Dynamic/logical partitions (system, vendor, product, ...) can only be
			# flashed from fastbootd; bootloader mode rejects them. In bootloader
			# mode their 'partition-type' getvar FAILS (rather than returning
			# "logical"), so on a getvar-capable device an empty result means the
			# partition is logical - skip it instead of logging a guaranteed failure.
			# Probe the slot-suffixed name so the getvar matches the exact
			# partition being flashed, independent of the device's current slot.
			if [ -n "$probe_type" ]; then
				ptype=$(fb_read getvar "partition-type:${partition}${ACTIVE_PARTITION}" 2>&1 | grep -oP 'partition-type:\s*\K[^\r\n]+' | head -1)
				if [ -z "$ptype" ]; then
					echo "[INFO] ${partition} is a dynamic partition - flash it from fastbootd (menu option 5) instead."
					skipped_dynamic+=("$failed_file")
					continue
				fi
			fi

			flash_image "${partition}${ACTIVE_PARTITION}" "$failed_file"
		done

		if [ ${#skipped_dynamic[@]} -gt 0 ]; then
			echo "[INFO] ${#skipped_dynamic[@]} dynamic partition(s) still need flashing from fastbootd (menu option 5):"
			for dyn_file in "${skipped_dynamic[@]}"; do
				echo "  - $(partition_from_file "$dyn_file")"
			done
			if ask_yn "[ACTION] Reboot back into fastbootd to flash them now? (y/n): "; then
				enter_fastbootd_mode
			fi
		fi

		if [ ${#failed_files[@]} -gt 0 ]; then
			echo "[INFO] Some files failed to flash after retrying."
			echo "[ACTION] Logging failures to $LOG_FILE"

			# Outputs failed files; falls back to inline listing if unwritable
			if echo "[INFO] Failed to flash the following files:" >"$LOG_FILE"; then # 1st line
				for failed_file in "${failed_files[@]}"; do
					echo "$failed_file" >>"$LOG_FILE"
				done

				echo "[INFO] Please check <$LOG_FILE> for the failed files."
			else
				echo "[ERROR] Could not write $LOG_FILE. Failed files:" >&2
				for failed_file in "${failed_files[@]}"; do
					echo "  - $failed_file" >&2
				done
			fi
		elif [ ${#skipped_dynamic[@]} -eq 0 ]; then
			echo "[INFO] All failed flashes succeeded after retry."
		fi
	else
		echo "[ACTION] No failed files to flash. Returning to the main menu"
		return 0
	fi
}
