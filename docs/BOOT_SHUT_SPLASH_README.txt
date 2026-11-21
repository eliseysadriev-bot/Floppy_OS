Floppy OS 2.0 — Minimal Boot Splash (SOURCE / UNTESTED)

Only the STARTUP splash changed (src/desktop/bootsplash.asm):
- Solid C_BLUE background at 800x600.
- Original ab_pic logo from src/desktop/about.asm, pixel-identical 32x32 bitmap
  rendered 2x as 64x64 at (28,508), in the bottom-left corner.
- Only one small white 8x16 BIOS-font label "Floppy OS 2.0", at (112,532).
- No central panel, large header, version label, status messages or progress bar.
- Keeps the prior timer-driven 73-tick (~4 sec) start splash duration.
- The bs_progress label remains as a no-op for compatibility.

NOT changed:
- The separate shutdown screen (bs_shutdown), its labels, and clock cursor.
- Boot menu and boot sector, installer, desktop, taskbar, icons, and cursors.
- Build/run scripts and Bochs configuration.

UNTESTED: do not assume NASM or QEMU work until independently built and run.
Previous versions of this README described a now-removed startup progress bar.
