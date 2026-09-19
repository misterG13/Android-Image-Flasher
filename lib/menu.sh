# shellcheck shell=bash
# Main menu
# NOTE: keep this menu and the README "Menu Reference" table in sync.
print_menu() {
	local -a menu_items=(
		"Flashing Options:"
		"  01. Find device's active slot"
		"  02. Select a slot to flash/erase"
		"  03. Swap active slot"
		""
		"Flashing files from 'flash-files/':"
		"  04. (1st) Flash VBMETA files"
		"  05. (2nd) Flash dynamic partitions"
		"  06. (3rd) Retry failed flashes (bootloader)"
		""
		"Erase:"
		"  07. Erase partitions matching files in 'flash-files/'"
		""
		"Boot Modes:"
		"  08. Enter fastbootd mode"
		"  09. Enter bootloader mode"
		"  10. Enter recovery mode"
		""
		"  11. Reboot to device's OS"
		"  12. Exit"
	)
	local item
	for item in "${menu_items[@]}"; do
		echo "$item"
	done
}

while true; do
	print_menu

	echo "" # Spacer
	if ! read -rp "Enter your choice: " choice; then
		echo "[INFO] Input stream closed. Exiting." >&2
		exit 0
	fi
	clear

	# Every device-touching action pins the target device once, here at menu
	# dispatch: destructive/state-changing actions confirm model + serial,
	# benign ones pin silently. Flows themselves never re-check.
	case $choice in
	1|01) acquire_target_device silent && get_active_slot ;;
	2|02) select_active_slot ;;
	3|03) acquire_target_device prompt && swap_active_slot ;;
	4|04) acquire_target_device prompt && flash_vbmeta_partitions ;;
	5|05) acquire_target_device prompt && flash_fastbootd_partitions ;;
	6|06) acquire_target_device prompt && flash_bootloader_partitions ;;
	7|07) acquire_target_device prompt && erase_active_partition ;;
	8|08) acquire_target_device silent && enter_fastbootd_mode ;;
	9|09) acquire_target_device silent && enter_bootloader_mode ;;
	10) acquire_target_device silent && enter_recovery_mode ;;
	11) acquire_target_device silent && reboot_to_os ;;
	12) exit 0 ;;
	*) echo "Invalid choice. Please try again." ;;
	esac

	echo "" # Spacer
done
