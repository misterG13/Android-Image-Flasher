# Android-Oneplus-Image-Flasher
- Flash any combination of Android image files
- Find a device's active partition slot
- Erase all partitions on a selected slot

# Screenshot
![screenshot](https://github.com/user-attachments/assets/2fc294ea-669b-4c2e-b86b-5cf88a8c8260)

# Options that are Working:
1) "Enter fastbootd mode"
  - Uses ADB to reboot device from it's operating system screen
2) "Enter bootloader mode"
  - Checks for device to be in fastbootd mode first. Reboots to fastbootd if needed then switches to bootloader mode
3) "Find device's active slot"
  - Uses ADB or FASTBOOT commands to find the device's active partition slot
4) "Exit"
  - Ends the script (ALT+C will exit if the script hits an error you can't get through)

# Options in Testing
5) "Erase partitions"
  - Will only erase partitions with filenames that were found in the 'image_files/' directory
  - If no slot is selected, this will erase with no slot suffix
  - Needs to be in either fastboot mode
6) "Begin flashing..."
  - Starts flashing in fastbootd mode, where there is access to the dynamic partitions
  - Start with your phone boot up to it's Operating System (ADB access)
  - Next, uses ADB to reboot device into fastbootd mode
  - Then fastboot commands are used to to flash the .BIN & .IMG files in directory, 'image_files/'
    - the filenames of the BIN and IMAGE files are used as the partition name in the fastboot flash command
    - the flash command will use a slot suffix, if the user has selected one from the main menu, if not, no suffix is used
  - Any files that failed to flash in fastbootd mode are saved to an array where 'Finish flashing..." takes over
7) "Finish flashing..."
  - Finishes by flashing in bootloader mode, where there is access to system partitions
  - The filenames that failed to flash in fastbootd will be looped through and flashed again
  - The flash command will use a slot suffix, if the user has selected one from the main menu, if not, no suffix is used
  - Any remaining files that fail to flash here will be recorded and written to a text file, 'flash_failures.txt'
8) "Reboot to device's OS"
  - Detects what mode the phone is in
  - Reboots device using ADB or FASTBOOT commands

# Script's workflow
1) Launching the script automatically looks for the directory 'image_files/', if it does not exist, it will be created
  - After the directory is created, the script will scan the directory for all files ending in '.BIN' & '.IMG'
  - The filenames of the '.BIN' & '.IMG' files will be stored in a array for later processing
2) Options #1 & #2 are optional and come as a utility function if you need it
  - This option is not need to start flashing
3) Option #3 is another utility function
  - This option is not need to start flashing
4) Option #4 is where you can select which slot this script will ERASE/FLASH, you can also DESELECT back to no slot scheme
  - This option is not need to start flashing
5) Option #5 will erase partitions (with or without a slot suffix) that match the filenames of files in the directory, 'image_files/'
  - This option is not need to start flashing
6) Option #6 Must be done first
7) Option #7 Must be selected second
