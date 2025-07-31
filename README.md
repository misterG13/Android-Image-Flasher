# Android-Image-Flasher
1) Flash any combination of Android image files
  - repair your boot partition, apply firmware updates or add custom recovery
2) Select a slot to flash
  - designed for devices with A/B partition schemes, but works on single slot devices as well
3) Find a device's active partition slot
  - detect if your device has an A/B partition scheme

# Screenshot
![screenshot](https://github.com/user-attachments/assets/2fc294ea-669b-4c2e-b86b-5cf88a8c8260)

# Options that are Working:
1) If the options in the menu are visible, the option is than also usable

# Script's Workflow
1) Coming soon....

# F.A.Q.
1) Where do I add files to flash to my device?
  - the directory 'image_files/', in the script's directory.
  - you can add files ending in '.IMG' and '.BIN', all others will be ignored

2) How does the script know the partition name to flash each file to?
  - the script takes every file from the directory 'image_files/', removes the file extension and then uses the remaining filename as the partition name.

3) Does this script ONLY work with A/B partition schemes?
  - NO, if you choose not to select a slot to flash to, then the script will flash without a slot suffix.