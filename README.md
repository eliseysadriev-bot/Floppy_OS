# Floppy OS

Floppy OS is a hobbyist 32-bit operating system written in NASM assembly language.

The operating system was developed with the help of artificial intelligence. The author designs features, makes development decisions, tests the system, and finds bugs, while AI generates most of the source code.

## About the System

- 32-bit protected-mode kernel with a custom 16-bit bootloader
- 800x600 graphics with 16 colors and custom mouse and keyboard drivers
- Black, white, gray, and blue color scheme with sharp shadows
- Graphical desktop with draggable and resizable windows and a clock
- About, Settings, and Disks windows
- English and Russian language support
- Mouse cursors: arrow, hand, text, resize, and busy cursor with a loading screen
- Keyboard shortcuts and clipboard support

## Programs

- FloText: text editor with mouse selection, copying, cutting, pasting, and file saving
- FloPaint: drawing program with tools, brush size slider, color palette, undo, and fill
- FloItge: graphics editor with drawing tools, color selection, and undo
- FloFile: file manager with folders, renaming, deletion, and disk navigation
- FloCalc: calculator
- FloClock: clock
- FloTasks: task management application
- FloTerm: terminal with system commands
- FloCalendar: calendar with month and year navigation
- Open and Save dialogs for working with files

## System

- Custom FSM2 and FSM3 file systems
- Support for files, folders, and nested directories
- Multi-block file storage in FSM3
- Three main disks: C, O, and I
- Virtual disks of 180 KB, 360 KB, 720 KB, and 8 MB
- FLOPSYS system folder on disk C containing system programs
- Separate `.sys` program modules loaded by the bootloader
- Disk management with formatting and space usage indicators
- Protection against dangerous operations on system files and disks
- File system integrity checks and error codes
- Compatibility with older FSM2 disks
- Scrollbars and sliders for content that does not fit on screen

## How to Run

QEMU is required to run the prebuilt operating system. NASM is required to build it from source.

- **Windows:** run `run.bat` to launch the prebuilt system or `build.bat` to compile it
- **Linux:** run `run.sh` to launch the prebuilt system
- **Prebuilt version:** requires the `pm.img` disk image
- **Source code:** available separately for building and development

## Status

Floppy OS 1.1 is an experimental operating system with a working graphical interface, built-in applications, and custom file systems.

Core functionality has been tested in QEMU. Some advanced features, including very large file handling and damaged disk recovery, still have limitations.

The project was created for fun, experimentation, and learning about low-level programming and operating system development.

## Links

- GitHub: https://github.com/eliseysadriev-bot/Floppy_OS
- YouTube: https://www.youtube.com/@Xanex_OS
- Telegram: https://t.me/+hLck_nnZCA0wZjIy

## License

See the LICENSE file for license information.


<img width="600" height="400" alt="image" src="https://github.com/user-attachments/assets/fa39764a-38b6-4906-b745-30efbc679907" />
<img width="410" height="360" alt="image" src="https://github.com/user-attachments/assets/380b4790-a72e-40dc-aa8b-8a67c3fc2e93" />
<img width="510" height="370" alt="image" src="https://github.com/user-attachments/assets/ce33a7a7-649e-4e4f-97c1-53fcc26968dc" />
