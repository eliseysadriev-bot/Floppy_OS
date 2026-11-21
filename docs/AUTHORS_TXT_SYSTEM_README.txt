Floppy OS 2.0 - C:/flopsys/authors.txt (source patch; UNTESTED)
===================================================================

Corrected location: C:/flopsys/authors.txt (NOT C:/system/authors.txt).

- assets/flopsys/authors.txt: source text of author credits.
- src/kernel/sysinst.asm: writes the credits into the EXISTING flopsys
  directory on the default C: FSM2 filesystem (new or existing disk).
- No new directory called 'system' is created.
- If authors.txt exists in flopsys, its contents are not overwritten.
- FloFile opens ordinary .txt files on double left-click using FloText.
- Taskbar icons in assets/taskbar_icons remain unchanged.
- Existing C:/system/authors.txt from an older build, if any, is
  NOT automatically deleted (avoid deleting unrelated user data).

To view inside Floppy OS:
  FloFile -> C: -> flopsys -> authors.txt (double left-click).

Build with existing build.bat (Windows) or build.sh; run with run.bat.
No changes to the FS schema, disk naming, graphics or UI.
This archive is NOT TESTED in NASM/QEMU in the current environment.
