Floppy OS 2.0 — Errors phase 1 (EXPERIMENTAL)
=================================================
Based on Floppy_OS_2_0_Setting_source (Setting is preserved).

Changes:
- Fresh FLOPSYS install no longer creates ERRORS or Error4x1.sys..Error4x4.sys.
- FloFile no longer offers the synthetic ERRORS folder/list.
- New compact Error window drawn by kernel, not FloFile module; title, centered code,
  localized RU/EN description, centered OK, minimize and close buttons.
- Codes encoded as: high nibble section (1..5), low nibble number (1..15).
- FloFile 3x1..3x5; Disk 4x1..4x3; FloCalc 5x1..5x4;
  FloTerm 5x5..5x12 in Floppy mode; older DOS-mode terminal messages preserved.
- Existing protection checks remain in place.
- Error window can be minimized, then restored via the 'Error' button near
  the bottom of the desktop (x=486..618, y=508..544).

IMPORTANT:
- This is a source-only candidate. NASM and QEMU are unavailable in this
  environment; no claim of successful assembly or boot testing is made.
- Existing disk images that already contain FLOPSYS/ERRORS are NOT silently
  modified. Migration/deletion must be handled after testing and backup.
- Boot/early fatal errors and FSM3 corruption full-screen alert remain on
  their original safe paths, until the new dialog has been proven stable.
- Do not overwrite the working Floppy OS 1.1 or 2.0 Setting backup.

Suggested test order on a COPY of your system image:
1. Run build.bat, inspect any NASM error or size overflow.
2. QEMU boot, verify Setting and other applications still open.
3. FloFile: delete protected folder -> Error 3x1, localized description.
4. Disks: format physical disk -> Error 4x2; never formats.
5. FloCalc: 1/0= -> Error 5x3.
6. FloTerm (Floppy mode): invalid command -> Error 5x5.
7. Check close X, OK, minus; restore via bottom Error button.
8. On a fresh disk image, check FLOPSYS contains no ERRORS folder.
