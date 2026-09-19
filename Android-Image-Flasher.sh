#!/bin/bash
# Android-Image-Flasher: Interactive A/B partition flasher for Android devices.
# Usage: ./Android-Image-Flasher.sh   (place .img/.bin files in flash-files/ first)
set -uo pipefail
export LC_ALL=C

# Resolve the script's own directory so paths work regardless of the caller's CWD.
# Note: deliberately symlink-relative (no readlink), so a symlinked invocation
# (e.g. the test harness) uses the symlink's directory for flash-files/logs while
# lib/ must sit alongside the symlink.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory of image files (.img/.bin) to flash
FLASH_FILES="$SCRIPT_DIR/flash-files"
# shellcheck disable=SC2034 # Used by lib/flash.sh (dynamic source; ShellCheck cannot follow it)
LOG_FILE="$SCRIPT_DIR/flash_failures.log"

# Ensure bash is new enough (bash 4.4+ for safe empty-array expansion under 'set -u')
if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
	echo "[ERROR] bash 4.4 or newer is required (found $BASH_VERSION)." >&2
	exit 1
fi

# Ensure required tools are available
for tool in adb fastboot timeout awk basename sort tr clear flock; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "[ERROR] $tool not found in PATH. Please install it and retry." >&2
		exit 1
	fi
done

# The script relies on GNU grep's PCRE support (-P)
if ! printf 'x' | grep -qP 'x' 2>/dev/null; then
	echo "[ERROR] GNU grep with PCRE support (-P) is required." >&2
	exit 1
fi

# Single-instance guard: prevent two scripts flashing the same device at once.
# flock is released automatically when the script exits (even on SIGKILL), so a
# crashed instance never leaves a stale lock.
LOCK_FILE="$SCRIPT_DIR/.flasher.lock"
if ! exec 9>"$LOCK_FILE"; then
	echo "[ERROR] Cannot create lock file $LOCK_FILE." >&2
	exit 1
fi
if ! flock -n 9; then
	echo "[ERROR] Another instance of Android-Image-Flasher.sh is already running." >&2
	exit 1
fi

# Check if directory exists; if not: create it
if [ ! -d "$FLASH_FILES" ]; then
	if ! mkdir -p "$FLASH_FILES"; then
		echo "[ERROR] Could not create $FLASH_FILES." >&2
		exit 1
	fi
fi

# Create an array of files with extensions (case-insensitive)
flash_files=()
for file in "$FLASH_FILES"/*; do
	if [[ "${file,,}" == *.img || "${file,,}" == *.bin ]]; then
		flash_files+=("$file")
	fi
done

# If the array is empty alert user to add files in order to use Erase & Flash functions
if [ ${#flash_files[@]} -eq 0 ]; then
	echo "[INFO] No .bin or .img files found in $FLASH_FILES."
	echo "[ACTION] Please add files to use the Erase & Flash functions."
	echo "" # Spacer
fi

# Load function libraries and the menu loop into this shell so global state
# (ACTIVE_PARTITION, failed_files, flash_files) is shared.
for lib in common device modes slots flash erase arb menu; do
	# shellcheck source=lib/common.sh
	source "$SCRIPT_DIR/lib/$lib.sh" || {
		echo "[ERROR] Could not load lib/$lib.sh. Reinstall or restore the file." >&2
		exit 1
	}
done

trap interrupt_handler INT TERM
trap 'rm -f "$LOCK_FILE"' EXIT
