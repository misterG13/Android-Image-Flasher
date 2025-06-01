# Android-Oneplus-Image-Flasher
- Flash any combination of Android image files
- Find a device's active partition slot
- Erase all partitions on a selected slot

# Screenshot
![screenshot](https://github.com/user-attachments/assets/2bd3f3dc-e4bd-44a3-84d2-1c297cd306aa)

# Options that are Working:
- "Enter fastbootd mode"
  - Uses ADB to reboot device from it's operating system screen
- "Enter bootloader mode"
  - Checks for device to be in fastbootd mode first. Reboots to fastbootd if needed then switches to bootloader mode
- "Find device's active slot"
  - Uses ADB or FASTBOOT commands to find the device's active partition slot
- "Exit"
  - Ends the script (ALT+C will exit if the script hits an error you can't get through)

# Options in Testing
- "Erase partitions" (Will only erase partitions of matching filenames in the 'image_files/' directory)
  1) If no slot is selected, this will erase with no slot suffix
  2) Needs to be in either fastboot mode
- "Begin flashing..." (Starts flashing in fastbootd mode, where there is access to the dynamic partitions)
  1) Start with your phone boot up to it's Operating System
  2) Next, uses ADB to reboot device into fastbootd mode
  3) Then fastboot commands are used to to flash the .BIN & .IMG files in directory, 'image_files/'
    - the filenames of the BIN and IMAGE files are used as the partition name in the fastboot flash command
    - Flash command will use a slot suffix, if the user has selected one from the main menu, if not no suffix is used
  4) Any files that failed to flash in fastbootd mode are saved to an array where 'Finish flashing..." takes over
- "Finish flashing..." (Finishes by flashing in bootloader mode, where there is access to system partitions)
- "Reboot to device's OS"

# Script's workflow
- Launching the script automatically looks for the directory 'image_files/', if it does not exist, it will be created
  - After the directory is created, the script will scan the directory for all files ending in '.BIN' & '.IMG'
  - The filenames of the '.BIN' & '.IMG' files will be stored in a array for later processing
