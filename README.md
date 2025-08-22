# Android Image Flasher
1) Flash any combination of Android image files
  - repair your boot partition, apply firmware updates or add custom recovery
2) Select a slot to flash
  - designed for devices with A/B partition schemes, but works on single slot devices as well
3) Find a device's active partition slot
  - detect if your device has an A/B partition scheme
4) Swap device's active slot
  - choose which slot you want to boot from

# Screenshot
![screenshot](https://github.com/user-attachments/assets/8be3ae03-ff28-490b-9bc1-fab0ebf899de)

# Requirements​
1) Linux system
2) ADB/fastboot installed
3) USB Debugging enabled on the device
4) Bootloader unlocked on the device

# Script's Workflow​
### Setup​
1) Download the zip file below
2) Extract it on your Linux box
3) Open a terminal in the same folder or navigate to the new folder
4) Type the command in terminal "bash Android-Image-Flasher.sh"
5) If the 'image_files/' directory is not present the script will create it
  - if the script creates the directory, exit and restart script (it scans files on startup)
6) Else if the directory is already present any files inside will be scanned
  - if you need to add or remove files, be sure to exit and reload the script
### Flashing​
1) Determine what slot (if any) you want to flash to
2) Either select a slot ORuse the swap slot option to reboot to the slot you want to flash
  - you chose to use the swap slot function: if the slot you swapped to is the slot you want to flash to, then there is NO need to still select a slot to flash to
3) Use the 1st VBMETA flash (if no vbmeta files, you can skip)
  - this will add the disable verity option
4) Next, the 2nd flash will do majority of the file flashing (in fastbootd mode, a must)
5) Lastly, the 3rd flash will retry any failed flashes but now in bootloader mode (may not be needed)
  - if there are still partitions that fail, a log file will be created in the same directory as the script called "flash_failures"
6) All the other options are just helpful and self explanatory

# F.A.Q.
1) Where do I add files to flash to my device?
  - the directory 'image_files/', in the script's directory.
  - you can add files ending in '.IMG' and '.BIN', all others will be ignored

2) How does the script know the partition name to flash each file to?
  - the script takes every file from the directory 'image_files/', removes the file extension and then uses the remaining filename as the partition name

3) Does this script ONLY work with A/B partition schemes?
  - NO, if you choose not to select a slot to flash to, then the script will flash without a slot suffix

4) Flashing keeps failing because a partition is not found or needs to be resized
  - if a partition needs to be resized, that can only be done in fastbootd mode
  - removing the slot selection and instead swapping to the slot you wish to flash to. then flash without a slot suffix, allowing the script to flash to the active slot instead


## Download the script from Github​
- [Zip file from Github, (always up to date)​](https://example.com "Download the script from Github​")
