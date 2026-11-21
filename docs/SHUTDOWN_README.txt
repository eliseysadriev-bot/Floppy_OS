Floppy OS 2.0 - Shut Down desktop button (SOURCE ONLY, UNTESTED)

New file: src/desktop/power.asm
Changed: src/kernel/kernel32.asm

- Four desktop buttons: Floppy, About, Setting, Shut Down.
- The Shut Down button is below Setting. No Bin button was added.
- Confirmation dialog: Shut Down / Cancel.
- Dialog visual fix: no blue line; both button captions drawn in black;
  question lowered within the existing dialog. Position and size unchanged.
- Buttons activate on mouse release over the same choice.
- Escape cancels; Enter confirms when the dialog is open.
- Power-off attempts QEMU/Bochs legacy ACPI ports, then displays a
  manual power-off screen and halts. Real hardware ACPI discovery
  and S5 handling are NOT implemented.
- Other GUI and file system modules unchanged.

IMPORTANT: NASM and QEMU are unavailable in the editing environment.
Compilation, image-size check and runtime tests have not been performed.
Keep a working backup. The image layout relies on a 256-sector kernel;
if kernel32.asm grows past that, the build will fail on the padding line.

Suggested test sequence:
1. Build in NASM with build.bat (Windows) or build.sh (Linux).
2. Boot QEMU with a COPY of your disk images.
3. Test the fourth button, Cancel, Escape and re-opening dialog.
4. Test Shut Down in QEMU. Real hardware is not expected to power off
   reliably until its ACPI shutdown support is implemented.
