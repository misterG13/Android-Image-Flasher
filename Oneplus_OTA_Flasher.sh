#!/bin/bash

# Set directory for extracted OTA images
OTA_DIR="./image_files"

# Check if directory exists; if not: create it
if [ ! -d "$OTA_DIR" ]; then
  mkdir -p "$OTA_DIR"
fi

# Create an array using the filenames of  the .bin & .img files in the directory
img_files=()
for file in "$OTA_DIR"/*; do
  if [[ "$file" == *.img || "$file" == *.bin ]]; then
    img_files+=("$file")
  fi
done

# If the array is empty alert user to add files in order to use Erase & Flash functions
if [ ${#img_files[@]} -eq 0 ]; then
  echo "[INFO] No .bin or .img files found in $OTA_DIR."
  echo "[ACTION] Please add files to use the Erase & Flash functions."
  echo "" # Spacer
fi

# Function to check if device is connected in fastbootd
enter_fastbootd_mode() {
  echo "[ACTION] Attempting to reboot into <fastbootd> mode..."

  # Check if any device is connected in ADB mode (excluding 'unauthorized' and 'offline')
  adb_device=$(adb devices | awk '$2 == "device" { print $1 }')

  if [ -n "$adb_device" ]; then
    echo "[INFO] Device is currently in <adb> mode: $adb_device"
    echo "[ACTION] Rebooting into <fastbootd> mode..."
    adb reboot fastboot
    echo "[INFO] Waiting for device in fastboot..."
    fastboot wait-for-device 2>/dev/null
  else
    echo "[INFO] Device is not detected in ADB. Assuming <fastboot> mode..."
    echo "[ACTION] Rebooting into <fastbootd> mode..."
    fastboot reboot fastboot
    echo "[INFO] Waiting for device in fastbootd..."
    fastboot wait-for-device 2>/dev/null
  fi
}

# Function to check if device is in bootloader mode
enter_bootloader_mode() {
  echo "[ACTION] Attempting to reboot into <bootloader> mode..."

  # Check if any device is connected in ADB mode (excluding 'unauthorized' and 'offline')
  adb_device=$(adb devices | awk '$2 == "device" { print $1 }')

  if [ -n "$adb_device" ]; then
    echo "[INFO] Device is currently in <adb> mode: $adb_device"
    echo "[ACTION] Rebooting into <bootloader> mode..."
    adb reboot bootloader
    echo "[INFO] Waiting for device in bootloader..."
    fastboot wait-for-device 2>/dev/null
  else
    echo "[INFO] Device is not detected in ADB. Assuming <bootloader> mode..."
    echo "[ACTION] Rebooting into <bootloader> mode..."
    fastboot reboot bootloader
    echo "[INFO] Waiting for device in bootloader..."
    fastboot wait-for-device 2>/dev/null
  fi
}

# Function to get the active partition (_a or _b)
get_active_slot() {
  echo "Checking for an active slot (_a or _b)..."

  # Check over ADB
  active_slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '_' | tr -d '\r')

  # Verify check
  if [[ -z "$active_slot" ]]; then

    # Check for fastboot mode
    active_slot=$(fastboot getvar current-slot 2>&1 | grep -oE 'a|b' | head -n 1)

    # Verify check
    if [[ -z "$active_slot" ]]; then
      echo "Error: active_slot is empty or unset."
    fi
  fi

  if [[ "$active_slot" == "a" || "$active_slot" == "b" ]]; then
    ACTIVE_SUFFIX="_$active_slot"
    echo "Active slot: $active_slot"
    echo "Active suffix: $ACTIVE_SUFFIX"
  else
    ACTIVE_SUFFIX=""
    echo "No active A/B slot detected."
  fi
}

# Function to switch active partition slot
swap_active_slot() {
  # Check if device is connected in ADB mode
  if adb get-state 2>/dev/null | grep -q "device"; then
    echo "[INFO] Device detected in ADB mode."

    current_slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
    echo "[INFO] Current active slot: $current_slot"

    read -p "Do you want to switch to the other slot? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
      echo "[INFO] Aborted by user."
      return
    fi

    # Switch to fastboot mode
    echo "[ACTION] Rebooting into bootloader (25 second pause)..."
    adb reboot bootloader
    sleep 25 # seconds
  fi

  # Check if device is in fastboot mode
  if fastboot devices | grep -q "fastboot"; then
    echo "[INFO] Device detected in Fastboot mode."

    current_slot=$(fastboot getvar current-slot 2>&1 | grep "current-slot" | awk '{print $2}')
    echo "[INFO] Current active slot: $current_slot"

    # Determine the new slot
    if [[ $current_slot == "a" ]]; then
      new_slot="b"
    elif [[ $current_slot == "b" ]]; then
      new_slot="a"
    else
      echo "[ERROR] Could not determine current slot."
      return 1
    fi

    read -p "Switch from slot $current_slot to slot $new_slot? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
      echo "[INFO] Aborted by user."
      return
    fi

    echo "[ACTION] Switching to slot $new_slot..."
    fastboot --set-active=$new_slot

    echo "[SUCCESS] Active slot set to $new_slot."

    read -p "Reboot the device now? (y/n): " confirm
    if [[ $confirm == "y" ]]; then
      fastboot reboot-bootloader
    else
      echo "[INFO] Reboot skipped."
    fi
  else
    echo "[ERROR] No device detected in ADB or Fastboot mode."
  fi
}

# Function to all the user to select which partition they want as 'active'
select_active_slot() {
  echo "Select the active slot:"
  echo "1. _a"
  echo "2. _b"
  echo "3. Clear active slot"

  read -p "Enter your choice (1/2/3): " choice

  case $choice in
  1) ACTIVE_PARTITION="_a" ;;
  2) ACTIVE_PARTITION="_b" ;;
  3)
    echo "Clearing active slot."
    unset ACTIVE_PARTITION
    ;;
  *)
    echo "Invalid choice. Defaulting to _a."
    ACTIVE_PARTITION="_a"
    ;;
  esac

  if [ -z "$ACTIVE_PARTITION" ]; then
    echo "Active slot cleared."
  else
    echo "Active slot set to: $ACTIVE_PARTITION"
  fi
}

# Function to erase partitions that match filenames in 'image_files/'
erase_active_partition() {
  if [ -z $ACTIVE_PARTITION ]; then
    echo "This will erase the devices's currently in use slot"
  else
    echo "This will erase slot $ACTIVE_PARTITION"
  fi

  read -p "Do you want to continue? (y/n) " choice

  case "$choice" in
  y | Y) ;;
  n | N) return ;;
  *) echo "Invalid choice. Exiting." && return ;;
  esac

  if [ -n "$ACTIVE_PARTITION" ]; then
    echo "Erasing all partitions on slot $ACTIVE_PARTITION:"
  else
    echo "Erasing all partitions on the active slot:"
  fi

  for img_file in "${img_files[@]}"; do
    partition=$(basename "$img_file" .img)
    partition_name="${partition}${ACTIVE_PARTITION}"

    echo "Erasing $partition_name..."
    fastboot erase "$partition_name"
    # echo "fastboot erase "$partition_name"" # testing purposes

    if [ $? -ne 0 ]; then
      echo "Failed to erase $partition_name."
      # exit 1
    fi
  done

  if [ -n "$ACTIVE_PARTITION" ]; then
    echo "All partitions on slot $ACTIVE_PARTITION erased successfully"
  else
    echo "All partitions on the active slot have been erased successfully"
  fi
}

# Function to find all partitions on the connected device
find_all_partitions() {
  echo "[ACTION] Attempting to find all partitions on the connected device..."

  # Ensure the device is in fastboot mode
  if ! fastboot devices | grep -q "fastboot"; then
    echo "[INFO] Device not in fastboot mode. Attempting to enter fastboot mode..."
    enter_bootloader_mode # This function already handles entering bootloader/fastboot mode
    if [ $? -ne 1 ]; then
      echo "[ERROR] Could not get device into fastboot mode. Cannot find partitions."
      return 1
    fi
  fi

  echo "Fetching A/B partition list from device..."

  # Initialize arrays
  local all_partitions a_partitions=() b_partitions=()

  # Get all A/B partitions
  mapfile -t all_partitions < <(fastboot getvar all 2>&1 |
    grep -oP '\b\w+_(a|b)\b' | sort -u)

  # Split into _a and _b arrays
  for part in "${all_partitions[@]}"; do
    if [[ "$part" == *_a ]]; then
      a_partitions+=("$part")
    elif [[ "$part" == *_b ]]; then
      b_partitions+=("$part")
    fi
  done

  # Display results
  echo -e "\nFound ${#a_partitions[@]} '_a' partitions:"
  for part in "${a_partitions[@]}"; do
    echo "- $part"
  done

  echo -e "\nFound ${#b_partitions[@]} '_b' partitions:"
  for part in "${b_partitions[@]}"; do
    echo "- $part"
  done

  # Optional: export arrays for use outside function
  export A_PARTS=("${a_partitions[@]}")
  export B_PARTS=("${b_partitions[@]}")

  erase_ab_slot_partitions
}

# Function to erase all partitions on a slot
erase_ab_slot_partitions() {
  # Make sure the partition arrays exist
  if [[ -z "${A_PARTS[*]}" || -z "${B_PARTS[*]}" ]]; then
    echo "Partition arrays are empty. Run get_ab_partition_arrays first."
    return 1
  fi

  echo -n "Which slot would you like to erase? (a / b): "
  read -r slot_choice

  case "$slot_choice" in
  a)
    selected_parts=("${A_PARTS[@]}")
    ;;
  b)
    selected_parts=("${B_PARTS[@]}")
    ;;
  *)
    echo "Invalid choice. Please enter 'a' or 'b'."
    return 1
    ;;
  esac

  echo "You selected to erase slot: $slot_choice"
  echo "The following partitions will be erased:"
  for part in "${selected_parts[@]}"; do
    echo "- $part"
  done

  echo -n "Are you sure you want to continue? (yes/no): "
  read -r confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Operation cancelled."
    return 1
  fi

  # Loop and erase each partition
  for part in "${selected_parts[@]}"; do
    echo "Erasing $part..."
    # fastboot erase "$part"
    echo "fastboot erase "$part""
    if [[ $? -ne 0 ]]; then
      echo "Failed to erase $part. Continuing with next..."
    fi
  done

  echo "Erasing complete."
}

# Function to flash a partition
flash_image() {
  local partition=$1
  local image=$2

  echo "Flashing ${partition} with ${image}..."
  if [[ $partition == vbmeta* ]]; then
    fastboot flash --disable-verity --disable-verification "$partition" "$image"
  else
    fastboot flash "$partition" "$image"
  fi

  # Check if the flash command was successful
  if [ $? -ne 0 ]; then
    echo "ERROR: Flashing ${partition} failed!"
    failed_files+=("$image") # Add failed file to the failed array
  else
    echo "${partition} flashed successfully!"
  fi

  echo "" # Spacer
}

# Function to flash 'vbmeta' and other 'vbmeta' partitions before all others
flash_vbmeta_partitions() {
  enter_bootloader_mode

  echo ""         # Spacer
  vbmeta_files=() # Initialize/clear the array

  for img in "${img_files[@]}"; do
    filename=$(basename "$img")
    if [[ $filename == vbmeta* ]]; then
      vbmeta_files+=("$img")
    fi
  done
  # echo "vbmeta_files: ${vbmeta_files[@]}"

  # Loop through filenames found in 'image_files/'
  for img in "${vbmeta_files[@]}"; do
    partition=$(basename "$img" .img) # Get partition name from filename
    active_suffix=$ACTIVE_PARTITION

    # Flash the partition of filenames found in 'image_files/'
    flash_image "${partition}${active_suffix}" $img
  done
}

# Function to flash a partition and handle failures
flash_fastbootd_partitions() {
  enter_fastbootd_mode

  echo "" # Spacer

  # If active_partition is not set remind user
  if [ -z "$ACTIVE_PARTITION" ]; then
    echo "[INFO] You have not selected a partition slot"
  else
    echo "[INFO] You have selected slot $ACTIVE_PARTITION"
  fi

  # Ask user to continue to flashing
  read -p "[ACTION] Start flashing the dynamic partitions? (y/n):" reply
  if [[ "$reply" != "y" ]]; then
    echo "[ACTION] Returning to main menu..."
    return 1
  fi

  echo "" # Spacer

  # Tracks failed partitions in a array
  failed_files=()

  # Loop through filenames found in 'image_files/'
  for img in "${img_files[@]}"; do
    partition=$(basename "$img" .img) # Get partition name from filename
    active_suffix=$ACTIVE_PARTITION

    # Skip flashing vbmeta-related images
    if [[ $partition == vbmeta* ]]; then
      echo "Skipping $partition image..."
      continue
    fi

    # Flash the partition of filenames found in 'image_files/'
    flash_image "${partition}${active_suffix}" $img
  done

  flash_bootloader_partitions
}

# Function to reboot into bootloader mode and finish flashing files
flash_bootloader_partitions() {
  if [ ${#failed_files[@]} -gt 0 ]; then
    enter_bootloader_mode

    echo "[ACTION] Flashing system partitions..."
    echo "" # Spacer

    for failed_file in "${failed_files[@]}"; do
      partition=$(basename "$failed_file" .img) # Get partition name from filename
      # flash_image $partition $failed_file
      flash_image "${partition}${active_suffix}" $failed_file
    done

    if [ ${#failed_files[@]} -gt 0 ]; then
      echo "[INFO] Some files failed to flash after retrying."
      echo "[ACTION] Logging failures to flash_failures.txt"

      # Outputs failed files
      echo "Failed to flash the following files:" >flash_failures.txt # 1st line
      for failed_file in "${failed_files[@]}"; do
        echo "$failed_file" >>flash_failures.txt
      done

      echo "[INFO] Please check <flash_failures.txt> for the failed files."
    else
      echo "[INFO] All failed flashes succeeded after retry."
    fi
  else
    echo "[ACTION] No failed files to flash. Returning to the main menu"
    return 1
  fi
}

# Main menu
while true; do
  echo "Flashing Options:"
  echo "  1. Select a slot to flash/erase"
  echo "  2. Find device's active slot"
  echo "  3. Swap active slot"

  echo "" # Spacer
  echo "Begin Flashing files from 'image_files/':"
  echo "  4. (1st) Flash VBMETA files"
  echo "  5. (2nd) Flash dynamic partitions"
  echo "  6. (3rd) Flash system partitions (if needed)"

  echo "" # Spacer
  echo "Boot Modes:"
  echo "  7. Enter fastbootd mode"
  echo "  8. Enter bootloader mode"

  # if [ -n "$ACTIVE_PARTITION" ]; then
  #   echo "  9. Erase slot $ACTIVE_PARTITION partitions"
  # else
  #   echo "  9. Erase active partitions"
  # fi

  echo "" # Spacer
  echo "Finished:"
  echo "  10. Reboot to device's OS"
  echo "  11. Exit"

  echo "" # Spacer
  read -p "Enter your choice: " choice
  clear

  case $choice in
  1) select_active_slot ;;
  2) get_active_slot ;;
  3) swap_active_slot ;;
  4) flash_vbmeta_partitions ;;
  5) flash_fastbootd_partitions ;;
  6) flash_bootloader_partitions ;;
  7) enter_fastbootd_mode ;;
  8) enter_bootloader_mode ;;
  # 9) erase_active_partition ;; # Testing
  # 9) find_all_partitions ;; # Testing
  10) fastboot reboot ;;
  11) exit 0 ;;
  *) echo "Invalid choice. Please try again." ;;
  esac

  echo "" # Spacer
done
