Floppy 1.0
<img width="700" height="600" alt="image" src="https://github.com/user-attachments/assets/58077a3e-d562-4cf5-ba25-cd15ce5beed8" />
<img width="700" height="600" alt="image" src="https://github.com/user-attachments/assets/413c675d-d387-42ec-8a66-aced3ca62507" />
<img width="700" height="600" alt="image" src="https://github.com/user-attachments/assets/4cb3bbf5-fc4e-40eb-979c-e14c286081df" />
<img width="700" height="600" alt="image" src="https://github.com/user-attachments/assets/1e139806-a85d-4821-a88b-43299dd341ac" />


A hobby operating system written in NASM assembly.

The whole system was made with the help of AI. The author designs and tests it and the AI writes most of the code.

About the system
- 32-bit protected mode kernel with its own 16-bit bootloader
- 800x600 graphics with 16 colors and its own mouse and keyboard drivers
- Black white gray and blue look with hard shadows
- Desktop with draggable and resizable windows and a clock
- About and Settings windows
- Mouse cursors for arrow and hand and text and resize and a busy cursor with a Loading screen

Programs
- FloText is a text editor with mouse selection and copy cut and paste
- FloPaint is a drawing program with tools and a brush slider and a palette and undo and fill
- FloFile is a file manager with folders and rename and delete and a list of disks
- FloCalc is a calculator
- Boil is a small game where you stop the microwave at the exact time and the record is saved in a file
- Open and Save to windows shared by the programs

System
- Own file system with folders
- Three disks C and O and I and an empty disk is formatted automatically
- System folder flopsys on disk C with programs and games
- Programs are separate .sys modules loaded by the bootloader
- Scrollbars and sliders everywhere something does not fit

How to run
You need NASM and QEMU or Bochs 3.1.
- Windows run build.bat for QEMU or run_bochs.bat for Bochs
- Linux and macOS run build.sh

Status
Early and experimental so bugs are expected. Made for fun and to learn assembly.

License is in the LICENSE file.
