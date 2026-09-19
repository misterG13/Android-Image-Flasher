# shellcheck shell=bash
# common.sh — Shared globals and utility functions (ask_yn, partition_from_file).

# Global state
# shellcheck disable=SC2034 # Shared globals consumed by other sourced libs; ShellCheck cannot follow the dynamic source
ACTIVE_PARTITION=""
failed_files=()

# Run <cmd...> under a <seconds> hard cap so a hung device cannot stall the
# script forever. Returns the command's exit status (124 = device unresponsive).
run_guarded() {
	local seconds="$1" rc
	shift
	timeout --kill-after="${KILL_GRACE:-5}" "$seconds" "$@"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		if [ "$rc" -eq 124 ]; then
			echo "[ERROR] The device did not respond to '$1' within ${seconds}s." >&2
		fi
		return "$rc"
	fi
	return 0
}

# Guarded fastboot/adb wrappers. Defaults expand at call time so they can be
# tuned per invocation via the environment.
fb_cmd() { run_guarded "${WRITE_CMD_TIMEOUT:-600}" fastboot "$@"; }
fb_read() { run_guarded "${READ_CMD_TIMEOUT:-20}" fastboot "$@"; }
adb_read() { run_guarded "${READ_CMD_TIMEOUT:-20}" adb "$@"; }

# Interrupt handler: warn the user the device may be in an inconsistent state
interrupt_handler() {
	echo "" >&2
	echo "[ERROR] Script interrupted. Verify the device state before continuing." >&2
	exit 130
}

# Prompt the user with a yes/no question. Returns 0 for yes (y/Y/yes/YES),
# 1 for anything else.
ask_yn() {
	local reply
	read -rp "$1" reply
	case "${reply,,}" in
	y | yes) return 0 ;;
	*) return 1 ;;
	esac
}

# Derive a partition name from an image filename (strip path and .img/.bin, case-insensitive)
partition_from_file() {
	local base
	base="$(basename "$1")"
	base="${base,,}"
	base="${base%.img}"
	base="${base%.bin}"
	printf '%s' "$base"
}
