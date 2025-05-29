# android-oneplus-ota-image-flasher
- Flash any combination of Android image files
- Find a phone's active partition slot
- Erase all partitions on a selected slot

# Options that are Working:
- "Enter fastbootd mode"
- "Enter bootloader mode"
- "Find phone's active slot"
- "Exit"

# Options in Testing
- "Erase partitions" (Will only erase partitions of matching filenames in the image_files/ directory)
- "Begin flashing..." (Starts flashing in fastbootd mode, where there is access to the dynamic partitions)
- "Finish flashing..." (Finishes by flashing in bootloader mode, where there is access to system partitions)
- "Reboot to phone's OS"